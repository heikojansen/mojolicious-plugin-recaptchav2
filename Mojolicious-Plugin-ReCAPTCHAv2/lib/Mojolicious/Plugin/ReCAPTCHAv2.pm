package Mojolicious::Plugin::ReCAPTCHAv2;
# vim:syntax=perl:tabstop=4:number:noexpandtab:

use Mojo::Base 'Mojolicious::Plugin';

# ABSTRACT: use Googles "No CAPTCHA reCAPCTHA" (reCAPTCHA v2) service in Mojolicious apps

use Mojo::JSON qw();
use Mojo::UserAgent qw();

has conf => sub{ +{} };
has verification_errors => sub{ +[] };

sub register {
	my $plugin = shift;
	my $app    = shift;
	my $conf   = shift || {};

	die ref($plugin), ": need sitekey and secret!\n"
		unless $conf->{'sitekey'} and $conf->{'secret'};

	$conf->{'api_url'}     //= 'https://www.google.com/recaptcha/api/siteverify';
	$conf->{'api_timeout'} //= 10;

	$plugin->conf($conf);

	$app->helper(
		recaptcha_get_html => sub {
			my $c         = shift;
			my $language  = $_[0] ? shift : undef;

			my %data_attr = map { $_ => $plugin->conf->{$_} } grep { index( $_, 'api_' ) != 0 } keys %{ $plugin->conf };

			# Never expose this!
			delete $data_attr{'secret'};

			my $hl = '';
			if ( defined $language and $language ) {
				$hl = $language;
			}
			elsif ( exists $data_attr{'language'} ) {
				$hl = delete $data_attr{'language'};
			}

			my $output = $c->render_to_string(
				inline => q|<script src="https://www.google.com/recaptcha/api.js?hl=<%= $hl %>" async defer></script>
<div class="g-recaptcha"<% foreach my $k ( sort keys %{$attr} ) { %> data-<%= $k %>="<%= $attr->{$k} %>"<% } %>></div>|,
				hl     => $hl,
				attr   => \%data_attr,
			);
			return $output;
		}
	);
	$app->helper(
		recaptcha_verify => sub {
			my $c = shift;

			my %verify_params = (
				remoteip => $c->tx->remote_address,
				response => $c->req->param('g-recaptcha-response'),
				secret   => $plugin->conf->{'secret'},
			);

			my $url     = $plugin->conf->{'api_url'};
			my $timeout = $plugin->conf->{'api_timeout'};

			my $ua = Mojo::UserAgent->new();
			$ua->max_redirects(0)->request_timeout($timeout);

			# reset previous errors, if any
			$plugin->verification_errors([]);

			# XXX async request?
			my $tx = $ua->post( $url => form => \%verify_params );
			if ( my $res = $tx->success ) {
				my $json = '';
				eval {
					$json = Mojo::JSON::decode_json( $res->body );
				};
				if ($@) {
					$c->app->log->error( 'Decoding JSON response failed: ' . $@ );
					$c->app->log->error( 'Request  was: ' . $tx->req->to_string );
					$c->app->log->error( 'Response was: ' . $tx->res->to_string );
					return -1;
				}
				unless ( $json->{'success'} ) {
					$plugin->verification_errors( $json->{'error-codes'} // [] );
				}
				return $json->{'success'};

			}
			else {
				$c->app->log->error( 'Retrieving captcha verifcation failed: HTTP ' . $res->code );
				$c->app->log->error( 'Request  was: ' . $tx->req->to_string );
				$c->app->log->error( 'Response was: ' . $tx->res->to_string );
				return -1;
			}
		}
	);
	$app->helper(
		recaptcha_get_errors => sub {
			return $plugin->verification_errors;
		}
	);

	return;
} ## end sub register

1;

__END__

=pod

=head1 SYNOPSIS

    use Mojolicious::Plugin::ReCAPTCHAv2;

    sub startup {
        my $self = shift;

        $self->plugin('ReCAPTCHAv2', {
            sitekey       => 'site-key-embedded-in-public-html',                 # required
            secret        => 'key-used-in-internal-verification-requests',       # required
            # api_timeout => 10,                                                 # optional
            # api_url     => 'https://www.google.com/recaptcha/api/siteverify',  # optional
            # size        => 'normal',                                           # optional
            # tabindex    => 0,                                                  # optional
            # theme       => 'light',                                            # optional
            # type        => 'image',                                            # optional
        });
    }

    # later

    # assembling website:
    $app->stash( captcha => $app->recaptcha_get_html );
    # now use stashed value in your HTML template, i.e.: <form..>...<% $captcha %>...</form>

    # on incoming request
    my $verify = $app->recaptcha_verify;
    if ( $verify < 0 ) {
        # internal error - request failed or invalid json
    }
    elsif ( $verify > 0 ) {
        # success: probably human
    }
    else {
        # fail: probably bot, but may also be a
        # processing error
        if ( my $err = $app->recaptcha_get_errors ) {
            # processing failed
            foreach my $e ( @{$err} ) {
                ...
            }
        }
        else {
            # bot
            ...
        }
    }

=head1 DESCRIPTION

L<Mojolicious::Plugin::ReCAPTCHAv2> allows you to protect your site against
automated interaction by (potentially malicious) robots.

This is accomplished by injecting a extra javascript widget in your forms
that requires human interaction. The interaction is evaluated on a server
(via AJAX) and a dynamic parameter is injected in your form.
When your users submit your form to your server you receive that parameter
and can verify it by sending it to the captcha servers in the background.
You should then stop further processing of the request you received if the
captcha did not validate.

Please note that this module currently does not support some advanced usage
models for the captcha like explicit rendering and AJAX callbacks.
Therefore a few options listed in the official Google docs are not listed
above.
If you would like to see support for this kind of functionality, please
get in touch with the author / maintainer of this module.

For a general overview of what a Captcha is and how the Google "No Captcha"
reCaptcha (v2) service works, please refer to the
L<official documentation|https://developers.google.com/recaptcha/>.

=head1 OPTIONS

The following params can be provided to the plugin on registration:

=over 4

=item C<sitekey>

=item C<secret>

=item C<api_timeout>

=item C<api_url>

=item C<size>

=item C<tabindex>

=item C<theme>

=item C<type>

=back

C<sitekey> and C<secret> are required parameters, while all others are
optional. The default values for the optional configuration params are shown
in the synopsis.

For the meaning of these please refer to L<https://developers.google.com/recaptcha/docs/display#config>.

=head1 METHODS

L<Mojolicious::Plugin::ReCAPTCHAv2> inherits all methods from L<Mojolicious::Plugin>
and implements no extra ones.

=head1 HELPERS

L<Mojolicious::Plugin::ReCAPTCHAv2> makes the following helpers available:

=head2 recaptcha_get_html

Returns a HTML fragment with the widget codeM; you will probably want to put
this in the stash, since it has to be inserted in your HTML form element
when processing the template.

=head2 recaptcha_verify

Call this helper when receiving the request from your website after the user
submitted the form.

You should call this only once per incoming request.

It will return one of the following values:

=over 4

=item C<-1>

Some internal error occured: the HTTP request failed or the result returned
by the reCPATCHA servers is invalid JSON.

=item C<0>

The reCAPTCHA service could not verify that the Captcha was solved by a
human; either because it was a bot or because of some processing error.
You should check for processing errors via C<recaptcha_get_errors>.
You should not continue with processing your users request but probably
re-display the form with an added error message.

=item C<1>

The reCAPTCHA service believes that the challenge was solved by a human.
You may proceed with processing the incoming request.

=back

=head2 recaptcha_get_errors

This helper returns a reference to an array which may contain zero, one
or more error codes.
The array is reset on every call to C<recaptcha_verify>.
The array can contain these error codes:

=over 4

=item C<missing-input-secret>

The secret parameter is missing.

This should not happen, since registering the plugin requires a C<secret>
configuration param which is then automatically included in the verification
request.

=item C<invalid-input-secret>

The secret parameter is invalid or malformed.

Please check your registration data and configuration!

=item C<missing-input-response>

The response parameter is missing.

Please check if the HTML code for the widget was included at the correct
position in your template. Please check the request parameters that were
transferred to your server after the user submitted your form.

=item C<invalid-input-response>

The response parameter is invalid or malformed.

Somebody tinkered with the request data somewhere.

=back

=head1 SEE ALSO

=over 4

=item L<Mojolicious>

=item L<https://developers.google.com/recaptcha/>

=back

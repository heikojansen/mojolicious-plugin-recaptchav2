# SYNOPSIS

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
    if ( $app->recaptcha_verify ) {
        # success: probably human
        ...
    }
    else {
        # fail: probably bot, but may also be a
        # processing error

        if ( my $err = $app->recaptcha_get_errors ) {
            # processing failed, inspect error codes
            foreach my $e ( @{$err} ) {
                ...
            }
        }
        else {
            # bot
            ...
        }
    }

# DESCRIPTION

[Mojolicious::Plugin::ReCAPTCHAv2](https://metacpan.org/pod/Mojolicious::Plugin::ReCAPTCHAv2) allows you to protect your site against
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
[official documentation](https://developers.google.com/recaptcha/).

# OPTIONS

The following params can be provided to the plugin on registration:

- `sitekey`
- `secret`
- `api_timeout`
- `api_url`
- `size`
- `tabindex`
- `theme`
- `type`

`sitekey` and `secret` are required parameters, while all others are
optional. The default values for the optional configuration params are shown
in the synopsis.

For the meaning of these please refer to [https://developers.google.com/recaptcha/docs/display#config](https://developers.google.com/recaptcha/docs/display#config).

# METHODS

[Mojolicious::Plugin::ReCAPTCHAv2](https://metacpan.org/pod/Mojolicious::Plugin::ReCAPTCHAv2) inherits all methods from [Mojolicious::Plugin](https://metacpan.org/pod/Mojolicious::Plugin)
and implements no extra ones.

# HELPERS

[Mojolicious::Plugin::ReCAPTCHAv2](https://metacpan.org/pod/Mojolicious::Plugin::ReCAPTCHAv2) makes the following helpers available:

## recaptcha\_get\_html

Returns a HTML fragment with the widget code; you will probably want to put
this in the stash, since it has to be inserted in your HTML form element
when processing the template.

## recaptcha\_verify

Call this helper when receiving the request from your website after the user
submitted the form. Sends your secret, the response token from the request
your received and the users IP to the reCAPTCHA server to verify the token.

You should call this only once per incoming request.

It will return either a `true` or `false` value:

- `false` (0)

    The reCAPTCHA service could not verify that the Captcha was solved by a
    human; either because it was a bot or because of some processing error.
    You should check for processing errors via `recaptcha_get_errors`.
    You should not continue with processing your users request but probably
    re-display the form with an added error message.

- `true` (1)

    The data is valid and the reCAPTCHA service believes that the challenge
    was solved by a human. You may proceed with processing the incoming request.

## recaptcha\_get\_errors

This helper returns a reference to an array which may contain zero, one
or more error codes.
The array is reset on every call to `recaptcha_verify`.
The array can contain these official API error codes:

- `missing-input-secret`

    The secret parameter is missing.

    This should not happen, since registering the plugin requires a `secret`
    configuration param which is then automatically included in the verification
    request.

- `invalid-input-secret`

    The secret parameter is invalid or malformed.

    Please check your registration data and configuration!

- `missing-input-response`

    The response parameter is missing.

    Please check if the HTML code for the widget was included at the correct
    position in your template. Please check the request parameters that were
    transferred to your server after the user submitted your form.

- `invalid-input-response`

    The response parameter is invalid or malformed.

    Somebody tinkered with the request data somewhere.

Additionally the following error codes may be encountered which are defined
internally by this module. Note: these codes start with "x-" to 
distinguish them from official error codes.

- `x-http-communication-failed`

    Something went wrong while trying to talk to the reCAPTCHA server.

- `x-unparseable-data-received`

    The http request was completed successfully but Mojo::JSON could not
    decode the response received from the reCAPTCHA server.

# SEE ALSO

- [Mojolicious](https://metacpan.org/pod/Mojolicious)
- [https://developers.google.com/recaptcha/](https://developers.google.com/recaptcha/)

#!perl
# vim:syntax=perl:tabstop=4:number:noexpandtab:

use Mojo::Base -strict;
use Mojolicious::Lite;
use Test::Mojo;
use Test::More;

plugin 'ReCAPTCHAv2' => {
	'sitekey'          => 'key',
	'secret'           => 'secret',
	'theme'            => 'dark',
	'type'             => 'image',
	'size'             => 'compact',
	'tabindex'         => '1',
	'callback'         => 'console.log',
	'expired-callback' => 'console.log',
};

get '/' => sub {
	my $c = shift;
	$c->render( text => $c->recaptcha_get_html('en') );
};

get '/test' => sub {
	my $c = shift;
	$c->recaptcha_verify;
	$c->render(
		json => {
			verify => $c->recaptcha_verify,
			errors => $c->recaptcha_get_errors,
		}
	);
};

my $t = Test::Mojo->new;

$t
->get_ok('/')
->status_is(200)
->content_is(<<'RECAPTCHA');
<script src="https://www.google.com/recaptcha/api.js?hl=en" async defer></script>
<div class="g-recaptcha" data-callback="console.log" data-expired-callback="console.log" data-sitekey="key" data-size="compact" data-tabindex="1" data-theme="dark" data-type="image"></div>
RECAPTCHA

$t
->get_ok( '/test' => {} => form => { 'g-recaptcha-response' => 'foo' } )
->status_is(200)
->json_is( '/verify'   => 0 )
->json_is( '/errors/0' => 'invalid-input-response' )
->json_is( '/errors/1' => 'invalid-input-secret' )
;

done_testing;

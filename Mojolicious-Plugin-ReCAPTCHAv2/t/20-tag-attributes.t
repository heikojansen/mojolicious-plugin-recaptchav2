#!perl
use Mojo::Base -strict;
use Test::More;
use Mojolicious::Lite;
use Test::Mojo;

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
    $c->render(text => $c->recaptcha_get_html('en'));
};

get '/errors' => sub {
    my $c = shift;
    $c->recaptcha_verify;
    $c->render(json => $c->recaptcha_get_errors);
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
->get_ok('/errors' => {} => form => {'g-recaptcha-response' => 'foo'} )
->status_is(200)
->content_is('["invalid-input-response","invalid-input-secret"]');

done_testing;

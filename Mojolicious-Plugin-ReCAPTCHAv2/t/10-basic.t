#!perl
use Mojo::Base -strict;
use Test::More;
use Mojolicious::Lite;
use Test::Mojo;

plugin 'ReCAPTCHAv2' => {
    'sitekey'  => 'key',
    'secret'   => 'secret',
};

get '/' => sub {
    my $c = shift;
    $c->render(text => $c->recaptcha_get_html);
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
<script src="https://www.google.com/recaptcha/api.js?hl=" async defer></script>
<div class="g-recaptcha" data-sitekey="key"></div>
RECAPTCHA

$t
->get_ok('/errors' => {} => form => {'g-recaptcha-response' => 'foo'} )
->status_is(200)
->content_is('["invalid-input-response","invalid-input-secret"]');

done_testing;

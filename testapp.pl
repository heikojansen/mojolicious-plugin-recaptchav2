#!/usr/bin/env perl 

use strict;
use warnings;
use utf8;

use lib qw(Mojolicious-Plugin-ReCAPTCHAv2/lib);

use Mojolicious::Lite;
 
app->log->level('error');

plugin 'ReCAPTCHAv2' => {
	sitekey  => $ENV{'RECAPTCHA_SITEKEY'},
	secret   => $ENV{'RECAPTCHA_SECRET'},
	language => 'de',
};
 
get '/test' => sub {
	my $self = shift;
	$self->stash( nocap => $self->recaptcha_get_html );
};

post '/run' => sub {
	my $self = shift;
	my $result = $self->recaptcha_verify;
	if ($result) {
		warn "success";
	}
	else {
		warn "failed";
		use Data::Dumper;
		warn Dumper $self->recaptcha_get_errors;
	}
	$self->stash( result => $result );
};

app->start;

__DATA__

@@ test.html.ep
<!DOCTYPE html>
<head>
<title>test</title>
</head>
<body>
<form action="/run" method="POST">
<%= $nocap %>
<button type="submit">run</button>
</form>
</body>
</html>

@@ run.html.ep
<!DOCTYPE html>
<head>
<title>run</title>
</head>
<body>
<b><%= $result %></b>
</body>
</html>

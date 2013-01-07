package Yoba::LWP;

use 5.010;
use strict;
use warnings;
use Carp;

use LWP;
use base "LWP::UserAgent";

use Yoba;

push @LWP::Protocol::http::EXTRA_SOCK_OPTS, (SendTE => 0);

sub referer($) {
   my $self = shift;
   my($url) = @_;
   $self->default_header(referer => Yoba::gethost($url));
   # $self->default_header(referer => $url);
   return;
}

sub cookie($) {
   my $self = shift;
   my($cookie) = @_;
   $self->default_header(cookie => $cookie);
   return;
}

sub proxy($) {
   my $self = shift;
   my($proxy) = @_;
   do { Carp::carp "No proxy string passed"; return } unless $proxy;
   $proxy = Yoba::setscheme($proxy);
   Carp::croak("Proxy must be specified as absolute URI; '$proxy' is not") unless $proxy =~ /^$URI::scheme_re:/;
   Carp::croak("Bad http proxy specification '$proxy'") if $proxy =~ /^https?:/ && $proxy !~ m,^https?://\w,;
   $self->{proxy}{"http"}  = $proxy;
   $self->{proxy}{"https"} = $proxy;
   $self->set_my_handler("request_preprepare", \&LWP::UserAgent::_need_proxy);
   return;
}

2;

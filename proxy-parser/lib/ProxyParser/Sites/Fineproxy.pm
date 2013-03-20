package ProxyParser::Sites::Fineproxy;

use 5.010;
use strict;
use utf8;
use warnings;
use Carp;

use LWP;

use ProxyParser::Common;

our $LWP = new LWP::UserAgent;
$LWP->default_header(Referer => "http://fineproxy.org/");
$LWP->agent("Opera/9.80 (X11; Linux i686) Presto/2.12.388 Version/12.14");

# <- (string)
sub parse
{
   my $lwp = $LWP->clone;
   my $url = "http://fineproxy.org/";
   say "Загрузка '$url'...";
   return parse_proxies($lwp->get($url)->content);
}
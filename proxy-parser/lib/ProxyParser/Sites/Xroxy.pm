package ProxyParser::Sites::Xroxy;

use 5.010;
use strict;
use utf8;
use warnings;
use Carp;

use LWP;
use List::MoreUtils qw/uniq/;

use ProxyParser::Common;

our $LWP = new LWP::UserAgent;
$LWP->default_header(Referer => "http://www.xroxy.com/");
$LWP->agent("Opera/9.80 (X11; Linux i686) Presto/2.12.388 Version/12.14");

# -> string
# <- (string)
sub parse_proxies_from_page($)
{
   my($html) = @_;
   my %proxies = $html =~ m~&host=(.*?)&port=(\d+)&~g;
   my @proxies = map { "$_:$proxies{$_}" } keys %proxies;
   return @proxies;
}

# -> LWP::UserAgent, number
# <- string
sub get_page($$)
{
   my($lwp, $page) = @_;
   my $url = "http://www.xroxy.com/proxylist.php?type=All_http&sort=reliability&pnum=$page";
   say "Загрузка '$url'...";
   return $lwp->get($url)->content;
}

# <- (string)
sub parse
{
   my $lwp = $LWP->clone;

   my @proxies;
   for my $page (0 .. 300)
   {
      my @p = parse_proxies_from_page(get_page($lwp, $page));
      last unless @p;
      say sprintf "-> Найдено %d прокси", 0 + @p;
      push @proxies, @p;
   }

   return @proxies;
}
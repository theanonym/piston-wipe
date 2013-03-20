package ProxyParser::Sites::Samair;

use 5.010;
use strict;
use utf8;
use warnings;
use Carp;

use LWP;
use List::MoreUtils qw/uniq/;

use ProxyParser::Common;

our $LWP = new LWP::UserAgent;
$LWP->default_header(Referer => "http://www.samair.ru/");
$LWP->agent("Opera/9.80 (X11; Linux i686) Presto/2.12.388 Version/12.14");

# -> LWP::UserAgent, string
# <- string
sub get_page($$)
{
   my($lwp, $page) = @_;
   my $url = "http://www.samair.ru/proxy/time-$page.htm";
   say "Загрузка '$url'...";
   return $lwp->get($url)->content;
}

# -> string
# <- (number)
sub parse_pages($)
{
   my($html) = @_;
   my @pages = sort uniq $html =~ m~<a href="time\-(\d+)\.htm">~g;
   return @pages;
}

# <- (string)
sub parse
{
   my $lwp = $LWP->clone;

   my $html = get_page($lwp, "01");
   my @pages = parse_pages $html;

   my @proxies = parse_proxies $html;
   for my $page (@pages)
   {
      eval { push @proxies, parse_proxies(get_page($lwp, $page)) };
      print $@ if $@;
   }

   return @proxies;
}
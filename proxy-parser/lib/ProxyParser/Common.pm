package ProxyParser::Common;

use 5.010;
use strict;
use utf8;
use warnings;
use Carp;

use base "Exporter";
our @EXPORT = qw/
   parse_proxies
/;

use List::MoreUtils qw/uniq/;

# -> string
# <- (string)
sub parse_proxies($)
{
   my($text) = @_;
   #----------------------------------------
   my @proxies = $text =~ m~([a-z0-9\.]*?\.(?:.{2,3}|\d{1,3}):\d{2,4})~gm;
   @proxies = uniq @proxies;
   my @result;
   my %ips;
   for my $proxy (@proxies)
   {
      my($ip) = $proxy =~ m~(.*?):\d+~;
      next if(length $ip < 8);
      push @result, $proxy unless $ips{$ip}++;
   }
   #----------------------------------------
   return map { "http://$_" } @result;
}

2;
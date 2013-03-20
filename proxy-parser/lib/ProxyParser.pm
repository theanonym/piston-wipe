package ProxyParser;

use 5.010;
use strict;
use utf8;
use warnings;
use Carp;

use ProxyParser::Sites;
use ProxyParser::Common;

our $VERSION = "0.1";

# -> string
# <- (string)
sub parse($)
{
   my($site) = @_;

   given($site)
   {
      when("spys")      { return ProxyParser::Sites::Spys::parse }
      when("fineproxy") { return ProxyParser::Sites::Fineproxy::parse }
      when("samair")    { return ProxyParser::Sites::Samair::parse }
      when("xroxy")     { return ProxyParser::Sites::Xroxy::parse }
   }
}

2;
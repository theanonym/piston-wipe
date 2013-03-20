package ProxyParser::Sites;

use 5.010;
use strict;
use utf8;
use warnings;
use Carp;

use base "Exporter";
our @EXPORT = qw/
   @SITES
/;

use ProxyParser::Sites::Spys;
use ProxyParser::Sites::Fineproxy;
use ProxyParser::Sites::Samair;
use ProxyParser::Sites::Xroxy;

our @SITES = qw/spys fineproxy samair xroxy/;

2;
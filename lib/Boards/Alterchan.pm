package Boards::Alterchan;

use 5.010;
use strict;
use warnings;
use Carp;

use Yoba;
use Yoba::LWP;
use Yoba::Coro;

use base "Exporter";
our @EXPORT = qw/
   login
/;
our @EXPORT_OK = @EXPORT;

# -> Yoba::LWP, string
# <- bool
sub login($$)
{
   my($lwp, $pass) = @_;
   my $res = $lwp->post("http://alterchan.net/uid.php",
      Content_Type => "application/x-www-form-urlencoded",
      Content      => "action=login&pass1=$pass",
  );
   return $res->content =~ /Ist Gut/;
}
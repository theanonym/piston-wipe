package Boards;

use 5.010;
use strict;
use warnings;
use Carp;

sub import
{
   shift;
   my $board = shift;
   eval sprintf "use Boards::%s %s; 1", ucfirst $board, (@_ ? "qw/@_/" : "") or die $@;
}

2;
use 5.010;
use strict;
use warnings;
use Carp;

use Piston::Extensions;
use Boards::Nullchan;

extension(
   if   => sub { $Piston::config->{chan} eq "nullchan" && $Piston::config->{nullthreads} },
   name => "Бамп пустых тредов",
   init => \&refresh,
   main => \&refresh,
);

sub refresh {
   my @target  = grep { $Piston::shared->{catalog}->{$_} <= 1 } keys %{ $Piston::shared->{catalog} };
   printf "%d тредов найдено\n", 0+ @target;
   @Piston::threads = @target;
}

2;

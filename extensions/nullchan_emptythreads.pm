use 5.010;
use strict;
use warnings;
use Carp;

use Piston::Extensions;
use Boards::Nullchan;

extension(
   if => sub {
		$Piston::config->{extensions}->{enable_all}
		&&
		$Piston::config->{chan} eq "nullchan"
		&&
		$Piston::config->{extensions}->{nullchan}->{emptythreads}->{enable}
   },
   name => "Бамп пустых тредов",
   init => \&refresh,
   main => \&refresh,
);

sub refresh
{
   my @target  = grep { $Piston::shared->{catalog}->{$_} <= 0 } keys %{ $Piston::shared->{catalog} };
   printf "%d тредов найдено\n", 0+ @target;
   @Piston::threads = @target;
}

2;

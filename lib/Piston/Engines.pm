package Piston::Engines;

use 5.010;
use strict;
use warnings;
use Carp;

use base "Exporter";
our @EXPORT = qw//;

sub init
{
   eval sprintf("use Piston::Engines\::%s", ucfirst $Piston::config->{thischan}->{engine});
   die "Ошибка или неизвестный движок: $@" if $@;
   if($Piston::config->{thischan}->{captcha}->{recaptcha})
   {
      eval "use Piston\::Engines::Recaptcha; 1" or die $@;
   }
}

2;

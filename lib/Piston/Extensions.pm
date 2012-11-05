package Piston::Extensions;

use 5.10.1;
use strict;
use warnings;
use Carp;

use base "Exporter";
our @EXPORT = qw/extension/;

use File::Basename qw/dirname basename/;
use Term::ANSIColor qw/color colored/;

use Yoba;

return 2 unless $Piston::config->{enable_extensions};

our $shared = {};

our @points = qw/
   init main exit
   before_captcha_request after_captcha_request
   before_post_request after_post_request
/;

#----------------------------------------
# Создание расширения
#----------------------------------------

# -> {}
sub extension {
   my $args = {@_};
   return if($args->{if} && !$args->{if}->());
   for my $point (@points) {
      Carp::croak "Неверный приоритет" if($args->{prio} && not $args->{prio} ~~ [0 .. 10]);
      next unless defined $args->{$point};
      my $ext = {
         name => $args->{name} || "noname",
         prio => $args->{prio} || 0,
         code => $args->{$point},
         fname => basename((caller)[1]),
      };
      say colored("   $ext->{fname}", "green") unless $ext->{fname} ~~ @{ $shared->{loaded} };
      push @{ $shared->{loaded} }, $ext->{fname};
      push @{ $shared->{$point} }, $ext;
   }
   return;
}

#----------------------------------------
# Точки запуска
#----------------------------------------

no strict "refs";

for my $pos (@points) {
   *{__PACKAGE__ . "::" . $pos} = sub {
      return unless $shared->{$pos};
      my(@args) = @_;
      for my $ext (sort { $a->{prio} < $b->{prio} } @{ $shared->{$pos} }) {
         try {
            $ext->{code}->(@args);
         } catch {
            print colored("Расширение '$ext->{name}': $_", "red");
         };
      }
   };
}

2;

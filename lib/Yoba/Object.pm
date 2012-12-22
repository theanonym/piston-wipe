#----------------------------------------
#
# Yoba ООП система, автоматически создающая метод new,
# конструктор и геттеры/сеттеры для членов класса.
#
# package Point;
#
# use Yoba::Object;
#
# has "x";
# hax "y";
#
# my $p = new Point(x => 1, y => 2); # Yoba-конструктор
# $p->x;    # Геттер
# $p->x(3); # Сеттер
#
#----------------------------------------

package Yoba::Object;

use 5.010;
use strict;
no strict "refs";
use warnings;
use Carp;

our %count;

sub import
{
   my $package = caller;
   *{ $package . "::new" }     = \&_constructor;
   *{ $package . "::DESTROY" } = \&_destructor;
   *{ $package . "::has" }     = \&_add_method;
}

sub _constructor
{
   my $package = shift;
   my $self = bless { @_ }, $package;
   if(defined *{ $package . "::CONSTRUCT" })
   {
      $self->CONSTRUCT;
   }
   $count{$package}++;
   return $self;
}

sub _destructor
{
   my $self = shift;
   my $package = ref $self;
   if(defined *{ $package . "::DESTRUCT" })
   {
      $self->DESTRUCT;
   }
   $count{$package}--;
}

sub _add_method
{
   my $package = caller;
   my($var) = @_;
   unless(defined *{ $package . "::" . $var })
   {
      *{ $package . "::" . $var} = sub {
         my($self, $value) = @_;
         if(defined $value)
         {
            $self->{$var} = $value;
            return $self;
         }
         else
         {
            Carp::croak "'$var' undefined" unless defined $self->{$var};
            return $self->{$var};
         }
      }
   }
   else
   {
      Carp::croak "$package\::$var already defined";
   }
}

2;

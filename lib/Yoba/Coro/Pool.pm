package Yoba::Coro::Pool;

use v5.10;
use strict;
use warnings;
use Carp;

use Params::Check qw/check/;

use Yoba::Object;
use Yoba::Coro;

sub CONSTRUCT {
   my $self = shift;
   #----------------------------------------
   Carp::croak "Неверные агументы коструктору" unless check({
      desc  => {},
      debug => {},
      limit => {},
      timelimit => {},
      semaphore => {},
      params => {},
      function  => { defined => 1 },
   }, $self, 1);
   #----------------------------------------
   $self->{desc} //= "";
   #----------------------------------------
   $self->{semaphore} = new Coro::Semaphore($self->{limit}) if $self->{limit};
   #----------------------------------------
   $self->{threads} = [map {
      new Yoba::Coro(
         desc  => $self->{desc},
         debug => $self->{debug},
         timelimit => $self->{timelimit},
         semaphore => $self->{semaphore},
         param => $_,
         function  => $self->{function},
      );
   } @{ $self->{params} }];
   undef $self->{params};
   #----------------------------------------
}

# <- (int)
sub start_all {
   my $self = shift;
   return map { $_->{coro}->ready } @{ $self->{threads} };
}

# <- (any)
sub join_all {
   my $self = shift;
   return map { $_->{coro}->join } @{ $self->{threads} };
}

2;

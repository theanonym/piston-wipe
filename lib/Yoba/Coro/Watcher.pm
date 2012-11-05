package Yoba::Coro::Watcher;

use v5.10;
use strict;
use warnings;
use Carp;

use Time::HiRes qw/time/;
use Params::Check qw/check/;

use Coro::State;
use AnyEvent;

use Yoba::Object;

sub CONSTRUCT {
   my $self = shift;
   #----------------------------------------
   Carp::croak "Неверные агументы коструктору" unless check({
      interval => {},
      desc     => {},
   }, $self, 1);
   #----------------------------------------
   $self->{interval} ||= 1;
   #----------------------------------------
   $self->{timer} = AnyEvent->timer(
      interval => $self->{interval},
      cb => \&_cb,
   );
}

sub _cb {
   my $time = time;
   for my $coro (grep { ($_->{desc} && $_->{desc} !~ /^\[/) || !$_->{desc} } Coro::State::list) {
      if($coro->{timeout_at} && $time >= $coro->{timeout_at}) {
         $coro->cancel(0);
      }
   }
}

2;

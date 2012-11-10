package Yoba::Coro;

use 5.010;
use strict;
use warnings;
use Carp;

use base "Exporter";
our @EXPORT = qw/sleep/;

use Time::HiRes qw/time/;
use Params::Check qw/check/;

use Coro;
use Coro::LWP;
use Coro::AnyEvent; #*sleep = \&Coro::AnyEvent::sleep;

use Yoba;
use Yoba::Object;
use Yoba::Coro::Watcher;
use Yoba::Coro::Pool;

our $id = 1;

sub CONSTRUCT {
   my $self = shift;
   #----------------------------------------
   Carp::croak "Неверные агументы коструктору" unless check({
      id    => {},
      desc  => {},
      debug => {},
      timelimit => {},
      semaphore => {},
      param => {},
      function  => { defined => 1 },
   }, $self, 1);
   #----------------------------------------
   $self->{id}   //= $id++;
   $self->{desc} //= "";
   $self->{coro}->{desc} = $self->{desc};
   #----------------------------------------
   $self->{coro} = new Coro(sub {
      my $coro = $Coro::current;
      $self->{semaphore}->down if $self->{semaphore};
      $coro->{timeout_at} = time + $self->{timelimit} if $self->{timelimit};
      #----------------------------------------
      $coro->on_destroy(sub {
         $self->{semaphore}->up if $self->{semaphore};
         my($ret) = @_;
         $ret //= 0;
         if($self->{debug}) {
            say "Thread #$$self{id} ($$self{desc}) canceled: $ret";
         }
         return $ret;
      });
      #----------------------------------------
      if($self->{debug}) {
         say "Thread #$$self{id} ($$self{desc}) started";
      }
      return $self->{function}->(delete $self->{param});
   });
   #----------------------------------------
}

# <- int
sub start { return $_[0]->{coro}->ready }

# <- any
sub join  { return $_[0]->{coro}->join }

2;

#!/usr/bin/perl
#----------------------------------------
#
# Скрипт для проверки прокси на работоспособность.
#
#----------------------------------------

use 5.010;
use strict;
use warnings;
use Carp;

use lib "lib";

use File::Slurp qw/write_file/;
use List::Util qw/shuffle/;
use Getopt::Long qw/GetOptions/;

eval "use LWP::Protocol::socks"; warn $@ if $@;

use Yoba;
use Yoba::LWP;
use Yoba::Coro;

my $opt = {
   infile  => undef,
   outfile => undef,

   url      => "http://0chan.hk/vg",
   threads  => 500,
   time     => 20,
   attempts => 1,
   wait     => 3,
};

GetOptions($opt,
   "infile=s", "outfile=s",
   "url=s", "threads=s",
   "time=s", "attempts=s",
   "skip=s", "wait=s",
   "help" => sub { print_help(); exit }
);

sub print_help {
   say <<HLP;
Yoba proxy checker

Использование:
   perl $0 [аргументы]

Справка:
   --in(file)   | Входной файл
   --ou(tfile)  | Выходной файл
   --sk(ip)     | Файл с прокси, которые нужно проигнорировать

   --ur(l)      | Адрес для проверки прокси ($opt->{url} по умолчанию)
   --th(reads)  | Количество потоков ($opt->{threads} по умолчанию)
   --ti(me)     | Ограничение по времени для каждой прокси ($opt->{time} по умолчанию)
   --at(tempts) | Попыток проверить прокси ($opt->{attempts} по умолчанию)

Примеры:
   --url http://0chan.hk/vg/  -i all_proxy.txt  -o proxylist.txt
HLP
}

Carp::croak "Не удалось найти файл '$opt->{infile}'" unless -f $opt->{infile};

my @proxies = Yoba::read_proxylist($opt->{infile});
my @ignore = Yoba::read_proxylist($opt->{outfile}) if -f $opt->{outfile};
if($opt->{skip}) {
   push @ignore, Yoba::read_proxylist($opt->{skip}) if -f $opt->{skip};
}
@proxies = grep { not $_ ~~ @ignore } @proxies;
@proxies = shuffle @proxies;

my @result;
my $w = new Yoba::Coro::Watcher;
while(my @part = splice @proxies, 0, 1000) {
   my $threads = new Yoba::Coro::Pool(
      debug => 1,
      desc => "check",
      timelimit   => $opt->{time},
      limit       => $opt->{threads},
      params  => \@part,
      function => \&check_func,
   );

   $threads->start_all;
   $threads->join_all;
   undef $threads;
}

write_file($opt->{outfile}, { append => 1 }, join("\n", @result) . "\n");

sub check_func {
   my($proxy) = @_;
   my $lwp = new Yoba::LWP;
   $lwp->agent("Opera/9.80 (X11; Linux i686; U; en) Presto/2.10.289 Version/12.00");
   $lwp->proxy($proxy);
   for(1 .. $opt->{attempts}) {
      my $response = $lwp->head($opt->{url});
      if( $response->is_success) {
         push @result, $proxy;
         if(@result >= 5) {
            write_file($opt->{outfile}, { append => 1 }, join("\n", @result) . "\n");
            @result = ();
         }
         return $proxy . ": " . sprintf("+ %s +", $response->status_line);
      } elsif($_ >= $opt->{attempts}) {
         return $proxy . ": " . $response->status_line;
      } else {
         Coro::AnyEvent::sleep $opt->{wait};
      }
   }
   return;
}

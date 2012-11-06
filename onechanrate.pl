#!/usr/bin/perl

use 5.10.1;
use strict;
use warnings;

use lib "lib";

use File::Slurp qw/read_file write_file/;
use File::Path qw/rmtree mkpath/;
use File::Spec::Functions qw/catfile catdir tmpdir/;
use Getopt::Long;

use Yoba;
use Yoba::LWP;
use Yoba::Coro;
use Yoba::OCR;
use Coro::AnyEvent;

my $opt = {
   rate    => 1,
   count   => 100,
   skip    => 0,

   tmpdir    => catdir(tmpdir, "piston_wipe", "onechan_rate"),

   ocr_mode => "hands",
};

GetOptions($opt,
   "rate=s", "count=s", "skip=s",
   "thread=s", "proxylist=s", "tmpdir=s",
   "ocr_mode=s",
   "clear" => sub { clear(); exit },
   "help"  => sub { print_help(); exit },
);

sub print_help {
   say <<HLP;
Yoba onechan plusoner

Использование:
   perl $0 [аргументы]

Справка:
   --ra(te)   | Голос (1 или 0)
   --th(read) | Оцениваемый тред

   --co(unt)  | Количество используемых прокси ($opt->{count} по умолчанию)
   --sk(ip)   | Сколько прокси пропустить в начале файла

   --pr(oxy)  | Файл с прокси

   --cl(ear)  | Удалить временные файлы

Примеры:
   --thread 1000000 --rate 1 --count 50  --proxylist proxies.txt
HLP
}

#----------------------------------------

Carp::croak("Файл с проски не указан или не существует") unless -f $opt->{proxylist};

mkpath($opt->{tmpdir});

my $lwp = new Yoba::LWP;
$lwp->agent("Opera/9.80 (X11; Linux i686; U; en) Presto/2.10.289 Version/12.00");
$lwp->referer("http://1chan.ru/");

my @proxies = Yoba::read_proxylist($opt->{proxylist});
@proxies = splice(@proxies, $opt->{skip}, $opt->{count});
printf "%d прокси загружено\n", scalar @proxies;

#----------------------------------------

my @captcha;
for my $proxy (@proxies) {
   my $lwp = $lwp->clone;
   $lwp->proxy($proxy);
   $lwp->cookie_jar({});

   push @captcha, {
      proxy => $proxy,
      lwp => $lwp,
      captcha => new Yoba::OCR(mode => $opt->{ocr_mode}, delete => 1),
   };
}

#----------------------------------------

my $w = new Yoba::Coro::Watcher;
my $threads;

$threads = new Yoba::Coro::Pool(
   desc  => "captcha",
   limit => $opt->{threads},
   timelimit => 20,
   params => \@captcha,
   function => sub {
      my($cap) = @_;
      if(rate($cap, $opt->{thread}, $opt->{rate})) {
         say "Ошибка или капча не нужна";
         return 1;
      } else {
         if(get_captcha($cap)) {
            say "Успешный запрос капчи";
            return 1;
         } else {
            say "Не удалось скачать капчу";
         }
      }
      return;
   }
);

$threads->start_all;
$threads->join_all;
undef $threads;

#----------------------------------------

@captcha = grep { $_->{captcha}->has_file } @captcha;
my $all = @captcha;
my $count = 1;
@captcha = grep {
   $_->{captcha}->run("$count/$all");
   $count++;
   $_->{captcha}->is_entered;
} @captcha;

#----------------------------------------

$threads = new Yoba::Coro::Pool(
   desc  => "rate",
   limit => $opt->{threads},
   timelimit => 30,
   params => \@captcha,
   function => sub {
      my($cap) = @_;
      say "Оценка поста";
      return rate($cap, $opt->{thread}, $opt->{rate});
   }
);

$threads->start_all;
$threads->join_all;
undef $threads;

exit;

#----------------------------------------

# -> {lwp => Yoba::LWP, captcha => Yoba::OCR}
# <- bool
sub get_captcha($) {
   my($cap) = @_;
   my($sessid) = $cap->{lwp}->cookie_jar->as_string =~ /(PHPSESSID=\w+)/;
   for(1 .. 3) {
      my $res = $cap->{lwp}->get("http://1chan.ru/captcha/?key=rate&$sessid");
      if($res->headers->{"content-type"} =~ /image\/(\w+)/) {
         my $fname = catfile($opt->{tmpdir}, substr(rand, -6) . ".$1");
         write_file($fname, $res->{_content});
         $cap->{captcha}->file($fname);
         return 1;
      }
      Coro::AnyEvent::sleep 3 if $_ < 5;
   }
   return;
}

# -> {lwp => Yoba::LWP, captcha => Yoba::OCR}, int, bool
# <- bool
sub rate($$$) {
   my($cap, $thread, $rate) = @_;
   my $key = $rate ? "up" : "down";
   if($cap->{captcha}->is_entered) {
      for(1 .. 5) {
         my $res = $cap->{lwp}->post("http://1chan.ru/news/res/$thread/rate_post/$key/",
            Content_Type => "application/x-www-form-urlencoded",
            Content => "referer=http://1chan.ru/news/all/&captcha_key=rate&captcha=$$cap{captcha}{text}",
         );
         return 1 if $res->is_success;
         Coro::AnyEvent::sleep 3 if $_ < 5;
      }
   } else {
      for(1 .. 5) {
         my $res = $cap->{lwp}->get("http://1chan.ru/news/res/$thread/rate_post/$key/");
         if($res->is_success && defined $res->headers->{title}) {
            return if $res->headers->{title} =~ /Голосование за пост/;
         }
         Coro::AnyEvent::sleep 3 if $_ < 5;
      }
   }
   return 1;
}

sub clear {
   unlink glob catfile($opt->{tmpdir}, "*");
}

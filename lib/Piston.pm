package Piston;

use 5.010;
use strict;
use warnings;
use Carp;

use File::Slurp qw/read_file write_file/;
use File::Path qw/rmtree mkpath/;
use File::Spec::Functions qw/tmpdir catfile catdir/;

use Term::ANSIColor qw/color colored/;

#eval "use LWP::Protocol::socks"; warn $@ if $@;

use Yoba;
use Yoba::LWP;
use Yoba::Coro;
use Yoba::OCR;

use Piston::Wipe;
use Piston::Postform;
use Piston::Engines;

our $config;
our $chans;

BEGIN {
   our $VERSION = "2.7.7";
   our $opt;

   require "config/config.pl";
   require "config/chans.pl";

   require Piston::Extensions;

   if($config->{postform}->{text_mode}) {
      $config->{postform}->{text} = "";
   }

   $config->{thischan} = $chans->{$config->{chan}};

   $config->{tmp} = catfile(tmpdir(), "piston_wipe");
   $config->{tmpdir} = catfile($config->{tmp}, $config->{chan});
   mkpath($config->{tmpdir});

   $config->{wait} = $config->{thischan}->{
      $config->{threads}->[0] ? "posts_delay" : "threads_delay"
   } || 1;
}


#----------------------------------------
# Глобальные переменные
#----------------------------------------

our @_threads;
our @threads;
our $last_thread;
our $wait_threads = 0;
our $killed_threads = 0;

our @proxies;
our %errors;

our $captcha_semaphore;
our $post_semaphore;
our $watcher;

#----------------------------------------
# Инициализация
#----------------------------------------

# Выход
$SIG{INT} = sub {
   say colored("\n--- Завершение ---", "yellow bold");
   Piston::Extensions::exit() if $Piston::config->{extensions}->{enable_all};
   exit;
};

sub init {
   @_threads = @{ $Piston::config->{threads} };
   @threads  = @{ $Piston::config->{threads} };

   $captcha_semaphore = new Coro::Semaphore($Piston::config->{max_connections});
   $post_semaphore    = new Coro::Semaphore($Piston::config->{max_connections});
   $watcher = new Yoba::Coro::Watcher;

   @proxies = (0, load_proxies());

   if($Piston::config->{extensions}->{enable_all})
   {
      load_extensions();
      Piston::Extensions::init()
   }
}

sub run {
   given($Piston::config->{wipe_mode}) {
      when(1) {
         my $pool = new Yoba::Coro::Pool(
            debug     => 0,
            desc      => "wipe",
            params    => \@proxies,
            function  => \&wipe_func_1,
         );

         $pool->start_all;
      } when(2) {
         my $main_thread = new Yoba::Coro(
            debug     => 0,
            desc     => "wipe",
            param    => \@proxies,
            function => \&wipe_func_2,
         );

         $main_thread->start;
      }
   }

   while(1) {
      Piston::sleep_this_thread(2);
      Piston::Extensions::main() if $Piston::config->{extensions}->{enable_all};
      #----------------------------------------
   }
}

# -> string
sub wipe_func_1($) {
   my($proxy) = @_;
   $errors{$proxy} = 0;
   main: while( $errors{$proxy} < $Piston::config->{errors_limit} ) {
      my $wipe = new Piston::Wipe( proxy => $proxy );
      #----------------------------------------
      #unless($Piston::config->{pregen}) {
         unless(@threads) {
            say "Нет треда, ожидание.";
            until(@threads)
            {
               $wait_threads++;
               Piston::sleep_this_thread(1);
               $wait_threads--;
            }
         }
         $wipe->set_thread;
      #}
      #----------------------------------------
      if($Piston::config->{thischan}->{captcha}) {
         my $t = get_captcha($wipe);
         $t->start;
         $t->join;
         if($wipe->{captcha}->has_file) {
            $errors{$proxy} = -1;
            $wipe->run_ocr;
            $wipe->log(3, "КАПЧА", "Капча не введена!") unless $wipe->{captcha}->is_entered;
         } else {
            $errors{$proxy}++ if $errors{$proxy} != -1;
         }
      }
      #----------------------------------------
      if(!$Piston::config->{thischan}->{captcha} || $wipe->{captcha}->is_entered) {
         my $t = send_post($wipe);
         $t->start;
         $t->join;
      }
   }

   say colored("$proxy завершено (лимит ошибок)", "cyan");
   $killed_threads++;
   return;
}

# -> [string]
sub wipe_func_2($) {
   my($proxies) = @_;

   map { $errors{$_} = 0; } @$proxies;

   main: while(1) {
      my @wipes = map {
         new Piston::Wipe(proxy => $_);
      } grep {
         my $bad_proxy = $errors{$_} >= $Piston::config->{errors_limit};
         do {
            say colored("$_ завершено (лимит ошибок)", "cyan");
            $killed_threads++;
         } if $bad_proxy && $errors{$_} != -1;
         !$bad_proxy;
      } @$proxies;

      last main unless @wipes;

      unless(@Piston::threads)
      {
         say "Нет треда, ожидание.";
         until(@Piston::threads)
         {
            $wait_threads = @wipes;
            Coro::AnyEvent::sleep(1);
            $wait_threads = 0;
         }
      }

      if($Piston::config->{thischan}->{captcha}) {
         # Загрузка капч
         my $captcha_pool = new Yoba::Coro::Pool(
            debug => 0,
            desc     => "captcha",
            params   => \@wipes,
            timelimit => $Piston::config->{captcha_timelimit},
            semaphore => $captcha_semaphore,
            function => \&captcha_request_func,
         );

         $captcha_pool->start_all;
         $captcha_pool->join_all;

         @wipes = grep { !$Piston::config->{thischan}->{captcha} || $_->{captcha}->has_file } @wipes;

         # Ввод капч
         my @antigate_threads;

         my $count = @wipes;
         my $i = 1;
         map {
            my $wipe = $_;
            $errors{$wipe->{proxy}} = -1;

            if($Piston::config->{ocr_mode} =~ /antigate/) {
               push @antigate_threads, Coro::async {
                  $wipe->run_ocr(title => "$i/$count");
               };
            } else {
               $wipe->run_ocr(title => "$i/$count");
               $i++;
               $wipe->log(3, "КАПЧА", "Капча не введена!") unless $wipe->{captcha}->is_entered;
            }
         } @wipes;

         if($Piston::config->{ocr_mode} =~ /antigate/ && @antigate_threads) {
            $_->join for @antigate_threads;
         }

         @wipes = grep { $_->{captcha}->is_entered } @wipes;
      }

      # Отправка постов
      my $posting_pool = new Yoba::Coro::Pool(
         debug => 0,
         desc     => "post",
         params   => \@wipes,
         timelimit => $Piston::config->{post_timelimit},
         semaphore => $post_semaphore,
         function => \&post_request_func,
      );

      $posting_pool->start_all;
      $posting_pool->join_all;

      my $wait = $Piston::threads[0] == 0 ?
         $Piston::config->{thischan}->{threads_delay}
         :
         $Piston::config->{thischan}->{posts_delay};
      if($wait)
      {
         $Piston::wait_threads = @wipes;
         say colored("Ожидание $wait с", "cyan");
         Piston::sleep_this_thread($wait);
         $Piston::wait_threads = 0;
      }
   }
}

#--------------------------------------------------------------------------------

#----------------------------------------
# Функции для вайпа
#----------------------------------------

# -> Piston::Wipe
# <- Yoba::Coro
sub get_captcha($) {
   my($wipe) = @_;
   return new Yoba::Coro(
      debug     => 0,
      desc      => "captcha",
      timelimit => $Piston::config->{captcha_timelimit},
      semaphore => $captcha_semaphore,
      param     => $wipe,
      function  => \&captcha_request_func,
   );
}

# -> Piston::Wipe
# <- Yoba::Coro
sub send_post($) {
   my($wipe) = @_;
   return new Yoba::Coro(
      debug     => 0,
      desc      => "post",
      timelimit => $Piston::config->{post_timelimit},
      semaphore => $post_semaphore,
      param     => $wipe,
      function  => \&post_request_func,
   );
}

# -> Piston::Wipe
# <- bool
sub captcha_request_func
{
   my($wipe) = @_;
   my $errcode;
   for my $att (1 .. $Piston::config->{captcha_attempts})
   {
      $wipe->before_captcha_request;
      $wipe->captcha_request;
      $errcode = $wipe->after_captcha_request;
      given($errcode)
      {
         # Успешно
         when(0) { last; }
         # Ошибка
         when(1) { Piston::sleep_this_thread(5) if $att < $Piston::config->{captcha_attempts}; }
         # Фатальная ошибка
         when(2) { Piston::kill_this_thread(); }
      }
   }
   return !!$errcode;
}

# -> Piston::Wipe
# <- bool
sub post_request_func
{
   return unless @threads;
   my($wipe) = @_;
   my $errcode;
   for my $att (1 .. $Piston::config->{post_attempts})
   {
      $wipe->before_post_request;
      $wipe->post_request;
      $errcode = $wipe->after_post_request;
      given($errcode)
      {
         # Успешно
         when(0) { last; }
         # Ошибка (пост может быть отправлен)
         when(1) { Piston::sleep_this_thread(5) if $att < $Piston::config->{post_attempts}; }
         # Ошибка (пост НЕ может быть отправлен)
         when(2) { last; }
         # Фатальная ошибка
         when(3) { Piston::kill_this_thread(); }
      }
   }
   return !!$errcode;
}

#--------------------------------------------------------------------------------

#----------------------------------------
# Прочие функции
#----------------------------------------

# Удаление треда (из @threads)
# -> int
sub delete_thread($) {
   my($thread) = @_;
   my $i = Yoba::array_find(\@threads, $thread);
   return if $i == -1;
   splice(@threads, $i, 1);
   $last_thread = int rand @threads;
   return;
}

sub sleep_this_thread($) {
   my($s) = @_;
   my $coro = $Coro::current;
   if($coro->{timeout_at}) {
      $coro->{timeout_at} += $s;
   }
   Coro::AnyEvent::sleep $s;
}

sub kill_this_thread {
   $killed_threads++;
   $Coro::current->cancel(0);
}

# Загрузка прокси.
# <- (string)
sub load_proxies {
   return unless $Piston::config->{use_proxy};
   my $fname = $Piston::config->{proxylist};
   die "Не найден проксилист '$Piston::config->{proxylist}'" unless -f $Piston::config->{proxylist};
   my @proxy = Yoba::read_proxylist($fname);
   my $all = @proxy;
   #----------------------------------------
   if(-s "$Piston::config->{chan}_bad_proxy.txt") {
      my @ignore = read_proxylist "$Piston::config->{chan}_bad_proxy.txt";
      @proxy = grep { not $_ ~~ @ignore } @proxy;
   }
   #----------------------------------------
   @proxy = splice(
         @proxy,
         $Piston::config->{proxies_ignore} || 0,
         $Piston::config->{proxies_max},
   ) if $Piston::config->{proxies_max};
   if(@proxy) {
      #TODO s/(\d+)/color("yellow") . $1 . color("reset")/ge
      say colored(scalar(@proxy), "yellow"),
          colored(" прокси загружены из файла '$fname' и ", "cyan"),
          colored($all - scalar(@proxy), "yellow"),
          colored(" проигнорированы.", "cyan");
      return @proxy;
   } else {
      Carp::carp colored("Не удалось загрузить прокси из файла '$fname'", "red");
   }
}

# Загрузка расширений.
sub load_extensions {
   use lib "extensions";
   my @files = Yoba::find_files(
      path  => catdir(".", "extensions"),
      regex => qr/\.(?:pl|pm)$/,
   );
   if(@files) {
      say colored("Загрузка расширений", "yellow bold");
      require for @files;
   }
   return;
}

2;

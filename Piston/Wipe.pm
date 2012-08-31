package Piston::Wipe;

use 5.010;
use strict;
use warnings;
use Carp;

use Encode qw/encode decode/;
use File::Spec::Functions qw/catfile catdir/;
use File::Slurp qw/read_file write_file/;
use Term::ANSIColor qw/color colored/;
use Time::HiRes qw/time/;

use LWP;

use Yoba;
use Yoba::Object;

use Piston::Engines;
use Piston::Postform;

our $lwp;

sub init {
   #----------------------------------------
   $lwp = new Yoba::LWP;
   $lwp->referer($Piston::config->{thischan}->{url});
   $lwp->agent("Opera/9.80 (X11; Linux i686; U; en) Presto/2.10.289 Version/12.00");
   #----------------------------------------
   return 1;
}

sub CONSTRUCT {
   my $self = shift;
   #----------------------------------------
   $self->{lwp} = $lwp->clone;
   $self->{lwp}->proxy($self->{proxy}) if $self->{proxy};
   $self->{lwp}->cookie_jar({});
   #----------------------------------------
   $self->{captcha} = new Yoba::OCR(
      mode   => $Piston::config->{ocr_mode},
      delete => 1,
      args   => $Piston::config->{thischan}->{tesseract},
   );
   #----------------------------------------
   if($Piston::config->{pregen}) {
      $self->set_board;
      $self->set_thread;
      $self->{postform} = new Piston::Postform(wipe => $self);
      if($Piston::config->{thischan}->{captcha}) {
         $self->{captcha_request} = Piston::Engines::captcha_request($self);
      }
      $self->{post_request} = Piston::Engines::post_request($self);
   }
}

sub before_captcha() {
   my $self = shift;
   #----------------------------------------
   unless($Piston::config->{pregen}) {
      $self->{captcha_request} = Piston::Engines::captcha_request($self);
   }
   Piston::Extensions::before_captcha_request($self) if $Piston::config->{enable_extensions};
   #----------------------------------------
   return;
}

sub get_captcha() {
   my $self = shift;
   #----------------------------------------
   # $self->log(1, "КАПЧА", "Запрос капчи");
   $self->{captcha_response} = $self->{lwp}->request($self->{captcha_request});
   #----------------------------------------
   return;
}

# <- int(1 - успешно, 0 - ошибка, -1 - фатальная ошибка)
sub after_captcha() {
   my $self = shift;

   my($code, $error) = (Piston::Engines::handle_captcha_response($self));

   given($code) {
      when(1) {
         $self->log(2, "КАПЧА", "Капча получена");
         my($fmt) = $self->{captcha_response}->{_headers}->{"content-type"} =~ /image\/(.*)/;
         my $fname = catfile($Piston::config->{tmpdir}, substr(rand, -10) . ".$fmt");
         write_file($fname, { binmode => ":raw" }, $self->{captcha_response}->{_content});
         Carp::carp "С капчей что-то не так" unless -f $fname;
         $self->{captcha}->{file} = $fname;
      } when([2, 3]) {
         $self->log(4, "КАПЧА", $error);
      }
   }

   if($code == 3) {
      Piston::kill_this_thread();
   }

   $self->{captcha_status} = 1  if $code == 1;
   $self->{captcha_status} = 0  if $code == 2;
   return $self->{captcha_status};
}

sub before_post() {
   my $self = shift;
   #----------------------------------------
   unless($Piston::config->{pregen}) {
      $self->set_board;
      $self->set_thread;
      $self->{postform} = new Piston::Postform(wipe => $self);;
      if($Piston::config->{thischan}->{captcha}) {
         $self->{captcha_request} = Piston::Engines::captcha_request($self);
      }
      $self->{post_request} = Piston::Engines::post_request($self);
   }
   Piston::Extensions::before_post_request($self) if $Piston::config->{enable_extensions};
   #----------------------------------------
   return;
}

sub send_post() {
   my $self = shift;
   #----------------------------------------
   $self->log(1, "ПОСТИНГ", "Отправка поста /$$self{board}/$$self{thread}, c:$$self{captcha}{text}");
   $self->{post_response} = $self->{lwp}->request($self->{post_request});
   return;
}

# <- int(1 - успешно, 0 - ошибка, -1 - фатальная ошибка)
sub after_post() {
   my $self = shift;

   my($code, $error) = (Piston::Engines::handle_post_response($self));

   given($code) {
      when(1) {
         $self->log(2, "ПОСТИНГ",
            "Пост отправлен успешно /$$self{board}/$$self{thread}, c:$$self{captcha}{text}"
         );
      } when([2, 3, 5]) {
         $self->log(3, "ПОСТИНГ", $error);
      } when([4]) {
         $self->log(4, "ПОСТИНГ", $error);
      }
   }

   if($code == 5) {
      Piston::kill_this_thread();
   }

   Piston::Extensions::after_post_request($self) if $Piston::config->{enable_extensions};

   $self->{post_status} = 1  if $code == 1;
   $self->{post_status} = 0  if $code ~~ [2, 4];
   $self->{post_status} = -1 if $code == 3;
   return $self->{post_status};
}

# -> (any)
# <- bool
sub run_ocr(@) {
   my $self = shift;
   my(@args) = @_;
   $self->{captcha}->run(@args);
   return $self->{captcha}->is_entered;
}

# -> string
sub set_board(;$) {
   my $self = shift;
   my($board) = @_;
   # return if defined $self->{board};
   if(defined $board) {
      $self->{board} = $board;
      return;
   }
   $self->{board} = $Piston::config->{board};
   return;
}

# -> string
sub set_thread(;$) {
   my $self = shift;
   my($thread) = @_;
   # return if defined $self->{thread};
   #----------------------------------------
   if(defined $thread) {
      $self->{thread} = $thread;
      $Piston::last_thread = rand $#Piston::threads;
      return;
   }
   if(@Piston::threads > 1) {
      if(!defined $Piston::last_thread || $Piston::last_thread == $#Piston::threads ) {
         $self->{thread} = $Piston::threads[0];
         $Piston::last_thread = 0;
      } else {
         $self->{thread} = $Piston::threads[$Piston::last_thread + 1];
         $Piston::last_thread += 1;
      }
   } else {
      $self->{thread} = $Piston::threads[0];
   }
   #----------------------------------------
   unless(defined $self->{thread}) {
      Carp::carp "Не удалось выбрать тред (Треды: @Piston::threads, индекс последнего: $Piston::last_thread)" ;
      $self->{thread} = $Piston::threads[rand @Piston::threads];
      $Piston::last_thread = 0;
   }
   #----------------------------------------
   return;
}

my @colors = qw/blue green yellow red/;

# -> int, string, string
sub log($$$) {
   my $self = shift;
   my($loglevel, $type, $string) = @_;
   return if $loglevel > $Piston::config->{loglevel};
   #----------------------------------------
   my $color = $colors[$loglevel - 1];
   my $proxy = $self->{proxy} || "No proxy";
   #----------------------------------------
   no warnings "utf8";
   printf("%s%-9s %-29s %.50s%s\n", color($color), decode("utf-8", "[$type]"), "[$proxy]", decode("utf-8", $string), color("reset"));
   return;
}

2;

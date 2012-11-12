package Piston::Engines::Nullchan;

use 5.010;
use strict;
use warnings;
use Carp;

use base "Exporter";
our @EXPORT = qw/
   captcha_request
   post_request
   handle_captcha_response
   handle_post_response
/;

use File::Slurp qw/read_file write_file/;
use File::Basename qw/dirname basename/;
use HTTP::Request::Common qw/GET POST/;

use Yoba;

# -> Piston::Wipe
# <- HTTP::Request
sub captcha_request($) {
   my($wipe) = @_;
   my $url = Yoba::caturl($Piston::config->{thischan}->{url}, "captcha.php");
   my $request = GET($url);
   return $request;
}

# -> Piston::Wipe
# <- HTTP::Request
sub post_request($) {
   my($wipe) = @_;
   #----------------------------------------
   my $content = [
      board        => $wipe->{board},
      replythread  => $wipe->{thread},
      em           => $wipe->{postform}->{email},
      name         => $wipe->{postform}->{name},
      subject      => $wipe->{postform}->{subject},
      message      => $wipe->{postform}->{text},
      postpassword => $wipe->{postform}->{password},
      embed        => $wipe->{postform}->{video},
      embedtype    => "youtube",
   ];
   #----------------------------------------
   unless($Piston::config->{thischan}->{recaptcha}) {
      push @$content, (captcha => $wipe->{captcha}->{text});
   } else {
      push @$content, (
         recaptcha_challenge_field => $wipe->{recaptcha_key},
         recaptcha_response_field  => $wipe->{captcha}->{text},
      );
   }
   #----------------------------------------
   if($wipe->{postform}->has_image) {
      push @$content, (
         imagefile => [
            undef, basename($wipe->{postform}->{file}),
            Content_Type => "*/*",
            Content => $wipe->{postform}->{image},
         ],
      );
   }
   if($Piston::config->{chan} eq "nullchan" && $wipe->{board} eq "b") {
      push @$content, (mm => 0);
   }
   #----------------------------------------
   my $url = Yoba::caturl($Piston::config->{thischan}->{url}, "board.php");
   my $request = POST($url,
      Content_Type => "form-data",
      Content => $content,
   );
   return $request;
}

# -> Piston::Wipe
# <- int, string
# 1 - Успешно
# 2 - Ошибка
# 3 - Фатальная ошибка для этой прокси
sub handle_captcha_response($) {
   my($wipe) = @_;
   #----------------------------------------
   my $response = $wipe->{captcha_response};
   my($error, $code);
   #----------------------------------------
   my $fmt = $Piston::config->{thischan}->{captcha}->{type};
   if(exists $response->{_headers}->{"content-type"}
      && $response->{_headers}->{"content-type"} =~ /image\/$fmt/) {
      write_file("nullchan_good_proxy.txt", { append => 1 }, "$$wipe{proxy}\n");
      return(1, "");
   } else {
      ($error, $code) = ($response->status_line, 2);
   }
   #----------------------------------------
   if($response->{_rc} ~~ [400, 403] ||
      ($response->{_rc} == 200 &&
         (!exists $response->{_headers}->{"content-type"} ||
         $response->{_headers}->{"content-type"} !~ /image\/$fmt/))) {
      $code = 3;
      write_file("nullchan_bad_proxy.txt", { append => 1 }, "$$wipe{proxy}\n");
   }
   #----------------------------------------
   return($code, $error);
}

my $errors = {
   a => qr/(Вы\ постите\ очень\ часто)/xo,
   b => qr/(
      Неправильно\ введена\ капча|Этот\ файл\ уже\ загружен|
      тобы\ ответить,\ загрузите\ изображение|Flood\ detected|
      File\ transfer\ failure|BuildThread|Неправильный\ ID\ треда|
      possible\ proxy
   )/xo,
};

# -> Piston::Wipe
# <- int, string
# 1 - Пост отправлен успешно
# 2 - Ошибка движка, пост ещё может быть отправлен
# 3 - Ошибка движка, пост не может отправлен
# 4 - Ошибка соединения
# 5 - Фатальная ошибка для этой прокси
sub handle_post_response($) {
   my($wipe) = @_;
   #----------------------------------------
   my $response = $wipe->{post_response};
   my($error, $code);
   #----------------------------------------
   # Общая обработка
   if(exists $response->{_headers}->{location}) {
      # Успешно
      #($error, $code) = ("", 1);
      return(1, "");
   } elsif($response->{_rc} == 200) {
      given($response->{_content}) {
         when($errors->{a}) { ($error, $code) = ($1, 2) }
         when($errors->{b}) { ($error, $code) = ($1, 3) }
         default            { ($error, $code) = ("Неизвестная ошибка", 2) }
      }
   } else {
      ($error, $code) = ($response->status_line, 4);
   }
   #----------------------------------------
   # Исключительные ситуации
   # Ошибка 503 Forbidden
   if($response->{_rc} == 403) {
      $code = 5;
      write_file("nullchan_bad_proxy.txt", { append => 1 }, "$$wipe{proxy}\n");
   }
   # Забаненая прокси
   given($error) {
      when(["YOU ARE BANNED", "possible proxy"]) {
         $code = 5;
         write_file("bad_proxy.txt", { append => 1 }, "$$wipe{proxy}\n");
      } when(["BuildThread"]) {
         ($error, $code) = ("", 1);
      }
   }
   #----------------------------------------
   return($code, $error);
}

2;

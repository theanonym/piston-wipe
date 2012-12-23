package Piston::Engines::Alterchan;

use 5.010;
use strict;
use warnings;
use Carp;

use base "Exporter";
our @EXPORT = qw/
   make_captcha_request
   make_post_request
   handle_captcha_response
   handle_post_response
/;

use File::Slurp qw/read_file write_file/;
use File::Basename qw/dirname basename/;
use HTTP::Request::Common qw/GET POST/;

use Yoba;

# -> Piston::Wipe
# <- HTTP::Request
sub make_captcha_request($)
{
   die;
}

# -> Piston::Wipe
# <- HTTP::Request
sub make_post_request($)
{
   my($wipe) = @_;
   #----------------------------------------
   # Основные поля
   my $content = [
      board        => $wipe->{board},
      replythread  => $wipe->{thread},
      em           => $wipe->{postform}->{email},
      name         => $wipe->{postform}->{name},
      subject      => $wipe->{postform}->{subject},
      message      => $wipe->{postform}->{text},
      postpassword => $wipe->{postform}->{password},
      captcha      => $wipe->{captcha}->{text},
      embed        => $wipe->{postform}->{video},
      embedtype    => "youtube",
   ];
   #----------------------------------------
   # Картинка
   if($wipe->{postform}->has_image)
   {
      push @$content, (
         imagefile => [
            undef, basename($wipe->{postform}->{file}),
            Content_Type => "*/*",
            Content      => $wipe->{postform}->{image},
         ],
      );
   }
   #----------------------------------------
   return POST(
      caturl($Piston::config->{thischan}->{url}, "board.php"),
      Content_Type => "form-data",
      Content      => $content,
   );
}

# -> Piston::Wipe
# <- number, string
# 0 - Успешно
# 1 - Ошибка
# 2 - Фатальная ошибка для этой прокси
sub handle_captcha_response($)
{
   die;
}

my $errors = {
   a => qr/(
      ПУСТО
   )/xo,
   b => qr/(
      Unable\ to\ connect\ to|Please\ log\ in|
      Для\ ответа\ нужна\ картинка\ или\ сообщение
   )/xo,
};

# -> Piston::Wipe
# <- number, string
# 0 - Успешно
# 1 - Ошибка движка (пост может быть отправлен)
# 2 - Ошибка движка (пост не может быть отправлен)
# 3 - Ошибка движка (фатальная)
# 4 - Ошибка соединения (пост может быть отправлен)
# 5 - Ошибка соединения (фатальная)
sub handle_post_response($)
{
   my($wipe) = @_;
   my $response = $wipe->{post_response};
   #----------------------------------------
   my($errcode, $errstr);

   # Успешно (код 0)
   if(exists $response->{_headers}->{location})
   {
      ($errcode, $errstr) = (0, "");
   }

   # Ошибка движка (код 1 или 2)
   elsif($response->{_rc} == 200)
   {
      given($response->{_content})
      {
         when($errors->{a}) { ($errcode, $errstr) = (1, $1); }
         when($errors->{b}) { ($errcode, $errstr) = (2, $1); }
         default            { ($errcode, $errstr) = (1, "Неизвестная ошибка"); }
      }
   }

   # Ошибка соединения (код 4)
   else
   {
      ($errcode, $errstr) = (4, $response->status_line);
   }
   #----------------------------------------
   say $response->content if $errstr eq "Неизвестная ошибка";
   return ($errcode, $errstr);
}

2;
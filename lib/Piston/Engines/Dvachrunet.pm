package Piston::Engines::Dvachrunet;

use 5.010;
use strict;
use warnings;
use Carp;

#use LWP::Protocol::https;

use base "Exporter";
our @EXPORT = qw/
   make_captcha_request
   make_post_request
   handle_captcha_response
   handle_post_response
/;

use File::Slurp qw/read_file write_file/;
use File::Basename qw/dirname basename/;
use File::MimeInfo qw/mimetype/;
use HTTP::Request::Common qw/GET POST/;

use Yoba;

# -> Piston::Wipe
# <- HTTP::Request
sub make_captcha_request($)
{
   return GET(caturl($Piston::config->{thischan}->{url}, "captcha/"));
}

# -> Piston::Wipe
# <- HTTP::Request
sub make_post_request($)
{
   my($wipe) = @_;
   #----------------------------------------
   # Основные поля
   my $content = [
      parent   => $wipe->{thread},
      email    => $wipe->{postform}->{email},
      subject  => $wipe->{postform}->{subject},
      message  => $wipe->{postform}->{text},
      captcha  => $wipe->{captcha}->{text},
      password => $wipe->{postform}->{password},
   ];
   #----------------------------------------
   # Картинка
   if($wipe->{postform}->has_image)
   {
      push @$content, (
         file => [
            undef, basename($wipe->{postform}->{file}),
            Content_Type => mimetype($wipe->{postform}->{file}),
            Content      => $wipe->{postform}->{image},
         ],
      );
   }
   #----------------------------------------
   return POST(
      caturl($Piston::config->{thischan}->{url}, $wipe->{board}, "imgboard.php"),
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
   my($wipe) = @_;
   my $response = $wipe->{captcha_response};
   my $cfmt = $Piston::config->{thischan}->{captcha}->{type};
   #----------------------------------------
   my($errcode, $errstr);

   # Успешно (код 0)
   if(exists $response->{_headers}->{"content-type"} && $response->{_headers}->{"content-type"} =~ /image\/$cfmt/)
   {
      ($errcode, $errstr) = (0, "");
      write_file("$Piston::config->{chan}_good_proxy.txt", { append => 1 }, "$$wipe{proxy}\n");
   }

   # Фатальная ошибка (код 2)
   elsif($response->{_rc} ~~ [200, 400, 403, 404])
   {
      ($errcode, $errstr) = (2, $response->status_line);
      write_file("$Piston::config->{chan}_bad_proxy.txt", { append => 1 }, "$$wipe{proxy}\n");
   }

   # Обычная ошибка (код 1)
   else
   {
      ($errcode, $errstr) = (1, $response->status_line);

      #say $response->as_string;
   }
   #----------------------------------------
   return ($errcode, $errstr);
}

my $errors = {
   a => qr/(Подождите\ немного)/xo,
   b => qr/(
      Неверно\ введена\ капча|Капча\ не\ была\ сгенерирована|
      Вам\ закрыт\ доступ\ к\ доске
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
   if($response->{_content} =~ /Перенаправление\.\./)
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
         default            { print $response->as_string; ($errcode, $errstr) = (1, "Неизвестная ошибка"); }
      }
   }

   # Ошибка соединения (код 4)
   else
   {
      ($errcode, $errstr) = (4, $response->status_line);
   }
   #----------------------------------------
   # Фатальная ошибка соединения (код 5)
   if($response->{_rc} == 403)
   {
      $errcode = 5;
      write_file("$Piston::config->{chan}_bad_proxy.txt", { append => 1 }, "$$wipe{proxy}\n");
   }

   # Фатальная ошибка движка (код 3)
   if($errstr ~~ ["Вам закрыт доступ к доске"])
   {
      $errcode = 3;
      write_file("$Piston::config->{chan}_bad_proxy.txt", { append => 1 }, "$$wipe{proxy}\n");
   }

   # Пост отправлен успешно (код 0)
   if($errstr ~~ ["BuildThread"])
   {
      ($errcode, $errstr) = (0, "");
   }
   #----------------------------------------
   return ($errcode, $errstr);
}

2;

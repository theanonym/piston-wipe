package Piston::Engines::Iichan;

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
use File::MimeInfo qw/mimetype/;
use HTTP::Request::Common qw/GET POST/;

use Yoba;

# -> Piston::Wipe
# <- HTTP::Request
sub make_captcha_request($)
{
   my($wipe) = @_;
   # Доска: http://iichan.hk/cgi-bin/captcha1.pl/b/?key=mainpage&dummy=
   # Тред:  http://iichan.hk/cgi-bin/captcha1.pl/b/?key=res%thread%&dummy=
   return GET(caturl(
      $Piston::config->{thischan}->{url},
      sprintf(
         "/cgi-bin/%s/$$wipe{board}/?key=%s&dummy=",
         ($wipe->{board} =~ /b|a/o ? "captcha1.pl" : "captcha.pl"),
         ($wipe->{thread} ? "res$$wipe{thread}" : "mainpage"),
      ),
   ));
}

# -> Piston::Wipe
# <- HTTP::Request
sub make_post_request($)
{
   my($wipe) = @_;
   #----------------------------------------
   my $content = [
      task      => "post",
      parent    => $wipe->{thread},
      nya1      => $wipe->{postform}->{name},
      nya2      => $wipe->{postform}->{email},
      nya3      => $wipe->{postform}->{subject},
      nya4      => $wipe->{postform}->{text},
      captcha   => $wipe->{captcha}->{text},
      postredir => 1,
      password  => $wipe->{postform}->{password},
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
   # Доска: http://iichan.hk/cgi-bin/wakaba.pl/b/
   # Тред:  http://iichan.hk/cgi-bin/wakaba.pl/b/
   return POST(
      caturl($Piston::config->{thischan}->{url}, "cgi-bin/wakaba.pl", $wipe->{board} . "/"),
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
   elsif($response->{_rc} ~~ [200,403])
   {
      ($errcode, $errstr) = (2, $response->status_line);
      write_file("$Piston::config->{chan}_bad_proxy.txt", { append => 1 }, "$$wipe{proxy}\n");
   }

   # Обычная ошибка (код 1)
   else
   {
      ($errcode, $errstr) = (1, $response->status_line);
   }
   #----------------------------------------
   return ($errcode, $errstr);
}

my $errors = {
   a => qr/(ПУСТО)/xo,
   b => qr/(
      Сообщения\ без\ изображений\ запрещены|
      Строка\ отклонена|Флуд|Доступ\ с\ этого\ прокси\ запрещён|
      Доступ\ с\ этого\ хоста\ запрещён|Open\ proxy\ detected|
      Код\ подтверждения\ не\ найден\ в\ базе|
      Введён\ неверный\ код\ подтверждения
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
   # Фатальная ошибка движка (код 3)
   if($errstr =~ /Доступ|Open/)
   {
      $errcode = 3;
      write_file("$Piston::config->{chan}_bad_proxy.txt", { append => 1 }, "$$wipe{proxy}\n");
   }
   #----------------------------------------
   say $response->content if $errstr eq "Неизвестная ошибка";
   return ($errcode, $errstr);
}

2;
package Piston::Engines::Sosach;

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
   $wipe->{lwp}->default_header(referer => "http://2ch.hk/$wipe->{board}/res/$wipe->{thread}.html");
   if($wipe->{lwp}->get("http://2ch.hk/makaba/captcha.fcgi")->{_content} eq "OK")
   {
      $wipe->{need_captcha} = 0;
      return;
   }
   return Piston::Engines::Recaptcha::make_captcha_request($wipe);
}

# -> Piston::Wipe
# <- HTTP::Request
sub make_post_request($)
{
   my($wipe) = @_;
   #----------------------------------------
   # Основные поля
   my $content = [
      task    => "роst",
      parent  => $wipe->{thread},
      akane   => $wipe->{postform}->{name},
      nabiki  => $wipe->{postform}->{email},
      sage    => ($wipe->{postform}->{email} eq "sage" ? "on" : ""),
      kasumi  => $wipe->{postform}->{subject},
      shampoo => $wipe->{postform}->{text},
      video   => ($wipe->{postform}->{video} ? "http://www.youtube.com/watch?v=$wipe->{postform}->{video}" : ""),
      recaptcha_challenge_field => $wipe->{recaptcha_key},
      recaptcha_response_field  => $wipe->{captcha}->{text},
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
      caturl($Piston::config->{thischan}->{url}, $wipe->{board}, "wakaba.pl"),
      Content_Type => "form-data",
      Content      => $content,
   );
}

# -> Piston::Wipe
# <- number, string
sub handle_captcha_response($)
{
   my($wipe) = @_;
   return Piston::Engines::Recaptcha::handle_captcha_response($wipe);
}

my $errors = {
   a => qr/(
      Обнаружен\ флуд|
      Вы\ уже\ создали\ один\ тред
   )/xo,
   b => qr/(
      Треда\ не\ существует|
      для\ начала\ треда\ нужно\ загрузить\ файл|
      вы\ забыли\ ввести\ капчу|
      Неверный\ код\ подтверждения|
      Вы\ ничего\ не\ написали\ в\ сообщении|
      видео\ имеет\ неверный\ формат|
      изображение\ слишком\ большое,\ либо\ его\ вообще\ не\ было
   )/xo,
   c => qr/(
      Доступ\ к\ отправке\ сообщений\ с\ этого\ IP\ закрыт
   )/xo,
};

# -> Piston::Wipe
# <- number, string
sub handle_post_response($)
{
   my($wipe) = @_;
   my $response = $wipe->{post_response};
   #----------------------------------------
   my($errcode, $errstr);
   if(exists $response->{_headers}->{location})
   {
      ($errcode, $errstr) = (0, "");
   }
   elsif($response->{_rc} == 200)
   {
      given($response->{_content})
      {
         when($errors->{a}) { ($errcode, $errstr) = (1, $1); }
         when($errors->{b}) { ($errcode, $errstr) = (2, $1); }
         when($errors->{c}) { ($errcode, $errstr) = (3, $1); }
         default            { ($errcode, $errstr) = (1, "Неизвестная ошибка"); }
      }
   }
   else
   {
      ($errcode, $errstr) = (4, $response->status_line);
   }
   #----------------------------------------
   if($response->{_rc} == 403)
   {
      $errcode = 5;
      write_file("$Piston::config->{chan}_bad_proxy.txt", { append => 1 }, "$$wipe{proxy}\n");
   }

   if($errstr ~~ ["Доступ к отправке сообщений с этого IP закрыт"])
   {
      $errcode = 3;
      write_file("$Piston::config->{chan}_bad_proxy.txt", { append => 1 }, "$$wipe{proxy}\n");
   }
   #----------------------------------------
   say $response->content if $errstr eq "Неизвестная ошибка";
   return ($errcode, $errstr);
}

2;

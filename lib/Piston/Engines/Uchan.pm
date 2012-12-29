package Piston::Engines::Uchan;

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
   die;
}

# -> Piston::Wipe
# <- HTTP::Request
sub make_post_request($)
{
   my($wipe) = @_;
   #----------------------------------------
   my $content = [
      task     => "post",
      parent   => $wipe->{thread},
      field1   => $wipe->{postform}->{name},
      field2   => $wipe->{postform}->{email},
      field3   => $wipe->{postform}->{subject},
      field4   => $wipe->{postform}->{text},
      noko     => "on",
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
      caturl($Piston::config->{thischan}->{url}, $wipe->{board}, "wakaba.pl"),
      Content_Type => "form-data",
      Content      => $content,
   );
}

# -> Piston::Wipe
# <- number, string
sub handle_captcha_response($)
{
   die;
}

my $errors = {
   a => qr/(
      Виявлено\ флуд,\ (?:пост|файл|новий\ тред)\ не
   )/xo,
   b => qr/(
      Не\ вибрано\ файлів|Виявлено\ флуд\.
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
   # if($errstr =~ /Доступ|Open/)
   # {
   #    $errcode = 3;
   #    write_file("$Piston::config->{chan}_bad_proxy.txt", { append => 1 }, "$$wipe{proxy}\n");
   # }
   #----------------------------------------
   say $response->content if $errstr eq "Неизвестная ошибка";
   return ($errcode, $errstr);
}

2;

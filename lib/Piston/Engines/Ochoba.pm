package Piston::Engines::Ochoba;

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

sub make_captcha_request($)
{
   return GET(caturl($Piston::config->{thischan}->{url}, $Piston::config->{board}, "captcha.fpl"));
}

sub make_post_request($)
{
   my($wipe) = @_;
   #----------------------------------------
   my $content = [
      task     => "post",
      name     => $wipe->{postform}->{name},
      email    => $wipe->{postform}->{email},
      subject  => $wipe->{postform}->{subject},
      comment  => $wipe->{postform}->{text},
      captcha  => $wipe->{captcha}->{text},
      password => $wipe->{postform}->{password},
   ];
   #----------------------------------------
   if($wipe->{postform}->has_image)
   {
      push @$content, (
         file => [
            undef, basename($wipe->{postform}->{file}),
            Content_Type => "*/*",
            Content => $wipe->{postform}->{image},
         ],
      );
   }
   #----------------------------------------
   return POST(
      caturl($Piston::config->{thischan}->{url}, $Piston::config->{board}, "post.fpl"),
      Content_Type => "form-data",
      Content      => $content,
   );
}

sub handle_captcha_response($)
{
   my($wipe) = @_;
   my $response = $wipe->{captcha_response};
   my $cfmt = $Piston::config->{thischan}->{captcha}->{type};
   #----------------------------------------
   my($errcode, $errstr);

   # Успешно (код 0)
   if(exists $response->{_headers}->{"content-type"} && $response->{_headers}->{"content-type"} =~ /image\/(png|gif)/)
   {
      ($errcode, $errstr) = (0, "");
      write_file("$Piston::config->{chan}_good_proxy.txt", { append => 1 }, "$$wipe{proxy}\n");
   }

   # elsif($response->{_rc} ~~ [200, 400, 403, 404])
   # {
   #    ($errcode, $errstr) = (2, $response->status_line);
   #    write_file("$Piston::config->{chan}_bad_proxy.txt", { append => 1 }, "$$wipe{proxy}\n");
   # }

   else
   {
      ($errcode, $errstr) = (1, $response->status_line);

      #say $response->as_string;
   }
   #----------------------------------------
   return ($errcode, $errstr);
}

my $errors = {
   a => qr/(Вы\ забанены|Нельзя\ создавать\ пустые\ сообщения)/xo,
   b => qr/(
      Неверно\ введена\ капча
   )/xo,
};

sub handle_post_response($)
{
   my($wipe) = @_;
   my $response = $wipe->{post_response};
   #print $response->as_string;
   #----------------------------------------
   my($errcode, $errstr);

   if($response->headers_as_string =~ /Location:/)
   {
      ($errcode, $errstr) = (0, "");
   }

   elsif($response->{_rc} == 200)
   {
      given($response->{_content})
      {
         when($errors->{a}) { ($errcode, $errstr) = (1, $1); }
         when($errors->{b}) { ($errcode, $errstr) = (2, $1); }
         default            { print $response->as_string; ($errcode, $errstr) = (1, "Неизвестная ошибка"); }
      }
   }

   else
   {
      ($errcode, $errstr) = (4, $response->status_line);
   }
   #----------------------------------------
   # Фатальная ошибка соединения (код 5)
   # if($response->{_rc} == 403)
   # {
   #    $errcode = 5;
   #    write_file("$Piston::config->{chan}_bad_proxy.txt", { append => 1 }, "$$wipe{proxy}\n");
   # }

   # Фатальная ошибка движка (код 3)
   if($errstr ~~ ["Вы забанены"])
   {
      $errcode = 3;
      write_file("$Piston::config->{chan}_bad_proxy.txt", { append => 1 }, "$$wipe{proxy}\n");
   }

   #----------------------------------------
   return ($errcode, $errstr);
}

2;

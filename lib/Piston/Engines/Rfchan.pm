package Piston::Engines::Rfchan;

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
      board        => $wipe->{board},
      replythread  => $wipe->{thread},
      em           => $wipe->{postform}->{email},
      name         => $wipe->{postform}->{name},
      subject      => $wipe->{postform}->{subject},
      message      => $wipe->{postform}->{text},
      recaptcha_challenge_field => $wipe->{recaptcha_key},
      recaptcha_response_field  => $wipe->{captcha}->{text},
      postpassword => $wipe->{postform}->{password},
   ];
   #----------------------------------------
   # Картинка
   if($wipe->{postform}->has_image)
   {
      push @$content, (
         imagefile => [
            undef, basename($wipe->{postform}->{file}),
            Content_Type => mimetype($wipe->{postform}->{file}),
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
sub handle_captcha_response($)
{
   my($wipe) = @_;
   return Piston::Engines::Recaptcha::handle_captcha_response($wipe);
}

my $errors = {
   a => qr/(ПУСТО)/xo,
   b => qr/(
      Введен\ неправильный\ код\ подтверждения
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
         default            { ($errcode, $errstr) = (1, "Неизвестная ошибка"); }
      }
   }
   else
   {
      ($errcode, $errstr) = (4, $response->status_line);
   }
   #----------------------------------------
   say $response->content if $errstr eq "Неизвестная ошибка";
   return ($errcode, $errstr);
}

2;

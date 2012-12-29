package Piston::Engines::Recaptcha;

use 5.010;
use strict;
use warnings;
use Carp;

use HTTP::Request::Common qw/GET POST/;

use Yoba;

# -> Piston::Wipe
# <- HTTP::Request
sub make_captcha_request
{
   my($wipe) = @_;
   my $key = $Piston::config->{thischan}->{captcha}->{recaptcha};
   die "Нет ключа рекапчи" unless $key;
   #----------------------------------------
   my $request;
   my $response = $wipe->{lwp}->get("http://www.google.com/recaptcha/api/challenge?k=$key");
   if($response->is_success)
   {
      my($challenge, $error) = $response->content =~ /challenge : '(.*?)'.*?error_message : '(.*?)'/s;
      if($challenge)
      {
         $wipe->log(2, "КАПЧА", "Ключ рекапчи получен");
         $wipe->{recaptcha_key} = $challenge;
         $request = GET("http://www.google.com/recaptcha/api/image?c=$challenge");
      }
      else
      {
         $error ||= $response->status_line;
         $wipe->log(3, "КАПЧА", "Не удалось получить ключ рекапчи: $error");
      }
   }
   else
   {
      $wipe->log(4, "КАПЧА", $response->status_line);
   }
   #----------------------------------------
   return $request;
}

# -> Piston::Wipe
# <- number, string
sub handle_captcha_response
{
   my($wipe) = @_;
   if($wipe->{captcha_response}->is_success)
   {
      return (0, "");
   }
   else
   {
      return (1, $wipe->{captcha_response}->status_line);
   }
}

2;

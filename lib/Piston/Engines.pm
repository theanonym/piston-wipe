package Piston::Engines;

use 5.010;
use strict;
use warnings;
use Carp;

use base "Exporter";
our @EXPORT = qw//;

sub init {
   eval sprintf("use Piston::Engines\::%s", ucfirst $Piston::config->{thischan}->{engine});
   die "Ошибка или неизвестный движок: $@" if $@;
   #if($Piston::config->{thischan}->{recaptcha}) {
   #   eval "use Piston\::Piston::Engines::Recaptcha; 1" or die $@;
   #}
   return 1;
}

# -> Piston::Wipe
# <- HTTP::Request
sub captcha_request($) {
   Carp::croak "Метод не определён";
}

# -> Piston::Wipe
# <- HTTP::Request
sub recaptcha_request($) {
   Carp::croak "Метод не определён";
}

# -> Piston::Wipe
# <- int, string
sub handle_captcha_response($) {
   my($wipe) = @_;
   #----------------------------------------
   my $response = $wipe->{captcha_response};
   my($error, $code);
   #----------------------------------------
   if($response->{_headers}->{"content-type"} =~ /image/) {
      return(1, "");
   } else {
      ($error, $code) = ($response->status_line, 2);
   }
   #----------------------------------------
   return($code, $error);
}

# -> Piston::Wipe
# <- int, string
sub handle_post_response($) {
   my($wipe) = @_;
   #----------------------------------------
   my $response = $wipe->{post_response};
   my($error, $code);
   #----------------------------------------
   if(exists $response->{_headers}->{location}) {
      return(1, "");
   } elsif($response->{_rc} == 200) {
      given($response->{_content}) {
         default { ($error, $code) = ("Неизвестная ошибка", 2) }
      }
   } else {
      ($error, $code) = ($response->status_line, 4);
   }
   #----------------------------------------
   return($code, $error);
}

2;

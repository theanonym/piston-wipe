use 5.010;
use strict;
use warnings;
use Carp;

use Term::ANSIColor qw/color colored/;

use Yoba;

use Piston::Extensions;

our $sessid;

extension(
   if => sub {
      $Piston::config->{extensions}->{enable_all}
      &&
      $Piston::config->{chan} eq "onechan_boards"
      &&
      $Piston::config->{extensions}->{onechan_boards}->{sessid}->{enable}
   },
   name => "Получение печеньки PHPSESSID",
   before_captcha_request => \&get_cookie,
);

# -> Piston::Wipe
sub get_cookie
{
   my($wipe) = @_;
   $wipe->{lwp}->get("http://1chan.ru/$$wipe{board}/");
   die "Не удалось получить PHPSESSID" unless $wipe->{lwp}->cookie_jar->as_string =~ /PHPSESSID/;
}

2;
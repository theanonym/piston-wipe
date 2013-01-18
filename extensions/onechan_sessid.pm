use 5.010;
use strict;
use warnings;
use Carp;

use Term::ANSIColor qw/color colored/;

use Yoba;

use Piston::Extensions;

our $sessid; #TODO Сделать кеш для проксей

extension(
   if => sub {
      $Piston::config->{extensions}->{enable_all}
      &&
      $Piston::config->{chan} ~~ ["onechan_boards", "onechan_news"]
      &&
      $Piston::config->{extensions}->{onechan}->{sessid}->{enable}
   },
   name => "Получение печеньки PHPSESSID",
   before_captcha_request => \&get_cookie,
);

# -> Piston::Wipe
sub get_cookie
{
   my($wipe) = @_;
   if($Piston::config->{chan} eq "onechan_boards")
   {
      $wipe->{lwp}->get("http://1chan.ru/$$wipe{board}/");
   }
   else
   {
      $wipe->{lwp}->get("http://1chan.ru/news/all/");
   }
   # die "Не удалось получить PHPSESSID" unless $wipe->{lwp}->cookie_jar->as_string =~ /PHPSESSID/;
}

2;
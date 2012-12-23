use 5.010;
use strict;
use warnings;
use Carp;

use Term::ANSIColor qw/color colored/;

use Yoba;
use Boards::Alterchan ();

use Piston::Extensions;

our $login_cookie;

extension(
   if => sub {
      $Piston::config->{extensions}->{enable_all}
      &&
      $Piston::config->{chan} eq "alterchan"
      &&
      $Piston::config->{extensions}->{alterchan}->{login}->{enable}
   },
   name => "Логин перед вайпом",
   before_post_request => \&make_login,
);

# -> Piston::Wipe
sub make_login
{
   my($wipe) = @_;
   # say "Login";
   Carp::croak "Не удалось залогиниться."
      unless Boards::Alterchan::login($wipe->{lwp}, array_pick $Piston::config->{thischan}->{passwords});
}

2;
use 5.010;
use strict;
use warnings;
use Carp;

use String::ShellQuote qw/shell_quote/;

use Piston::Extensions;

our $cache;

extension(
   if => sub {
      $Piston::config->{extensions}->{enable_all}
      &&
      $Piston::config->{chan} eq "nullchan"
      &&
      $Piston::config->{board} eq "b"
      &&
      $Piston::config->{extensions}->{nullchan}->{mm}->{enable}
   },
   before_post_request => \&gen_mm,
);

sub gen_mm
{
   my($wipe) = @_;
   #----------------------------------------
   my $mm = 772897149;
   if($Piston::config->{postform}->{text} || $Piston::config->{postform}->{text_mode} || $Piston::config->{postform}->{password}) {
      my $cmd = shell_quote("0$$wipe{postform}{text}$$Piston::config{postform}{password}");
      $mm = `./bin/mm $cmd`;
      warn "Не удалось сгенерировать mm" unless $mm;
   }
   #----------------------------------------
   $wipe->{lwp}->cookie("mm=$mm");
}

2;

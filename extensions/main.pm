use 5.010;
use strict;
use warnings;
use Carp;

use List::Util qw/sum/;
use Term::ANSIColor qw/color colored/;

use Piston::Extensions;
use Yoba;

extension(
  if => sub {
    $Piston::config->{extensions}->{enable_all}
    &&
    $Piston::config->{extensions}->{main}->{informer}->{enable}
  },
  name => "Информер",
  prio => 10,
  main => \&informer,
);

sub informer
{
   my $wait    = $Piston::wait_threads;
   my $captcha = $Piston::config->{max_connections} - $Piston::captcha_semaphore->count;
   my $post    = $Piston::config->{max_connections} - $Piston::post_semaphore->count;
   my $killed  = $Piston::killed_threads;
   my $str = sprintf("%d/%d/%d/%d (%d)",
       $wait, $captcha, $post, $killed,
       sum($wait, $captcha, $post),
   );
   $str =~ s/(\d+)/colored($1, "yellow")/ge;
   $str =~ s/([\/\(\)])/colored($1, "cyan")/ge;
   say colored("Потоки (ожидают/капча/постинг/убиты): ", "cyan"), $str;
}

2;

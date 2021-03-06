use 5.010;
use strict;
use warnings;
use Carp;

use Term::ANSIColor qw/color colored/;

use Piston::Extensions;
use Boards::Nullchan qw/get_catalog_page parse_threads_table/;

extension(
   if => sub {
      $Piston::config->{extensions}->{enable_all}
      &&
      $Piston::config->{chan} eq "nullchan"
      &&
      $Piston::config->{board} !~ /^_/
      &&
      $Piston::config->{extensions}->{nullchan}->{catalog}->{enable}
   },
   name => "Обновление каталога",
   prio => 10,
   init => \&check_catalog,
   main => \&check_catalog,
);

extension(
   if => sub {
      $Piston::config->{extensions}->{enable_all}
      &&
      $Piston::config->{chan} eq "nullchan"
      &&
      $Piston::config->{board} !~ /^_/
      &&
      $Piston::config->{extensions}->{nullchan}->{catalog}->{enable}
      &&
      $Piston::config->{extensions}->{nullchan}->{postcounter}->{enable}
   },
   name => "Счётчик постов",
   main => \&postcounter,
);

extension(
   if => sub {
      $Piston::config->{extensions}->{enable_all}
      &&
      $Piston::config->{chan} eq "nullchan"
      &&
      $Piston::config->{board} !~ /^_/
      &&
      $Piston::config->{extensions}->{nullchan}->{catalog}->{enable}
      &&
      $Piston::config->{extensions}->{nullchan}->{check_bumplimit}->{enable}
   },
   name => "Проверка бамплимита",
   init => \&check_bumplimit,
   main => \&check_bumplimit,
);

sub check_catalog
{
   my %catalog;
   try
   {
      %catalog = parse_threads_table(get_catalog_page($Piston::config->{board}));
   }
   catch
   {
      warn "$_\n";
   };
   $Piston::shared->{catalog} = \%catalog;
}

sub postcounter
{
   for my $thread (@Piston::threads)
   {
      next if $thread == 0;
      say colored("Постов в треде /$Piston::config->{board}/$thread: ", "cyan"),
         colored($Piston::shared->{catalog}->{$thread}, "yellow");
   }
}

sub check_bumplimit {
   for my $thread (@Piston::threads)
   {
      next if $thread == 0;
      next unless defined $Piston::shared->{catalog}->{$thread}; #TODO Заглушка
      if($Piston::shared->{catalog}->{$thread} >= 500)
      {
         Piston::delete_thread($thread);
         say colored("Тред $thread удалён из целей (бамплимит)", "cyan");
      }
   }
}

2;

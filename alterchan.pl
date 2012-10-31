#!/usr/bin/perl
#----------------------------------------
#
# http://alterchan.net/b/res/31574.html
#
#----------------------------------------

use v5.10;
use strict;
use warnings;
use autodie;
use Coro;
use Coro::LWP;
use Coro::Semaphore;
use LWP;

#----------------------------------------
# Настройки

my $password = ""; # Пароль от любого аккаунта, его блеклист будет очищен

my $board    = "b"; # Доска
my $pages    = 5;   # Количество сканируемых страниц начиная с 0

my @target   = (); # Если указано, то сканируются только указанные треды
my $target   = 0;  # Целевой пост

my $outfile  = "posts.txt"; # Куда сохранить найденные посты

#----------------------------------------

my $lwp = new LWP::UserAgent;
$lwp->agent( "Opera/9.80 (X11; Linux i686; U; en) Presto/2.10.289 Version/12.02" );
$lwp->cookie_jar( {} );

my $sem = new Coro::Semaphore( 30 );

sub login($) {
   my( $pass ) = @_;
   say "Login";
   my $res = $lwp->post( "http://alterchan.net/uid.php",
      Content_Type => "application/x-www-form-urlencoded",
      Content      => "action=login&pass1=$pass",
   );
   unless( $res->content =~ /Ist Gut/ ) {
      die "Can't login:\n" . $res->content;
   }
}

sub add_to_blacklist($$) {
   my( $board, $post ) = @_;
   my $res = $lwp->post( "http://alterchan.net/uid.php",
      Content_Type => "application/x-www-form-urlencoded",
      Content      => "action=blacklist&number=$post&board=$board",
   );
   unless( $res->is_success ) {
      die "Can't hide post '$board/$post':\n" . $res->as_string;
   }
}

sub clear_blacklist() {
   my $res = $lwp->post( "http://alterchan.net/uid.php",
      Content_Type => "application/x-www-form-urlencoded",
      Content      => "action=erase",
   );
   unless( $res->is_success ) {
      die "Can't erase blacklist:\n" . $res->as_string;
   }
}

sub get_page($$) {
   my( $board, $page ) = @_;
   say "Get page '$board/$page'";
   my $url = "http://alterchan.net/$board/" . ( $page ? "$page.html" : "" );
   my $res = $lwp->get( $url );
   if( $res->is_success ) {
      return $res->content;
   } else {
      die "Can't download page '$board/$page':\n" . $res->as_string;
   }
}

sub parse_threads($) {
   my( $html ) = @_;
   my @threads = $html =~ /^<div id="thread(\d+).+">/gm;
   if( @threads ) {
      return @threads;
   } else {
      die "No threads found";
   }
}

sub get_thread($$) {
   my( $board, $thread ) = @_;
   say "Get thread '$board/$thread'";
   my $res = $lwp->get( "http://alterchan.net/$board/res/$thread.html" );
   if( $res->is_success ) {
      return $res->content;
   } else {
      die "Can't download thread '$board/$thread':\n" . $res->as_string;
   }
}

sub parse_posts($) {
   my( $html ) = @_;
   my %posts = $html =~ m/^<td class="reply" id="reply(\d+)">.*?^<blockquote>(.*?)^<\/blockquote>/gms;
   for( values %posts ) {
      s/^\s+|\s+$//g;
      s/<.*?>//g;
      s/&gt;/>/g;
      s/&quot;/"/g;
   }
   return \%posts;
}

sub parse_all_posts(@) {
   my( @threads ) = @_;
   my %threads;
   my @workers;
   for my $thread ( @threads ) {
      push @workers, async {
         $sem->down;
         my @ret = ( $thread, parse_posts( get_thread( $board, $thread ) ) );
         $sem->up;
         return @ret;
      };
   }
   for( @workers ) {
      my( $thread, $posts ) = $_->join;
      $threads{$thread} = $posts;
   }
   return \%threads;
}

sub write_file($$) {
   my( $fname, $data ) = @_;
   open my $fh, ">", $fname;
   if( syswrite( $fh, $data ) != length $data ) {
      warn "File '$fname' written with errors";
   }
}

#----------------------------------------

login( $password );
clear_blacklist();

my @all;
if(@target) {
   push @all, @target;
} else {
   my @workers;
   for my $page ( 0 .. $pages - 1 ) {
      push @workers, async {
         $sem->down;
         my @ret = parse_threads( get_page( $board, $page ) );
         $sem->up;
         return @ret;
      };
   }
   push @all, $_->join for @workers;
}

my $threads = parse_all_posts( @all );

add_to_blacklist( $board, $target );
my @after = map { keys %$_ } values %{ parse_all_posts( @all ) };

clear_blacklist();

my $text;
for my $thread ( sort { $a <=> $b } keys %$threads ) {
   for my $post ( sort { $a <=> $b } keys %{ $threads->{$thread} } ) {
      next if $post ~~ @after;
      $text .= "http://alterchan.net/$board/res/$thread.html\n";
      $text .= "Тред $thread, пост $post:\n-----\n$threads->{$thread}->{$post}\n-----\n";
   }
}

write_file( $outfile, $text );

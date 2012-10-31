package Piston::Args;

use 5.010;
use strict;
use warnings;
use Carp;

use Getopt::Long;
use File::Slurp qw/read_file write_file/;
use File::Path qw/rmtree mkpath/;
use File::Spec::Functions qw/catfile catdir/;
use File::Basename qw/dirname basename/;

use Coro::AnyEvent;

use Yoba;
use Yoba::LWP;
use Boards::Nullchan;

my $opt;

GetOptions(
   "proxies=s"      => \$opt->{proxies},
   "youtube=s{1,2}" => \@{ $opt->{youtube} },

   "config=s"       => \$opt->{config},
   "chan=s"         => \$opt->{chan},
   "board=s"        => \$opt->{board},
   "threads=s{1,}"  => \@{ $opt->{threads} },

   "images=s{3}"    => \@{ $opt->{images} },
   "posts=s{3}"     => \@{ $opt->{posts} },
   "catalog=s"      => \$opt->{catalog},
   "last-post=s"    => \$opt->{"last-post"},
   "check=s{2}"     => \@{ $opt->{check} },
   "count=s{1,2}"   => \@{ $opt->{count} },
   "delete=s{1,3}"  => \@{ $opt->{delete} },

   "clear"   => sub { clear(); exit },
   "help"    => sub { print_help(); exit },
   "version" => sub { say $Piston::VERSION; exit },
);

$Piston::opt = $opt;

die "Неверные аргументы" if @ARGV;

sub print_help() {
   say <<HLP;
Piston Wipe $Piston::VERSION

Использование:
   perl $0 [аргументы]

Справка:
   Общее:
      --(pr)oxies [файл]            | Обработать файл с прокси
      --(yo)utube [запрос,страниц]  | Поиск роликов на ютубе по указанному запросу
      --(cl)ear                     | Удалить временные файлы ('$Piston::config->{tmp}')
      --(h)elp                      | Справка

   Конфиг:
      --(con)fig
      --(cha)n
      --(bo)ard
      --(th)reads

   Нульчан:
      --(im)ages [доска,тред,папка] | Скачать все картинки из треда в указанную папку
      --(po)sts  [доска,тред,файл]  | Сохранить текст постов из треда в указанный файл
      --(ca)talog [доска]           | Отобразить каталог доски в текстовом виде
      --(la)st-post [доска]         | Найти последний пост на доске
      --(che)ck [доска,тред]        | Быстрая проверка на сущестование треда
      --(cou)nt  [доска]            | Посчитать треды на доске
      --(cou)nt  [доска,тред]       | Посчитать посты в треде
      --(de)lete [доска,пост]       | Удалить пост (пароль берётся из конфига)
      --(de)lete [доска,перв,посл]  | Удалить посты от .. до


Также скрипты:
   proxycheck.pl      | Проксичекер
   voiceupload.pl     | Загрузка голосовых флешек на нульчан
   (--help для справки)
HLP
}

# --config
if(defined $opt->{config}) {
   $opt->{config} =~ s/\s//g;
   say "Config:";
   for(split /\|/, $opt->{config}) {
      my($key, $value) = split /:/;
      die unless(defined $key && defined $value);
      if($value =~ /^\[(.*)\]$/s) {
         $value = [split /,/, $1];
         die unless @$value;
         say "   $key = [@$value]";
         die unless defined $Piston::config->{$key};
         $Piston::config->{$key} = $value;
      } elsif($value =~ /^\{(.*)\}$/s) {
         $value = {split /,|=>/, $1};
         die unless %$value;
         for(keys %$value) {
            say "   $key\->$_ = $$value{$_}";
            die unless defined $Piston::config->{$key}->{$_};
            $Piston::config->{$key}->{$_} = $value->{$_};
         }
      } else {
         say "   $key = $value";
         die unless defined $Piston::config->{$key};
         $Piston::config->{$key} = $value;
      }
   }
}

# --chan
if(defined $opt->{chan}) {
   $Piston::config->{chan} = $opt->{chan};
}

# --board
if(defined $opt->{board}) {
   $Piston::config->{board} = $opt->{board};
}

# --threads
if(@{ $opt->{threads} }) {
   array_unique($opt->{threads});
   $Piston::config->{threads} = $opt->{threads};
}

# --youtube
if(my @arg = @{ $opt->{youtube} }) {
   parse_youtube_videos(@arg);
   exit;
}

# --proxies
if(defined $opt->{"proxies"}) {
   my @p = Yoba::read_proxylist($opt->{"proxies"});
   write_file($opt->{"proxies"}, join("\n", @p));
   exit;
}

# --images
if(my @arg = @{ $opt->{images} }) {
   die unless @arg == 3;
   my($board, $thread, $folder) = @arg;
   my @urls = parse_image_links(get_thread_page($board, $thread));
   printf "%d картинок найдено\n", scalar @urls;
   mkpath($folder);
   my $w = new Yoba::Coro::Watcher;
   my $p = new Yoba::Coro::Pool(
      limit => 10,
      timelimit => 60,
      params => \@urls,
      function   => sub {
         my($url) = @_;
         say $url;
         write_file(
            catfile($folder, basename($url)),
            { binmode => ":row" },
            Yoba::http_get($url),
         );
      },
   );
   $p->start_all;
   $p->join_all;
   exit;
}

# --posts
if(my @arg = @{ $opt->{posts} }) {
   die unless @arg == 3;
   my($board, $thread, $fname) = @arg;
   my @posts = parse_posts(get_thread_page($board, $thread));
   Yoba::write_file($fname, join("\n---\n", @posts));
   exit;
}

# --catalog
if(defined $opt->{catalog}) {
   my $catalog = get_catalog_page($opt->{catalog});
   my @threads = parse_threads_list($catalog);
   my %catalog = parse_threads_table($catalog);
   my $i = 1;
   for my $thread (@threads) {
      printf "%-3d ", $catalog{$thread};
      print "\n" unless $i++ % 12;
   }
   exit;
}

# --last-post
if(defined $opt->{"last-post"}) {
   say get_last_post($opt->{'last-post'});
   exit;
}

# --check
if(my @arg = @{ $opt->{check} }) {
   die unless @arg == 2;
   my($board, $thread) = @arg;
   my $code = check_thread_exists($board, $thread);
   if($code == 200) {
      say "Тред существует.";
   } else {
      say "Тред не существует ($code).";
   }
   exit;
}

# --count
if(my @arg = @{ $opt->{count} }) {
   die if @arg < 1 || @arg > 2;
   if(@arg == 2) {
      my($board, $thread) = @arg;
      printf("Постов в треде /$board/$thread/: %d.\n", count_posts($board, $thread));
   } else {
      my($board) = @arg;
      printf("Тредов на доске /$board/: %d.\n", count_threads($board));
   }
   exit;
}

# --delete
if(my @arg = @{ $opt->{delete} }) {
   die if @arg < 2 || @arg > 3;
   my $pass = $Piston::config->{postform}->{password};
   die "Нет пароля" unless defined $pass;
   if(@arg == 2) {
      my($board, $post) = @arg;
      delete_post($board, $post, $pass);
   } else {
      my($board, $first, $last) = @_;
      for my $post ($first .. $last) {
         delete_post($board, $post, $pass);
         Coro::AnyEvent::sleep(5);
      }
   }
   exit;
}

sub parse_youtube_videos {
   my($query, $pages) = @_;
   $pages ||= 20;
   say "Ищем видео по запросу '$query':";
   #----------------------------------------
   my @results;
   my $w = new Yoba::Coro::Watcher;
   my $p = new Yoba::Coro::Pool(
      timelimit => 20,
      params => [1 .. $pages],
      function   => sub {
         my($page) = @_;
         say "Страница $page";
         my $html = http_get("http://www.youtube.com/results?search_query=$query&page=$page");
         push @results, $html =~ /data-video-ids="(.{11})"/g;
      },
   );
   $p->start_all;
   $p->join_all;
   array_unique(\@results);
   if(@results) {
      write_file("youtube.txt", {append => 1}, join("\n", @results) . "\n");
      printf "%d видео сохранено в файл 'youtube.txt'.\n", scalar @results;
   } else {
      die "Ни одно видео не было найдено.\n";
   }
   return;
}

sub clear() {
   rmtree($Piston::config->{tmp});
   return;
}

2;

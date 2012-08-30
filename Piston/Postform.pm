package Piston::Postform;

use 5.010;
use strict;
use warnings;
use Carp;

use Encode qw/encode decode/;
use File::Slurp qw/read_file write_file/;

use Yoba::Object;

our $cache = {};

our @files;  # Список картинок из папки
our @videos; # Список id видео с ютуба
our @copypasta; # Блоки копипасты

our @links;  # Список ссылок из треда
our @posts;  # Список постов из треда

sub init {
   #----------------------------------------
   # Получение страницы первого треда из конфига
   sub get_thread_page {
      return if $cache->{thread_page};
      require Boards::Nullchan;
      Carp::croak "Нет треда чтобы скачать." unless $Piston::config->{threads}->[0];
      $cache->{thread_page} = Boards::Nullchan::get_thread_page(
         $Piston::config->{board},
         $Piston::config->{threads}->[0],
      );
   }
   #----------------------------------------
   # Загрузка ссылок на посты из треда
   if($Piston::config->{postform}->{randreply}) {
      get_thread_page;
      require Boards::Nullchan;
      if(@links = Boards::Nullchan::parse_post_refs($cache->{thread_page})) {
         printf "%d ссылок на посты найдено в треде $Piston::config->{threads}->[0].\n", scalar @links;
      } else {
         Carp::croak "Не удалось найти ссылки на посты в треде $Piston::config->{threads}->[0].\n";
      }
   }
   #----------------------------------------
   # Загрузка постов из треда
   if($Piston::config->{postform}->{text_mode} eq "posts") {
      get_thread_page;
      require Boards::Nullchan;
      if(@posts = Boards::Nullchan::parse_posts($cache->{thread_page})) {
         Yoba::array_unique(\@posts);
         printf "%d постов найдено в треде $Piston::config->{threads}->[0].\n", scalar @posts;
      } else {
         Carp::croak "Не удалось посты в треде $Piston::config->{threads}->[0].\n";
      }
   }
   #----------------------------------------
   # Загрузка копипасты
   if($Piston::config->{postform}->{text_mode} eq "copypasta") {
      my $fname = "copypasta.txt";
      my $file  = read_file($fname);
      @copypasta = map {
         s/^\s+|\s+$//
      } grep {
         length $_ > 100 && length $_ <= 5000
      } split(/\n---\n/, $file);
      if(@copypasta) {
         printf "%d блоков копипасты загружено из '$fname'.\n", scalar @copypasta;
      } else {
         Carp::croak "Не удалось найти копипасту в '$fname'.\n";
      }
   }
   #----------------------------------------
   # Загрузка картинок из папки
   if($Piston::config->{postform}->{images_mode} eq "folder") {
      my $path = $Piston::config->{postform}->{folder}->{path};
      Carp::croak "Неверный путь к папке с картинками '$path'.\n" unless -d $path;
      if(@files = Yoba::find_files(%{ $Piston::config->{postform}->{folder} })) {
         printf "%d изображений загружено из '$path'.\n", scalar @files;
      } else {
         Carp::croak "Не удалось найти картинки в '$path'.\n";
      }
   }
   #----------------------------------------
   # Поиск ютуб-роликов
   if($Piston::config->{postform}->{images_mode} eq "video") {
      my $videos = "youtube.txt";
      my $used_videos = "youtube_used.txt";
      my @used = read_file($used_videos) if -s $used_videos;
      if(@videos = grep { not $_ ~~ @used } read_file($videos)) {
         Yoba::array_unique(\@videos);
         printf "%d id видео загружено из '$videos'.\n", scalar @videos;
      } else {
         Carp::croak "Не удалось найти видео в '$videos'.\n";
      }
   }
   #----------------------------------------
   undef $cache;
   return 1;
}

sub CONSTRUCT {
   my $self = shift;
   #----------------------------------------
   # Прочее
   for(qw/email name subject password/) {
      $self->{$_} = $Piston::config->{postform}->{$_};
   }
   #----------------------------------------
   # Текст
   given($Piston::config->{postform}->{text_mode}) {
      # Режим текста
      when("copypasta") { $self->{text} = $copypasta[rand @copypasta] }
      when("posts")     { $self->{text} = $posts[rand @posts] }
      default           { $self->{text} = $Piston::config->{postform}->{text} }
   }
   #----------------------------------------
   # Картинка
   given($Piston::config->{postform}->{images_mode}) {
      when("folder")  { $self->{file} = $files[rand @files] }
      when("video") {
         if(@videos) {
            $self->{video} = pop @videos;
         } else {
            Carp::carp "Видео закончились";
         }
      }
   }
   #----------------------------------------
   # Обработка текста
   if($self->{text}) {
      if($Piston::config->{postform}->{randreply}) {
         # Добавление ссылки на случайный пост
         $self->{text} = sprintf(">>%d\n%s", $links[rand @links], $self->{text});
      }
      # Джокеры
      #----------------------------------------
      $self->{text} =~ s/%rand%/substr(rand, -10)/e;
      $self->{text} =~ s/%time%/time/e;
      $self->{text} =~ s/%i%/%% %%/;
      $self->{text} =~ s/%captcha%/$$self{wipe}{captcha}{text}/;
      $self->{text} =~ s/%board%/$$self{wipe}{board}/;
      $self->{text} =~ s/%thread%/$$self{wipe}{thread}/;
   }
   #----------------------------------------
   # Чтение файла
   if($self->{file}) {
      $self->{image} = read_file($self->{file}, { binmode => ":raw" }); #TODO Возможно, нужен бинарный режим
      $self->{image} .= substr(rand, -6) . "Piston Wipe $Piston::VERSION";
   }
   #----------------------------------------
   if(!defined $self->{text} && !$self->{file} && !$self->{video}) {
      Carp::croak "Нет текста и картинки.";
   }
   # Связанные объекты Piston::Wipe и Piston::Postrofm не будут удалены
   # счётчиком ссылок.
   undef $self->{wipe};
}

# <- bool
sub has_file {
   return !!$_[0]->{file};
}

# <- bool
sub has_image {
   return !!$_[0]->{image};
}

# <- bool
sub has_video {
   return !!$_[0]->{video};
}

2;

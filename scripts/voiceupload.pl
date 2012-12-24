#!/usr/bin/perl
#----------------------------------------
#
# Скрипт для загрузки голосовых флешек на нульчан.
#
#----------------------------------------

use 5.010;
use strict;
use warnings;
use Carp;

use lib "lib", "../lib";

use File::Path qw/rmtree mkpath/;
use File::Spec::Functions qw/catfile catdir tmpdir/;
use Image::Magick;
use Getopt::Long;

use Yoba;
use Yoba::LWP;

my $opt = {
   image => undef,
   voice => "./voice.mp3",

   sx => 3,
   sy => 15,

   tmpdir => catdir(tmpdir, "piston_wipe", "voice_uploader"),
};

sub print_help {
   say <<HLP;
Yoba voice uploader

Использование:
   perl $0 [аргументы]

Справка:
   --im(age)  | Путь к файлу картинки
   --vo(ice)  | Путь к mp3-файлу ($opt->{voice} по умолчанию)

   --cr(op)   | Порезать изображение на части
   --up(load) | Загрузить изображение (все части в сочетании с --crop)
   --ol(d)    | Загрузить части порезанной ранее картинки

   --sx       | Количество блоков по горизонтали ($opt->{sx} по умолчанию)
   --sy       | Количество блоков по вертикали ($opt->{sy} по умолчанию)

   --cl(ear)  | Удалить временные файлы

Примеры:
   --image="yoba.png" --upload | Загрузить одну картинку
   --image="bolshoy_yoba.png" --crop --upload | Разрезать и загрузить по частям
HLP
}

GetOptions($opt,
   "image=s", "voice=s", "sx=s",
   "sy=s", "tmpdir=s", "upload",
   "old", "crop",
   "clear" => sub { clear(); exit },
   "help"  => sub { print_help(); exit },
);

Carp::croak "Не найден файл картики.\n" unless -f $opt->{image};
Carp::croak "Не найден mp3-файл.\n"   unless -f $opt->{voice};

mkpath($opt->{tmpdir});

my $lwp = new Yoba::LWP;
$lwp->referer("http://0chan.hk/");

if($opt->{crop}) {
   say "Нарезаем картинку '$$opt{image}':";
   #----------------------------------------
   my $image = new Image::Magick;
   $image->Read($opt->{image});
   $image->Resize(
      width  => $opt->{sx} * 300 + ($opt->{sx} - 1) * 70,
      height => $opt->{sy} * 50  + ($opt->{sy} - 1) * 20,
   );
   $image->Write(catfile($opt->{tmpdir}, "big.png"));
   #----------------------------------------
   my $count = $opt->{sx} * $opt->{sy};
   for(my($i, $x, $y) = (1, 0, 0); $i <= $count; $y++) {
      for($x = 0; $x < $opt->{sx}; $x++, $i++) {
         say "$i/$count";
         #----------------------------------------
         my $image = new Image::Magick;
         $image->Read(catfile($opt->{tmpdir}, "big.png"));
         $image->Crop(
            x => $x * 300 + $x * 70,
            y => $y * 50  + $y * 20,
            width  => 300,
            height => 50,
         );
         $image->Write(catfile($opt->{tmpdir}, "$i.png"));
         #----------------------------------------
      }
   }
}

if($opt->{upload} || $opt->{old}) {
   if($opt->{old} || $opt->{crop}) {
      my $count = $opt->{sx} * $opt->{sy};
      say "Загружаем $count частей картинки '$$opt{image}':";
      #----------------------------------------
      for my $i (1 .. $count) {
         my $fname = catfile($opt->{tmpdir}, "$i.png");
         die "Не найден файл '$fname'\n" unless -f $fname;
         print upload($fname);
         say "" unless $i % $opt->{sx};
      }
      #----------------------------------------
   } else {
      say "Загружаем картинку '$$opt{image}':";
      say upload($opt->{image});
   }
}

sub upload {
   my($fname) = @_;
   #----------------------------------------
   my $res = $lwp->post("http://0chan.hk/voice.php",
      Content_Type => "form-data",
      Content => [
         voice  => [$opt->{voice}],
         visual => [$fname],
      ],
   );
   #----------------------------------------
   if($res->content =~ /done:(\w+)/) {
      return "[voice=$1]";
   } else {
      die $res->content;
   }
}

sub clear {
   unlink glob catfile($opt->{tmpdir}, "*");
}

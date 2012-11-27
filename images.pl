#!/usr/bin/perl

use 5.010;
use strict;
use warnings;
use Carp;

use lib "lib";

use File::Spec::Functions qw/catfile/;
use File::Path qw/mkpath/;
use Getopt::Long qw/GetOptions/;
use Image::Magick;

use Yoba;

my $opt = {};
GetOptions($opt,
   "input=s", "output=s",
   "recursive", "scale=s",
   "quality=s",
   "help" => sub { print_help(); exit }
);

sub print_help {
   say <<HLP;
Yoba image compressor

Использование:
   perl $0 [аргументы]

Справка:
   --i(nput)     | Путь к оригинальным картинкам
   --o(uput)     | Куда сохранить сжатые
   --r(ecursive) | Искать рекурсивно

   --s(cale)     | Масштаб в процентах
   --q(uality)   | Качество в процентах

Примеры:
   -i ./images -o ./wipe_images -s 50 -q 50
HLP
}

die "Не удалось найти папку с картинками" unless $opt->{input} && -d $opt->{input};
mkpath($opt->{output});
die "Не удалось создать папку для сжатых картинок" unless $opt->{output} && -d $opt->{output};

my @files = Yoba::find_files(
   path      => $opt->{input},
   regex     => qr/(jpg|png|gif)$/i,
   recursive => $opt->{recursive},
);
printf "Найдено %d файлов \n", 0+ @files;
exit unless @files;

for my $file (@files)
{
   say $file;
   my $im = new Image::Magick;
   $im->Read($file);

   $im->Resize(
      height => $im->Get("height") * ($opt->{scale} / 100),
      width  => $im->Get("width")  * ($opt->{scale} / 100),
   ) if $opt->{scale};

   $im->Set(compression => "JPEG");
   $im->Set(quality => $opt->{quality}) if $opt->{quality};

   $im->Write(catfile($opt->{output}, substr(rand, -10) . ".jpg"));
}

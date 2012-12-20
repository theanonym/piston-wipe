package Piston::Postform::Generators;

use 5.010;
use strict;
use warnings;
use Carp;

use Encode qw/encode decode/;

use Yoba;

my $min_words    = 10;
my $max_words    = 30;
my $min_letters  = 4;
my $max_letters  = 9;

my $vowel_chance        = 50 / 100;
my $dot_or_comma_chance = 40 / 100;
my $dot_chance          = 40 / 100;

# <- string
#TODO Переписать на шаблонах
sub anti_kukloeb
{
   use utf8;
   my @a = qw/а е и о у ю я/;
   my @b = qw/б в г д ж з к л м н п р с т ф х ц ш ч/;
   my $text = "";
   for(1 .. rand($max_words - $min_words) + $min_words) {
      my $a = int rand(2);
      for(1 .. rand($max_letters - $min_letters) + $min_letters) {
         if(rand() < $vowel_chance && !(substr($text, -2) =~ /[аеиоуэюя]{2}/i)) {
            my($new, $last) = ($a[rand @a], substr($text, -1));
            if(($new ne $last) && !($last =~ /[жшхцч]/i && $new =~ /[яюэ]/i)) {
               $text .= $new;
               $a = 1;
            } else {
               redo;
            }
         } elsif($a || !$text) {
            $text .= $b[rand @b];
            $a = 0;
         } else {
            redo;
         }
      }

      if(rand() < $dot_or_comma_chance) {
         $text .= rand() < $dot_chance ? "." : ",";
      }

      $text .= " ";
   }
   $text =~ s/[\s\.\,]+$/./;
   $text =~ s/\. (.)/. \U$1/g;
   return encode("utf-8", ucfirst($text));
}

use utf8;
my @intro = ('ололо,', 'внезапно,', 'ITT', 'in b4,', 'невозбранно', 'алсо', 'быстро, решительно',
             'былинно', 'эпично');
my @verb  = ('бампаю', 'сагаю', 'нульчую', 'набигаем на', 'фапаю на', 'гарантирую', 'доставляю');
my @noun  = ('капчу', 'бамп', 'гет', 'сажу', 'нульч', 'лолей', 'тян', 'пикрелейтед', 'пруфпик',
             'хуйцы', 'быдло', 'корованы', 'хитрый план', 'копипасту', 'пинус', 'рейд', 'вин',
             'фейл', 'тред');
my @outro = (' овер 9000', ' во все поля', ', инфа 100%', ' - доставило', ' - хуита', ', годно',
             ', например', ', анон', ' блджад', ', а твоя мать - шлюха');
my @mark  = ('.', '.', '.', '.', '.', '!', '!!!', '...');
no utf8;

# <- string
sub genbred
{
   use utf8;
   my $text;
   for(1..10) {
      my $str;
      $str .= $intro[rand @intro] if(rand() < 0.5);
      $str .= ' ' . $verb[rand @verb] . ' ';
      $str .= $noun [rand @noun];
      $str .= $outro[rand @outro] if(rand() < 0.5);
      $str .= $mark [rand @mark];
      $str =~ s/^\s?(.)/\u$1/m;
      $text .= $str . "\n";
   }
   return encode('utf-8', $text);
}

2;
#----------------------------------------
#
#  Библиотека Yoba.
#
#----------------------------------------

package Yoba;

use 5.010;
use strict;
use warnings;
use Carp;

use base "Exporter";
our @EXPORT = qw/
   array_delete array_find array_pick array_unique
   find_files notify print_dump prompt split_text
   unref yobatext
   http_get http_post save setscheme gethost caturl
   read_proxylist parse_proxies
   try catch
/;

our @EXPORT_OK = @EXPORT;

use Encode qw/encode decode/;
use File::Slurp qw/read_file write_file/;
use File::Spec::Functions qw/catfile tmpdir/;
use File::Find;
use String::ShellQuote qw/shell_quote/;
use Params::Check;
use Try::Tiny;

use Yoba::Functional ();
use Yoba::LWP;

#----------------------------------------
# Функции для работы с массивами
#----------------------------------------

# -> [any], any
# <- int
sub array_find($$)
{
   my($array, $value) = @_;
   do { Carp::carp "Empty array"; return } unless @$array;
   return -1 unless $value ~~ @$array;
   for my $i (0 .. $#$array)
   {
      next unless defined $array->[$i];
      return $i if $array->[$i] eq $value;
   }
}

# -> [any], any
# <- bool
sub array_delete($$)
{
   my($array, $value) = @_;
   my $i = array_find($array, $value);
   if($i != -1)
   {
      splice @$array, $i, 1;
      return 1;
   } else {
      return;
   }
}

# -> [any], int
# <- any | (any)
sub array_pick($;$)
{
   my($array, $n) = @_;
   do { Carp::carp "Empty array"; return } unless @$array;
   unless($n)
   {
      return $$array[rand @$array];
   }
   else
   {
      array_unique($array);
      Carp::croak "Too small array" unless @$array >= $n;
      return @$array if @$array == $n;
      my @temp = @$array;
      my @ret;
      no warnings;
      for(1 .. $n)
      {
         my $new = array_pick(\@temp);
         array_delete(\@temp, $new);
         push @ret, $new;
      }
      return @ret;
   }
}

# -> [any]
*unique = \&array_unique;
sub array_unique($)
{
   my($array) = @_;
   do { Carp::carp "Empty array"; return } unless @$array;
   my %a;
   @$array = grep { !$a{$_}++ } @$array;
   return;
}

#----------------------------------------
# Прочие функции
#----------------------------------------

# -> string
# <- string
sub prompt
{
   my($msg) = @_;
   print $msg;
   return scalar readline;
}

# -> (any)
sub print_dump(@)
{
   require Data::Dump;
   say Data::Dump::dump(@_);
   return;
}

# -> {}
# <- (strings)
sub find_files
{
   my $args = {@_};
   die unless Params::Check::check({
      path => { required => 1 },
      regex  => {},
      maxlen => {},
      recursive => {},
   }, $args, 1);
   #----------------------------------------
   my @files;
   unless($args->{recursive})
   {
      @files = glob Yoba::catfile($args->{path}, "*");
   }
   else
   {
      File::Find::find({no_chdir => 1, wanted => sub {push @files, $_}}, $args->{path});
   }
   #----------------------------------------
   return grep {
      (!$args->{regex}  || /$$args{regex}/) &&
      (!$args->{maxlen} || -s $_ <= $args->{maxlen})
   } @files;
}

# -> any
# <- any | (any)
sub unref
{
   my($ref) = @_;
   given(ref $ref)
   {
      when("SCALAR") { return $$ref }
      when("ARRAY")  { return @$ref }
      when("HASH")   { return %$ref }
      when("CODE")   { return &$ref }
      when("REF")    { return unref($$ref) }
      default { Carp::croak "Bad type for unref: $_" }
   }
}

# -> string, string
sub notify($$)
{
   my($head, $message) = @_;
   system qq~notify-send "$head" "$message"~;
   return;
}

#----------------------------------------
# Функции для работы со строками
#----------------------------------------

# Эта функция оставляет в тексте только кириллицу
# и знаки, расставляет заглавные буквы, точки, удаляет
# лишние пробелы и пропуски строки.
#
# -> string
# <- string
sub yobatext
{
   my($text) = @_;
   use utf8;
   my $a = 'А-ЯЁа-яё';         # Кириллица
   my $b = '\.\,\!\?\"\(\)\-'; # Знаки
   my $c = '\.\,\!\?\"\(\)';   # Знаки без тире
   my $d = '\.\!\?';           # Завершающие знаки
   $text = decode("utf-8", $text);
   for($text)
   {
      tr/«»—/""-/;                  # Замена выёбистых кавычек и тире на обычные
      s/[^$a$b\s]/ /g;              # Замена не-кириллицы, не-знаков и не-пропусков пробелами
      s/([$a][$c])?[^$a]+?[$c]/($1 || "") . " "/ge; # Удаление знаков, которые следуют не после буквы
      s/(?:[$b]|\ {2,})\-//g;       # Удаление отдельных тире
      s/^[\ $b]+|[\ $b]+$//gm;      # Удаление знаков и пробелов в конце и начале строк
      s/\s+/ /g;                    # Замена скоплений пропусков на один пробел
      s/([$a][$d] )([$a])/$1\u$2/g; # Расстановка заглавных после завершающих знаков
      s/^([$a])/\u$1/gm;            # Расстановка заглавных в начале строк
      s/([$a])\ ([А-ЯЁ])/$1. $2/g;  # Расстановка точек перед заглавными
      s/[^$a]*$/./s;                # Точка в конце
   }
   return encode("utf-8", $text);
}

# Эта функция пропускает текст через фукнцию yobatext
# и разбивает его на предложения.
#
# -> \string
# <- (string)
sub split_text($)
{
   my($text) = @_;
   return grep {
      $_ = yobatext $_;
      length >= 10; # Кириллический символ здесь за 2
   } split /[\.\n\?\!]/, $$text;
}

#----------------------------------------
# Функции для работы с вебом
#----------------------------------------

# -> string
# <- string
sub http_get($)
{
   my($url) = @_;
   $url = setscheme($url);
   #----------------------------------------
   my $lwp = new Yoba::LWP;
   $lwp->agent("Opera/9.80 (X11; Linux i686; U; en) Presto/2.10.229 Version/11.61");
   $lwp->referer($url);
   #----------------------------------------
   my $res = $lwp->get($url);
   if($res->is_success)
   {
      return $res->{_content};
   }
   else
   {
      Carp::carp "Ошибка: не удалось скачать '$url'.\n";
      return;
   }
}

# -> string, string || [strings]
# <- HTTP::Response
sub http_post($$)
{
   my($url, $content) = @_;
   $url = setscheme($url);
   #----------------------------------------
   my $lwp = new Yoba::LWP;
   $lwp->agent("Opera/9.80 (X11; Linux i686; U; en) Presto/2.10.229 Version/11.61");
   $lwp->referer($url);
   #----------------------------------------
   my $res = $lwp->post(
      $url,
      Content_Type => ref($content) eq "ARRAY" ? "form-data" : "application/x-www-form-urlencoded",
      Content =>  $content,
   );
   #----------------------------------------
   return $res;
}

#----------------------------------------
# Прочие функции
#----------------------------------------

# -> string, string
# <- string
sub setscheme($;$)
{
   my($url, $scheme) = @_;
   $scheme ||= "http";
   return $url =~ m~^\w+://~ ? $url : "$scheme://$url";
}

# -> string
# <- string
sub gethost($)
{
   my($url) = @_;
   my($host) = $url =~ m~^((?:\w+://)?[^/]+)~;
   return $host . '/';
}

# -> (string)
# <- string
sub caturl(@)
{
   my $url = join "/", @_;
   $url =~ s~^(\w+://)/+~$1~;
   $url =~ s~([^:]/)/+~$1~g;
   return $url;
}

# -> string
# <- (string)
sub read_proxylist($)
{
   my($fname) = @_;
   my $file = read_file($fname);
   return parse_proxies($file);
}

# -> string
# <- (string)
sub parse_proxies($)
{
   my($text) = @_;
   #----------------------------------------
   my @proxies = $text =~ m~((?:\w+://)?[a-z0-9\.]*?\.(?:.{2,3}|\d{1,3}):\d{2,4})~gm;
   Yoba::array_unique(\@proxies);
   my @result;
   my %ips;
   for my $proxy (@proxies)
   {
      my($ip) = $proxy =~ m~(?:\w+://)?(.*?):\d+~;
      next if(length $ip < 8);
      push @result, $proxy unless $ips{$ip}++;
   }
   #----------------------------------------
   return map { setscheme($_) } @result;
}

2;


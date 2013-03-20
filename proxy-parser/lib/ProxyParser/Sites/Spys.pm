package ProxyParser::Sites::Spys;

use 5.010;
use strict;
use utf8;
use warnings;
use Carp;

use LWP;
use JE;

use ProxyParser::Common;

our $LWP = new LWP::UserAgent;
$LWP->default_header(Referer => "http://spys.ru/");
$LWP->agent("Opera/9.80 (X11; Linux i686) Presto/2.12.388 Version/12.14");

# -> string
# <- string
sub parse_proxys_function($)
{
   my($html) = @_;

   my($script) = $html =~ m~<script type="text/javascript">eval\((function\(p,r,o,x,y,s\).*?)</script>~s;
   Carp::confess "Не удалось найти '<script>...function(p,r,o,x,y,s)...</script>' на странице" unless $script;

   my($function) = $script =~ m~function\(p,r,o,x,y,s\){(.*?)return p}~s;
   Carp::confess "Не удалось найти код функции 'function(p,r,o,x,y,s)' на странице" unless $function;
   my($params) = $script =~ m~return p}\((.*?)\)\)~s;
   Carp::confess "Не удалось найти аргументы функции 'function(p,r,o,x,y,s)' на странице" unless $params;

   my @vars = qw/p r o x y s/;
   my @params = split /,/, $params;
   Carp::confess "Не ожидаемое количество аргументов функции 'function(p,r,o,x,y,s)'" if @params != @vars;

   my $params_str;
   for my $i (0 .. $#vars)
   {
      $params_str .= "var $vars[$i] = $params[$i];\n"
   }

   $function =~ s~y=fun~var y = fun~;
   return "$params_str\n$function";
}

# -> string
# <- ( string => string )
sub parse_raw_proxies($)
{
   my($html) = @_;

   my %proxies = $html =~ m~<td colspan=\d+>\s*<font class=spy\d+>\d+</font>\s*<font class=spy\d+>\s*(\d+\.\d+\.\d+\.\d+)\s*<script type="text/javascript">\s*document.write\(".*?"\s*\+\s*(.*?)\)\s*</script>\s*</font>\s*</td>~gs;
   Carp::confess "Не удалось найти ни одной прокси на странице" unless %proxies;

   return %proxies;
}

# -> JE, ( string => string )
sub escape_ports($%)
{
   my($js, %proxies) = @_;

   for my $proxy (keys %proxies)
   {
      my $res = $js->eval('""+' . $proxies{$proxy});
      if($res)
      {
         $proxies{$proxy} = $res->value;
      }
      else
      {
         warn "Не удалось извечь порт из '$proxies{$proxy}'";
         delete $proxies{$proxy};
      }
   }

   return %proxies;
}

# -> string
# <- (string)
sub parse_proxies_from_page($)
{
   my($html) = @_;

   my $js = new JE;

   my $func = parse_proxys_function($html);
   $js->eval($js->eval($func));

   my %proxies = escape_ports($js, parse_raw_proxies($html));

   return map { "http://$_:$proxies{$_}" } keys %proxies;
}

# -> string
# <- (string)
sub parse_states($)
{
   my($html) = @_;

   my @states = $html =~ m~<a href='/proxys/(\w+)/'>~g;
   Carp::confess "Не удалось найти страницу с прокси ни для одного из государств" unless @states;

   return @states;
}

# -> string
# <- (number)
sub parse_pages($)
{
   my($html) = @_;

   my @pages = $html =~ m~<a href='/proxys(\d+)/\w+/'>~g;

   return @pages;
}

# -> LWP::UserAgent, string, number
# <- string
sub get_main_page
{
   my($lwp, $state, $page) = @_;
   my $url = "http://spys.ru/proxys";
   say "Загрузка '$url'...";
   return $lwp->get($url)->content;
}

# -> LWP::UserAgent, string, number
# <- string
sub get_page($$$)
{
   my($lwp, $state, $page) = @_;
   my $url = "http://spys.ru/proxys" . ($page || "") . "/$state/";
   say "Загрузка '$page' of '$state' ('$url')...";
   return $lwp->get($url)->content;
}

# -> string
# <- (string)
sub parse_proxies_by_state($)
{
   my($state) = @_;

   my $lwp = $LWP->clone;

   my $html = get_page($lwp, $state, 0);
   my @pages =  parse_pages($html);

   my @proxies = parse_proxies_from_page($html);
   for my $page (@pages)
   {
      push @proxies, parse_proxies_from_page(get_page($lwp, $state, $page));
   }

   say "-> Найдено " . @proxies . " прокси страны '$state'";

   return @proxies;
}

# <- (string)
sub parse
{
   my $lwp = $LWP->clone;

   my @states = parse_states(get_main_page($lwp));

   my @proxies;
   for my $state (@states)
   {
      say "Поиск прокси страны '$state'...";
      eval { push @proxies, parse_proxies_by_state($state) };
      print $@ if $@;
   }

   return @proxies;
}

2;
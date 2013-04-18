use 5.010;
use strict;
use warnings;
use utf8;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Getopt::Long;
use JE;
use Yoba::LWP;
use Yoba::Coro;
use Yoba;

binmode STDOUT, ":utf8";

print_help() unless @ARGV;

my $opt = {
   threads => 500,
   timeout => 30,
};

GetOptions($opt,
   "id=s", "vote=s", "multi",
   "threads=s", "timeout=s", "debug",
   "proxylist=s",
   "help" => \&print_help,
);

sub print_help
{
   say <<HLP;
Использование:
   perl $0 [аргументы]

Справка:
   --id        | id опроса (в адресе страницы - без 'sp'/'sr' на конце!)
   --vote      | Номер пункта ИЛИ пункты через запятую, если --multi
   --multi     | В опросе можно указать несколько вариантов

   --proxylist | Файл с прокси

   --threads   | Количество запускаемых соединений
   --timeout   | Время в секундах, отводимое соединению
   --debug     | Сообщения для отладки

Примеры:
   --id wnacpryp --vote 1
   --id wnacpryp --multi --vote 2,4
HLP
   exit;
}

die unless $opt->{id} && $opt->{vote} && $opt->{proxylist};

my $lwp = new LWP::UserAgent;
$lwp->agent("Opera/9.80 (X11; Linux i686) Presto/2.12.388 Version/12.15");
$lwp->default_header(Referer => "http://www.rupoll.com/$opt->{id}sp.html");

sub parse_url($)
{
   my($html) = @_;

   my $url = eval {
      my($script, $url) = $html =~ /'javascript'>(.*);location\.replace\('(.*?)'\)/s;
      die unless $script && $url;

      my($fnd) = $url =~ /'\+(\w+)\+'/;
      die unless $fnd;

      my $js = new JE;
      $js->eval($script);
      $url =~ s/'\+$fnd\+'/$js->eval($fnd)/e;
      die unless $url;

      $url;
   };

   if($url) {
      return $url;
   } else {
      # warn $@;
      return;
   }
}

sub vote($)
{
   my($proxy) = @_;

   my $lwp = $lwp->clone;
   $lwp->cookie_jar({});
   $lwp->proxy("http", $proxy) if $proxy;

   my $content = "poll_id=$opt->{id}";
   if($opt->{multi}) {
      $content .= join "", map { "&vote$_=on" } split /,\s*/, $opt->{vote};
   } else {
      $content .= "&vote=$opt->{vote}";
   }

   my $res = $lwp->post(
      "http://www.rupoll.com/vote.php",
      Content_Type => "application/x-www-form-urlencoded",
      Content => $content,
   );

   my $url = parse_url $res->content;
   if($url) {
      my $res = $lwp->get($url);
      return $res->is_success;
   } else {
      return;
   }
}

my @proxy = read_proxylist $opt->{proxylist};

my $w = new Yoba::Coro::Watcher;
my $p = new Yoba::Coro::Pool(
   # debug => 1,
   desc => "vote",
   limit => $opt->{threads},
   timelimit => $opt->{timeout},
   params => \@proxy,
   function => sub {
      my($proxy) = @_;

      for my $a (1 .. 5) {
         my $res = vote $proxy;
         if($res) {
            say "$proxy: ok";
            return 1;
         } else {
            say "$proxy: fail";

         }
      }

      return;
   },
);

$p->start_all;
$p->join_all;
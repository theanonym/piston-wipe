#!/usr/bin/perl

use 5.010;
use strict;
use utf8;
use warnings;
use Carp;

use FindBin;
use lib "$FindBin::Bin/lib";

use Getopt::Long;
use File::Slurp;
use List::MoreUtils qw/uniq/;

use ProxyParser;

binmode STDOUT, ":utf8";

print_help() and exit unless @ARGV;

my $opt = {
   sites => "",
   out   => "out.txt",
};

GetOptions($opt,
   "sites=s", "out=s", "all",
   "help" => sub { print_help(); exit },
);

sub print_help
{
   say <<HLP;
Yoba proxy parser $ProxyParser::VERSION

Использование:
   perl $0 [аргументы]

Справка:
   --si(tes) | Сайты через запятую
   --al(l)   | Искать на всех сайтах
   --ou(t)   | Файл, куда записать прокси

Примеры:
   --site spys,fineproxy -o proxies.txt

Поддерживаемые сайты:
   spys (spys.ru), fineproxy (fineproxy.org),
   samair (samair.ru) xroxy (xroxy.com)
HLP
}

if($opt->{all})
{
   $opt->{sites} = join ",", @ProxyParser::SITES;
}

my @sites = map { lc } split /,\s*/, $opt->{sites};
die "Не указан сайт" unless @sites;
for(@sites) { die "Неизвестный сайт: '$_'" unless $_ ~~ @ProxyParser::SITES }

my @proxies;
for my $site (@sites)
{
   push @proxies, ProxyParser::parse("$site");
}
@proxies = uniq @proxies;

say "Всего найдено " . @proxies . " прокси.";
write_file($opt->{out}, join("\n", @proxies));
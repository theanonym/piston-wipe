#!/usr/bin/perl

use 5.010;
use strict;
use warnings;
use Carp;

use lib "lib";

use Term::ANSIColor qw/color colored/;

use Piston;

if(@ARGV) {
   require Piston::Args;
}

say colored("Piston Wipe ", "red bold") . colored($Piston::VERSION, "yellow bold");
say colored("Инициализация", "yellow bold");
Piston::init();
Piston::Engines::init();
Piston::Wipe::init();
Piston::Postform::init();

say colored("--- Запуск (режим $Piston::config->{wipe_mode}) ---", "yellow bold");
Piston::run();

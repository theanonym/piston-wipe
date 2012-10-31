package Yoba::Tesseract;

use 5.10.1;
use strict;
use warnings;
use Carp;

use File::Slurp qw/read_file write_file/;
use File::Copy qw/copy/;

use base "Exporter";
our @EXPORT = qw/tesseract/;

use Yoba;

# -> string, string
# <- int
sub convert($$) {
   my($scr, $dsc) = @_;
   my $code = system qq/ convert "$scr" -compress none +matte "$dsc" /;
   Carp::croak "Exit on other process" if $code == 2;
   Carp::carp $? if $code;
   return !$code;
}

# -> string, string, string
# <- string
sub tesseract($;$$) {
   my($fname, $lang, $config) = @_;
   #printf "Tesseract: распознавание '$fname' (%d)\n", -s $fname;
   #----------------------------------------
   unless(-s $fname) {
      warn "File '$fname' not exists";
      return;
   }
   #----------------------------------------
   my $tmpfile = $fname . ".tmp.tif";;
   unless($fname =~ /\.tiff?$/) {
      return unless convert($fname, $tmpfile);
   } else {
      copy($fname, $tmpfile);
   }
   #----------------------------------------
   my $cmd = qq/tesseract "$tmpfile" "$tmpfile"/;
   $cmd .= qq/ -l "$lang" /       if $lang;
   $cmd .= qq/ nobatch "$config"/ if $config;
   $cmd .= " 1>/dev/null 2>&1";
   my $code = system $cmd;
   $SIG{INT}->() if $code == 2;
   Carp::carp $? if $code;
   #----------------------------------------
   my $text = "";
   try {
      $text = read_file("$tmpfile.txt");
      unlink($tmpfile, "$tmpfile.txt");
   } catch {
      Carp::carp $_;
   };
   $text =~ s/^\s+|\s+$//g;
   #say "Распознано: $text";
   return $text;
}

2;

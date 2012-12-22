#----------------------------------------
#
#  Интерфейс к Tesseract OCR.
#
#  my $text = tesseract($filename, { options });
#
#----------------------------------------

package Yoba::OCR::Tesseract;

use 5.010;
use strict;
use warnings;
use Carp;

use File::Slurp qw/read_file write_file/;
use File::Copy qw/copy/;

use base "Exporter";
our @EXPORT = qw/tesseract/;

use Yoba;

# -> string, string
# <- bool
sub _convert($$)
{
   my($scr, $dsc) = @_;
   my $code = system qq/ convert "$scr" -compress none +matte "$dsc" /;
   Carp::croak "Завершено в другом процессе" if $code == 2;
   Carp::carp $? if $code;
   return !$code;
}

# -> string, { options }
# <- string
sub tesseract($$)
{
   my($filename, $options) = @_;
   #----------------------------------------
   unless(-s $filename)
   {
      warn "Файл '$filename' не найден";
      return;
   }
   #----------------------------------------
   my $tmpfile = $filename . ".tmp.tif";
   unless($filename =~ /\.tiff?$/)
   {
      return unless _convert($filename, $tmpfile);
   }
   else
   {
      copy($filename, $tmpfile);
   }
   #----------------------------------------
   my $cmd = qq~tesseract "$tmpfile" "$tmpfile" ~;
   $cmd .= qq~ -l "$options->{lang}" ~        if $options->{lang};
   $cmd .= qq~ nobatch "$options->{config}" ~ if $options->{config};
   $cmd .= qq~ 1>/dev/null 2>&1 ~;
   my $code = system $cmd;
   $SIG{INT}->() if $code == 2;
   Carp::carp $? if $code;
   #----------------------------------------
   my $text = "";
   try
   {
      $text = read_file("$tmpfile.txt");
      unlink($tmpfile, "$tmpfile.txt");
   }
   catch
   {
      Carp::carp $_;
   };
   $text =~ s/^\s+|\s+$//g;
   #----------------------------------------
   return $text;
}

2;

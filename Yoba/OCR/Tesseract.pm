package Yoba::OCR::Tesseract;

use 5.10.1;
use strict;
use warnings;
use Carp;

use base "Exporter"; our @EXPORT = qw/get_ocr/;

use Yoba;
use Yoba::Tesseract;

# -> string
# <- string
sub get_ocr($;@) {
   my($file, @args) = @_;
   @args = ("eng", "english") unless @args;
   my $text = tesseract($file, $args[0], $args[1]);
   # $text =~ s/[^a-z]//i;
   # $text =~ s/\s+|\s+//g;
   return $text;
}

2;

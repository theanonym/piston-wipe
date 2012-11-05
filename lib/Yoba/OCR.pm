package Yoba::OCR;

use 5.10.1;
use strict;
use warnings;
use Carp;

use Yoba;
use Yoba::Object;

has "mode";
has "file";
has "text";

sub CONSTRUCT {
   my $self = shift;
   given($self->{mode}) {
      when(/hands?/) {
         eval "use Yoba::OCR::Hands; 1" or Carp::croak $@;
      } when(/tesse?r?a?c?t?/) {
         eval "use Yoba::OCR::Tesseract; 1" or Carp::croak $@;
      } when(/antigate/) {
         eval "use Yoba::OCR::Antigate; 1" or Carp::croak $@;
      } default {
         Carp::croak "Неверный режим";
      }
   }
}

sub DESTRUCT {
   my $self = shift;
   if($self->{delete}) {
      $self->delete;
   }
}

# -> (any)
# <- string
sub run(@) {
   my $self = shift;
   my(@args) = @_;
   # $self->{args} = \@args if @args;

   unless($self->has_file) { Carp::croak "Нет файла капчи" };
   $self->{text} = get_ocr($self->{file}, @{ $self->{args} });
   return $self->{text};
}

# -> string, (any)
# <- string
sub get_ocr($;@) {
   Carp::croak "Метод не определён";
}

# <- bool
sub has_file {
   return defined $_[0]->{file};
}

# <- bool
sub is_entered {
   return defined $_[0]->{text} && length $_[0]->{text};
}

sub delete {
   my $self = shift;
   if($self->has_file) {
      unlink $self->{file};
   }
   return;
}

2;

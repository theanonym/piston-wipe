package Yoba::OCR;

use 5.010;
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
      when(/hands/) {
         eval "use Yoba::OCR::Hands; 1" or die $@;
      } when(/tesse?r?a?c?t?/) {
         eval "use Yoba::OCR::Tesseract; 1" or die $@;
      } when(/antigate/) {
         require Yoba::OCR::Antigate;
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

   unless($self->has_file) {
      Carp::croak "Нет файла капчи";
   };

   given($self->{mode}) {
      when(/hands/) {
         my $type = $self->{mode} =~ /hands(.*)/;
         $self->{text} = get_ocr($1, $self->{file}, @args);
      }

      when(/tesse?r?a?c?t?/) {
         $self->{text} = get_ocr($self->{file}, @{ $self->{args} });
      }

      when(/antigate/) {
         my $ag = new Yoba::OCR::Antigate(%{ $self->{args} });
         say "Отправка капчи на antigate.com";
         my $id = $ag->send_captcha($self->{file});
         say "Ожидание ответа antigate.com";
         $self->{text} = $ag->get_ocr($id);
         say "Ответ antigate.com получен";
      }
   }

   return $self->{text};
}

# -> string, (any)
# <- string
sub get_ocr {
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

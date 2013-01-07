#----------------------------------------
#
# Различные инструменты для распознавания капчи.
#
# my $ocr = new Yoba::OCR(( options ));
# my $text = $ocr->run;
#
#----------------------------------------

package Yoba::OCR;

use 5.010;
use strict;
use warnings;
use Carp;

use Yoba;
use Yoba::Object;

use Yoba::OCR::Tesseract;
use Yoba::OCR::Antigate;

has "mode";
has "file";
has "text";

has "opt_hands";
has "opt_tesseract";
has "opt_antigate";

sub CONSTRUCT
{
   my $self = shift;
   Carp::croak "Неверный режим капчи" unless $self->{mode} ~~ ["hands", "tesseract", "antigate"];
}

sub DESTRUCT
{
   my $self = shift;
   $self->delete_file if $self->{delete_file};
}

# -> (options)
# <- string
sub run(;@)
{
   my $self = shift;
   my $new_options = { @_ } if @_;
   #----------------------------------------
   unless($self->has_file)
   {
      Carp::carp "Нет файла капчи";
      return;
   }
   #----------------------------------------
   given($self->{mode})
   {
      when(/hands/)
      {
         my $title = "Captcha";
         $title = $new_options->{title} if $new_options->{title};
         $self->{opt_hands}->{whitelist} ||= "";
         my $cmd = qq~bin/captcha "$self->{file}" "$title" ~;
         $cmd .= qq~"$self->{opt_hands}->{whitelist}" ~ if $self->{opt_hands}->{whitelist};
         $self->{text} = readpipe $cmd;
      }

      when(/tesseract/)
      {
         $self->{text} = tesseract($self->{file}, $self->{opt_tesseract});
      }

      when(/antigate/)
      {
         my $ag = new Yoba::OCR::Antigate(%{ $self->{opt_antigate} });
         say "Antigate: отправка капчи";
         my $id = $ag->send_captcha($self->{file});
         unless($id)
         {
            $self->{text} = "";
            say "Antigate: не удалось получить id";
            return;
         }
         say "Antigate: ожидание ответа";
         $self->{text} = $ag->receive_text($id);
         say "Antigate: ответ получен";
      }
   }
   #----------------------------------------
   return $self->{text};
}

sub delete_file
{
   my $self = shift;
   unlink $self->{file};
   return;
}

# <- bool
sub has_file
{
   my $self = shift;
   return $self->{file} && -s $self->{file};
}

# <- bool
sub is_entered
{
   my $self = shift;
   return $self->{text} && length $self->{text};
}

2;
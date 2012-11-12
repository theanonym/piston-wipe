package Yoba::OCR::Hands;

use 5.010;
use strict;
use warnings;
use Carp;

use base "Exporter";
our @EXPORT = qw/get_ocr/;

#use Gtk2 -init;

use Yoba;

# -> string, string
# <- string
sub get_ocr {
   my($type, $file, $title) = @_;
   $title ||= "";
   my $cmd;
   if($type eq "qt") {
      $cmd = qq~./bin/qt_captcha $file $title~;
   } elsif($type eq "gtk") {
      $cmd = qq~./bin/gtk_captcha $file $title~;
   } else {
      Carp::croak $type;
   }
   return `$cmd`;
}

# -> string, string
# <- string
#sub _get_ocr($;@) {
   #my($file, $title) = @_;
   #my $text;
   ##----------------------------------------
   #my $image;
   #eval {
      ## Gtk2::Image->new_from_file() неправильно работает с некоторыми форматами.
      #my $pixbuf = Gtk2::Gdk::Pixbuf->new_from_file($file);
      #$image  = Gtk2::Image->new_from_pixmap($pixbuf->render_pixmap_and_mask(255));
   #};
   #warn $@ and return if $@;
   ##----------------------------------------
   #my $mw = new Gtk2::Window("toplevel");
   #$mw->set_position("center");
   #$mw->set_title($title // "Captcha");
   #$mw->signal_connect(destroy => sub { Gtk2->main_quit });
   ##----------------------------------------
   #my $vbox  = new Gtk2::VBox;
   #my $entry = new Gtk2::Entry;
   #$entry->signal_connect(
      #activate => sub {
         #$text = Yoba::encode("utf-8", $entry->get_text);
         #$mw->destroy;
         #Gtk2->main_quit;
      #},
   #);
   ##----------------------------------------
   #$vbox->pack_start($image, 0, 0, 20);
   #$vbox->pack_start($entry, 0, 0, 0);
   #$mw->add($vbox);
   #$mw->show_all;
   #Gtk2->main;
   ##----------------------------------------
   #return $text;
#}

2;

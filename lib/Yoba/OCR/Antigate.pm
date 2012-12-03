package Yoba::OCR::Antigate;

use 5.010;
use strict;
use warnings;

use Params::Check qw/check/;

use Yoba;
use Yoba::Coro;
use Yoba::Object;

our $lwp = new Yoba::LWP;

sub CONSTRUCT
{
   my $self = shift;

   die unless check({
      key        => { required => 1 },
      phrase     => {},
      regsense   => {},
      numeric    => {},
      calc       => {},
      min_len    => {},
      max_len    => {},
      is_russian => {},
   }, $self, 1);
}

# -> string
# <- string
sub send_captcha($)
{
   my $self = shift;
   my($fname) = @_;
   die unless -s $fname;

   my $res = $lwp->post("http://antigate.com/in.php",
      Content_Type => "form-data",
      Content => [
         method => "post",
         key    => $self->{key},

         phrase     => $self->{phrase},
         regsense   => $self->{regsense},
         numeric    => $self->{numeric},
         calc       => $self->{calc},
         min_len    => $self->{min_len},
         max_len    => $self->{max_len},
         is_russian => $self->{is_russian},

         file => [$fname],
      ],
   );

   if($res->content =~ /^OK\|(.*)/)
   {
      return $1;
   }
   else
   {
      warn $res->content;
      return;
   }
}

# -> string
# <- string
sub get_ocr($)
{
   my $self = shift;
   my($id) = @_;

   while(1)
   {
      my $res = $lwp->get("http://antigate.com/res.php?key=$$self{key}&action=get&id=$id");

      if($res->content =~ /^OK\|(.*)/)
      {
         return $1;
      }
      elsif($res->content =~ /^CAPCHA_NOT_READY/)
      {
         Coro::AnyEvent::sleep(3);
      }
      else
      {
         warn $res->content;
         return;
      }
   }
}

2;

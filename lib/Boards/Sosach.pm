package Boards::Sosach;

use 5.010;
use strict;
use warnings;
use Carp;

use Yoba;
use Yoba::LWP;

use base "Exporter";
our @EXPORT = qw/
   check_thread_exists count_posts count_threads
   delete_post get_all_threads get_board_page
   get_catalog_page get_last_post get_thread_page
   parse_image_links parse_post_refs parse_posts
   parse_threads_list parse_threads_table
/;
our @EXPORT_OK = @EXPORT;

# -> string, number
sub get_board_page($$)
{
   my($board, $page) = @_;
   my $url = "http://2ch.hk/$board/" . ($page ? "$page.html" : "");
   return Yoba::http_get($url);
}

# -> string, number
# <- string
sub get_thread_page($$)
{
   my($board, $thread) = @_;
   return Yoba::http_get("http://2ch.hk/$board/res/$thread.html");
}

# -> string
# <- (string)
sub parse_posts($)
{
   my($html) = @_;
   return grep {
      $_ = Yoba::yobatext($_);
      length Yoba::decode("utf-8", $_) > 10
   } $html =~ m~class="postMessage"><p>(.*?)</blockquote>~gs;
}

# -> string
# <- (number)
sub parse_post_refs($)
{
   my($html) = @_;
   return($html =~ /<table id="post_(\d+)"/g);
}

# -> string, number
# <- (string)
sub parse_image_links($)
{
   my($html) = @_;
   return map { "http://2ch.hk$_" } $html =~ m~<a target="_blank" href="(/\w+/src/\d+\.\w+)">~g;
}

2;

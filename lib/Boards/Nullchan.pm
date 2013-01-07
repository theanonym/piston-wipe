package Boards::Nullchan;

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

# -> string, int
# <- string
sub get_board_page($$) {
   my($board, $page) = @_;
   my $url = "http://0chan.hk/$board/" . ($page ? "$page.html" : "");
   return Yoba::http_get($url);
}

# -> string, int
# <- string
sub get_thread_page($$) {
   my($board, $thread) = @_;
   return Yoba::http_get("http://0chan.hk/$board/res/$thread.html");
}

# -> string
# <- string
sub get_catalog_page($) {
   my($board) = @_;
   return Yoba::http_get("http://0chan.hk/$board/catalog.html");
}

# -> string
# <- (string)
sub parse_threads_list($) {
   my($html) = @_;
   return($html =~ /^<a href=\"\/\w+\/res\/(\d+).*?^<small>\d+/gms);
}

# -> string
# <- %(string => string)
sub parse_threads_table($) {
   my($html) = @_;
   return($html =~ /^<a href=\"\/\w+\/res\/(\d+).*?^<small>(\d+)/gms);
}

# -> string
# <- (string)
sub parse_posts($) {
   my($html) = @_;
   return grep {
      $_ = Yoba::yobatext($_);
      length Yoba::decode("utf-8", $_) > 10
   } $html =~ /^<blockquote><div class="postmessage">(.*?)<\/div><\/blockquote>$/gms;
}

# -> string
# <- (string)
sub parse_post_refs($){
   my($html) = @_;
   return($html =~ /^\s+<a name="(\d+)"><\/a>$/gm);
}

# -> string
# <- (string)
sub parse_image_links($) {
   my($html) = @_;
   my @res = $html =~ m~http://(?:img.)?0chan.hk/\w+/src/\w+\.\w+~g;
   Yoba::array_unique(\@res);
   return @res;
}

# -> string
# <- int
sub count_threads($) {
   my($board) = @_;
   my @threads = parse_threads_list(get_catalog_page($board));
   return 0 + @threads;
}

# -> string, int
# <- int(-1 - тред не существует)
sub count_posts($$) {
   my($board, $thread) = @_;
   my %catalog = parse_threads_table(get_catalog_page($board));
   return $catalog{$thread} // -1;
}

# -> string, int
# <- int(код ответа)
sub check_thread_exists($$) {
   my($board, $thread) = @_;
   my $lwp = new Yoba::LWP;
   return $lwp->head("http://0chan.hk/$board/res/$thread.html")->code;
}

# -> string
# <- int
sub get_last_post($) {
   my($board) = @_;
   my $thread = (sort { $b <=> $a } get_board_page($board, 0) =~ /^\t<a href[^#]*?#(\d+)/gm)[0];
   return $thread;
}

# -> string, string, int
# <- bool
sub delete_post($$$) {
   my($board, $post, $pass) = @_;
   my $lwp = new Yoba::LWP(timeout => 20);
   $lwp->agent("Opera/9.80 (X11; Linux i686; U; en) Presto/2.10.289 Version/12.00");
   $lwp->referer("http://0chan.hk/");
   my $res = $lwp->post("http://0chan.hk/board.php",
      Content_Type => "application/x-www-form-urlencoded",
      Content => "board=$board&delete=$post&postpassword=$pass",
   );
   say $res->as_string;
   return $res->{_content} =~ /Сообщение удалено/;
}

2;

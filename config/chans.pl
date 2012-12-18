# Настройки имиджборд

our $chans = {
   nullchan => {
      url  => "http://0chan.hk/",
      engine => "nullchan",
      captcha => {
         type => "png",
      },
      hands => {
         whitelist => "аетовриндлжусяпзгкюычм",
      },
      tesseract => {
         lang   => "eng",
         config => "eng_lowcase",
      },
      antigate  => {
         key        => "",
         is_russian => 1,
         min_len    => 7,
         max_len    => 7,
      },
      threads_delay => 30 * 60,
      posts_delay   => 20,
   },
};

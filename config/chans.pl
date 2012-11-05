# Настройки имиджборд

our $chans = {
   nullchan => {
      url  => "http://0chan.hk/",
      engine => "nullchan",
      captcha => "png",
      tesseract => ["eng", "eng_lowcase"],
      threads_delay => 30 * 60,
      posts_delay   => 20,
   },
};

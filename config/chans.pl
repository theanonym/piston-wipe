# Настройки имиджборд

our $chans = {
   nullchan => {
      url  => "http://0chan.hk/",
      engine => "nullchan",
      captcha => { type => "png", chars => "аетовриндлжусяпзгкюычм" },
      tesseract => ["eng", "eng_lowcase"],
      antigate  => { key => "", is_russian => 1 },
      threads_delay => 30 * 60,
      posts_delay   => 20,
   },
};

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

   iichan => {
      url    => "http://iichan.hk/",
      engine => "iichan",
      captcha => {
         type => "gif",
      },
      hands => {
         whitelist => join "", 'a' .. 'z',
      },
      tesseract => {
         lang   => "eng",
         config => "eng_lowcase",
      },
      antigate => {
         key => "",
      },
      threads_delay => 60,
      posts_delay   => 1,
   },

   uchan => {
      url    => "http://uchan.to/",
      engine => "uchan",
      threads_delay => 60,
      posts_delay   => 15,
   },

   alterchan => {
      url    => "http://alterchan.net/",
      engine => "alterchan",
      threads_delay => 0,
      posts_delay   => 0,
      passwords => ["qwerty"],
   },

   onechan_boards => {
      url    => "http://1chan.ru/",
      engine => "onechanboards",
      captcha => {
         type => "jpeg",
      },
      hands => {
         whitelist => join "", 'a' .. 'z', 0 .. 9,
      },
      antigate => {
         key => "",
      },
      threads_delay => 0,
      posts_delay   => 0,
      homeboards => ["anonymous"],
   }
};

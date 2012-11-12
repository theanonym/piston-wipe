our $config = {
   enable_extensions => 1,

   ocr_mode   => "handsgtk",

   wipe_mode => 2,

   use_proxy => 1,
   proxylist => "",

   proxies_max    => 0,
   proxies_ignore => 0,

   chan    => "nullchan",
   board   => "b",
   threads => [],

   pregen => 0,

   postform => {
      text_mode   => "",
      images_mode => "captcha",

      randreply => 0,

      text   =>  "",

      folder => {
         path => "",
         regex  => qr/(jpg|png|gif)$/i,
         maxlen => 50 * 1024,
         recursive => 0,
      },

      email    => '',
      name     => '',
      subject  => '',
      password => '',
   },

   max_connections => 300,

   captcha_timelimit => 30.00,
   post_timelimit    => 20.00,
   captcha_attempts  => 3,
   post_attempts     => 3,
   errors_limit      => 20,

   loglevel => 4,
};

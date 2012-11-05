our $config = {
   enable_extensions => 1,

   ocr_mode   => "hands",

   wipe_mode => 1,
   use_proxy => 1,
   proxylist => "",

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

---
title: About Convos - The simplest IRC client around
description: A multiuser chat web app for IRC. Always online, supports video, custom theming and is extremely easy to install
image: /screenshots/2020-05-28-convos-chat.jpg
---

<div class="hero-wrapper is-before-content">
  <header class="hero">
    <div class="hero--text">
      <h1><img src="/images/convos-light.png" alt="Convos"></h1>
      <p class="tagline">&mdash; A better chat experience</p>
      <p class="small">Convos is the simplest way to use IRC and it is always online.</p>
      <a href="#instant-demo" class="btn"><i class="fas fa-sign-in-alt"></i> Try the demo</a>
    </div>
    <a href="#instant-demo" class="hero--media">
      <img src="/screenshots/2020-05-28-convos-chat.jpg" alt="Picture of Convos conversation">
    </a>
  </header>
</div>

<section class="cards">
  <a href="#instant-demo" class="cards--card">
    <i class="fas fa-eye"></i>
    <h3>Curious?</h3>
    <span>Check out the <u>demo</u>!</span>
  </a>
  <a href="/doc/start" class="cards--card">
    <i class="fas fa-running"></i>
    <h3>Ready to start?</h3>
    <span><u>Install</u> Convos.</span>
  </a>
  <a href="#features" class="cards--card">
    <i class="fas fa-list-ul"></i>
    <h3>Undecided?</h3>
    <span>Check out our <u>feature list</u>.</span>
  </a>
</section>

## About

Convos is an IRC client that runs in your browser and brings the IRC experience
into the 21st century. It features a persistent bouncer on the server side that
will keep you online even after you close your browser window. Want to use
Convos on your phone? No problem! Convos is fully responsive and fits any
screen. Convos can be installed on your home server,
[cloud service](/blog/2019/11/26/convos-on-digital-ocean), or in [Docker](/doc/start#docker).

<div class="text-center">
  <a href="https://snapcraft.io/convos"><img src="https://snapcraft.io/convos/badge.svg" alt="snapcraft.io"></a>
  <a href="https://hub.docker.com/r/nordaaker/convos"><img src="https://img.shields.io/docker/build/nordaaker/convos" alt="Docker"></a>
  <!-- a href="https://travis-ci.org/Nordaaker/convos"><img src="https://travis-ci.org/Nordaaker/convos.svg?branch=master" alt="Build status"></a -->
  <a href="https://github.com/nordaaker/convos/issues"><img src="https://img.shields.io/github/issues/nordaaker/convos" alt="Issues"></a>
</div>

## Newsletter

<!-- Begin Mailchimp Signup Form -->
<div id="mc_embed_signup">
  <form action="https://chat.us3.list-manage.com/subscribe/post?u=cb576a11a8fb288554f82bbe8&amp;id=3ed96b7f9e" method="post" id="mc-embedded-subscribe-form" name="mc-embedded-subscribe-form" class="validate" target="_blank" novalidate>
    <p class="text-center">
      Sign up with your email address to get Convos news!
    </p>
    <div id="mc_embed_signup_scroll" class="signup">
      <div class="mc-field-group text-field">
        <input type="email" value="" name="EMAIL" class="required email" id="mce-EMAIL" placeholder="Email address" required>
      </div>
      <div style="position: absolute; left: -5000px;" aria-hidden="true"><input type="text" name="b_cb576a11a8fb288554f82bbe8_3ed96b7f9e" tabindex="-1" value=""></div>
      <button type="submit" class="button btn" name="subscribe" id="mc-embedded-subscribe">Sign up</button>
    </div>
    <div id="mce-responses">
      <div class="response" id="mce-error-response" style="display:none"></div>
      <div class="response" id="mce-success-response" style="display:none"></div>
    </div>
  </form>
</div>
<script type='text/javascript' src='//s3.amazonaws.com/downloads.mailchimp.com/js/mc-validate.js'></script><script type='text/javascript'>(function($) {window.fnames = new Array(); window.ftypes = new Array();fnames[0]='EMAIL';ftypes[0]='email';fnames[1]='FNAME';ftypes[1]='text';fnames[2]='LNAME';ftypes[2]='text';fnames[3]='ADDRESS';ftypes[3]='address';fnames[4]='PHONE';ftypes[4]='phone';}(jQuery));var $mcj = jQuery.noConflict(true);</script>
<!--End mc_embed_signup-->

## Features

<section class="cards is-wide">
  <div class="cards--card">
    <i class="fas fa-plug"></i>
    <h3>Always online</h3>
    <p>Convos keeps you online and logs all activity in your archive.</p>
  </div>
  <div class="cards--card">
    <i class="fas fa-video"></i>
    <h3>Video chat</h3>
    <p>Convos let's you <a href="/blog/2020/5/23/experimental-video-support-using-webrtc">video chat</a>
      with a single person or multiple participants.</p>
  </div>
  <div class="cards--card">
    <i class="fas fa-paint-roller"></i>
    <h3>Themes</h3>
    <p>Convos comes with a selection of <a href="/blog/2020/5/14/theming-support-in-4-point-oh">color themes</a>,
      so you can personalize it to your taste.</p>
  </div>
  <div class="cards--card">
    <i class="fas fa-grin-hearts"></i>
    <h3>Rich formatting</h3>
    <p>Convos makes the chat come alive with emojis and media displayed inline.</p>
  </div>
  <div class="cards--card">
    <i class="fas fa-user-shield"></i>
    <h3>Private</h3>
    <p>You own and control all your settings, logs, and uploaded files from <a href="/doc/faq">your server</a>.</p>
  </div>
  <div class="cards--card">
    <i class="fas fa-download"></i>
    <h3>Easy to install</h3>
    <p>No need for external servers or complex config files to <a href="/doc/start">get up and running</a>.</p>
  </div>
</section>

## Instant demo

Want to try out Convos? Sign up with your email address and instantly see how
Convos works. You might also run into the developers in the `#convos` channel.

<p class="text-center has-extra-vertical-margin">
  <a href="/login#signup" class="btn"><i class="fas fa-user-plus"></i> Sign up</a>
  <a href="/login" class="btn"><i class="fas fa-sign-in-alt"></i> Sign in</a>
</p>

Note that the demo is [locked](/doc/config#convosforcedircserver) to the
IRC server running on localhost. This is to prevent the server from getting
banned from IRC networks with strict limitations.

<style>
article > h1 {
  height: 1px;
  width: 1px;
  overflow: hidden;
  position: absolute;
  top: -1px;
  left: -1px;
}

article > h2 {
  text-align: center;
}

.hero-wrapper {
  margin-bottom: 2rem;
}

.hero--media {
  text-align: center;
  padding: 1rem;
  display: block;
  position: relative;
  top: 1.5rem;
}

.hero--media img {
  border-radius: 0.5rem;
  box-shadow: 0 0 8px 2px rgba(0, 0, 0, 0.25);
  max-width: 90%;
}

.signup {
  display: flex;
  align-items: start;
}

.signup > * {
  margin: 0;
}

.signup .text-field {
  flex: 1 0 0;
}

#mc_embed_signup {
  max-width: 28rem;
  margin: 0 auto;
}

#mce-responses {
  margin: 1rem 0;
}

#mc_embed_signup div.mce_inline_error {
  font-weight: inherit !important;
}

@media (min-width: 800px) {
  .hero-wrapper {
    margin-bottom: 4rem;
  }

  .hero--text {
    max-width: 20rem;
    padding-left: 2rem;
    padding-right: 2rem;
  }

  .hero--media {
    padding: 0;
    width: 50%;
    left: 2rem;
    transform: scale(1.2);
  }
}

@media (min-width: 1100px) {
  .hero-wrapper {
    margin-bottom: 8rem;
  }

  .hero--media {
    top: 3rem;
    left: 6rem;
    transform: scale(1.5);
  }
}
</style>

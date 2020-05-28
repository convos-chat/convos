---
title: About Convos - The simplest IRC client around
---

<div class="hero-wrapper is-before-content">
  <header class="hero has-max-width">
    <div class="hero--text">
      <h1>
        <img src="/images/convos-light.png" alt="Convos">
        <small class="tagline">&mdash; A better chat experience</small>
        <small>Convos is the simplest way to use IRC, and it keeps you always online.</small>
      </h1>
      <a href="#demo" class="btn">Try the demo</a>
    </div>

    <a href="/doc/start" class="hero--media">
      <img src="/screenshots/2020-05-28-convos-chat.jpg" alt="Picture of Convos conversation">
    </a>
  </header>
</div>

<section class="cards">
  <a href="#demo" class="cards--card">
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

Convos is the simplest way to use [IRC](http://www.irchelp.org/). It is always
online, and accessible to your web browser, both on desktop and mobile. Run it
on your home server, [cloud service](/blog/2019/11/26/convos-on-digital-ocean)
or in [Docker](/doc/start#docker).

<div class="text-center">
  <a href="https://snapcraft.io/convos"><img src="https://snapcraft.io/convos/badge.svg" alt="snapcraft.io"></a>
  <a href="https://hub.docker.com/r/nordaaker/convos"><img src="https://img.shields.io/docker/build/nordaaker/convos" alt="Docker"></a>
  <!-- a href="https://travis-ci.org/Nordaaker/convos"><img src="https://travis-ci.org/Nordaaker/convos.svg?branch=master" alt="Build status"></a -->
  <a href="https://github.com/nordaaker/convos/issues"><img src="https://img.shields.io/github/issues/nordaaker/convos" alt="Issues"></a>
</div>

## Newsletter

<form class="signup">
  <div class="text-field">
    <input type="text" name="email" placeholder="your@email">
  </div>
  <button class="btn">Sign up</button>
</form>

<p class="text-center">
  Sign up with your e-mail address to get Convos news delivered to your inbox!
</p>

## Features

<section class="cards is-wide">
  <div class="cards--card">
    <i class="fas fa-plug"></i>
    <h3>Always online</h3>
    <p>Convos keeps you logged in and logs all the activity in your archive.</p>
  </div>
  <div class="cards--card">
    <i class="fas fa-video"></i>
    <h3>Video chat</h3>
    <p>With Convos you can <a href="/blog/2020/5/23/experimental-video-support-using-webrtc">video chat</a>
    with a single person or multiple participants in a conversation.</p>
  </div>
  <div class="cards--card">
    <i class="fas fa-paint-roller"></i>
    <h3>Theming</h3>
    <p>Convos comes bundled with a selection of <a href="/blog/2020/5/14/theming-support-in-4-point-oh">themes</a>, and also supports dark mode</p>
  </div>
  <div class="cards--card">
    <i class="fas fa-grin-hearts"></i>
    <h3>Rich formatting</h3>
    <p>Convos makes the chat come alive with emojis and media displayed inline.</p>
  </div>
  <div class="cards--card">
    <i class="fas fa-user-shield"></i>
    <h3>Private</h3>
    <p>You own and control all your settings, logs and uploaded files from <a href="/doc/faq">your own computer</a>.</p>
  </div>
  <div class="cards--card">
    <i class="fas fa-download"></i>
    <h3>Easy to install</h3>
    <p>No need for external servers or complex config files to <a href="/doc/start">get up and running</a>.</p>
  </div>
</section>

## Demo

Want to try out Convos?  Register with your email address and try it out. There
should be someone lurking in the `#test` channel.

<div class="text-center">
  <a href="/login" class="btn">Register</a>
  <br>
  <br>
</div>

Note that the demo is [locked](/doc/config#convosforcedircserver) to the
IRC server running on localhost. This is to prevent the server from getting
banned from IRC networks with strict limitations.

<style>
.cms-content > h2 {
  text-align: center;
}

.hero-wrapper {
  background: var(--sidebar-left-bg);
  margin-bottom: 5rem;
}

.hero {
  height: 80vh;
  max-height: 20rem;
  padding: 2rem var(--gutter) 0 var(--gutter);
}

.hero--text {
  color: var(--sidebar-left-text);
  text-align: center;
}

.hero--text h1 {
  font-size: 2.8rem;
  margin-top: 0;
}

.hero--text h1 img {
  display: none;
}

.hero--text h1 small {
  font-size: 0.9rem;
  font-weight: normal;
  margin: 0.5rem 0;
  display: block;
}

.hero--text h1 .tagline {
  font-size: 1.2rem;
  font-style: italic;
}

.hero--media {
  display: block;
  position: relative;
  top: 1.5rem;
}

.hero--media img {
  border-radius: 0.5rem;
  box-shadow: 0 0 8px 2px rgba(0, 0, 0, 0.25);
}

.signup {
  max-width: 24rem;
  margin: 0 auto;
  display: flex;
  align-items: end;
}

.signup > * {
  margin: 0;
}

.signup .text-field {
  flex: 1 0 0;
}

@media (min-width: 800px) {
  .hero {
    display: flex;
    align-items: center;
  }

  .hero--text {
    padding: var(--gutter);
    text-align: left;
    width: 50%;
    max-width: 20rem;
  }

  .hero--text h1 img {
    display: block;
    height: 2.8rem;
  }

  .hero--media {
    width: 50%;
    left: 2rem;
    transform: scale(1.2);
  }
}

@media (min-width: 1100px) {
  .hero--media {
    top: 3rem;
    left: 6rem;
    transform: scale(1.5);
  }
}
</style>

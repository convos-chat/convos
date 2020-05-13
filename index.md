---
layout: page
title: About
---

Convos is the simplest way to use [IRC](http://www.irchelp.org/). It is always
online, and accessible to your web browser, both on desktop and mobile. Run it
on your home server, [cloud service](/blog/2019-11-26-convos-on-digital-ocean)
or in [Docker](/doc/getting-started.md#docker).

Curious? Try ut our [demo](#demo). Eager? [Download and install](/doc/getting-started.html)
Convos for free! Unsure? Check out the [feature](#features) list.

[![convos](https://snapcraft.io//convos/badge.svg)](https://snapcraft.io/convos)
[![Docker Build Status](https://img.shields.io/docker/build/nordaaker/convos)](https://hub.docker.com/r/nordaaker/convos)
[![Build Status](https://travis-ci.org/Nordaaker/convos.svg?branch=master)](https://travis-ci.org/Nordaaker/convos)
[![GitHub issues](https://img.shields.io/github/issues/nordaaker/convos)](https://github.com/nordaaker/convos/issues)

<div style="height: 340px;overflow:hidden;border-radius: 0.5rem; box-shadow:0 0 8px 3px rgba(0, 0, 0, 0.3)">
  <a href="/doc/getting-started.html"><img src="/public/screenshots/2019-10-26-conversation.jpg" alt="Picture of Convos conversation"></a>
</div>

## Demo

There is an online demo running at [demo.convos.by](http://demo.convos.by).
Register with your email address and try it out. There should be someone
lurking in the `#test` channel.

Note that the demo is [locked](/doc/config.html#convosforcedircserver) to the
IRC server running on localhost. This is to prevent the server from getting
banned from IRC networks with strict limitations.

## Features

* ___Always online___ -
  The backend server will keep you logged in and logs all the activity in your
  archive.

* ___Private___ -
  Convos is all about privacy. By default, no data will be exchanged with third
  parties. You own and control all your settings, logs and uploaded files from
  your own computer.

* ___Archive___ -
  All chats will be logged persistently, which allow you to go back in history or
  search for any sent message.

* ___Notifications___ -
  Convos will track whenever you are mentioned in a conversation and display
  desktop notifications.

* ___Rich formatting___ -
  Convos will format markdown, making the IRC experience feel more alive. Emojis
  support is built in, and photos and video will be displayed inline. No need to
  click on the link to view the data. You can upload your own files and create
  pastebins directly from the chat input.

* ___Custom theming___ -
  Convos comes bundled with a selection of themes that change between dark/light
  mode together with the settings on your desktop/phone. You can also
  [define your own themes](/2020/5/14/theming-support-in-4-point-oh.html)
  that are local to your Convos instance.

* ___Snappy interface___ -
  Convos uses the [Svelte](https://svelte.dev/) web app compiler in the frontend,
  and the real-time web framework [Mojolicious](https://mojolicious.org/) in the
  backend, making Convos very snappy and lightweight.

* ___Easy to install and extend___ -
  The main design principle for Convos is to keep simple things simple, and
  optionally support complexity. With this in mind, it's incredible simple to
  [download and install Convos](/doc/getting-started.html). No need for external
  servers or complex config files to get up and running. Run one command, and
  you are good to go!

* ___LDAP support___ -
  Got your existing users in a LDAP server? Convos can
  [connect to it](https://github.com/Nordaaker/convos/blob/master/lib/Convos/Plugin/Auth/LDAP.pm#L100),
  meaning you can administrate all your users in one place.

## Copyright & License

Copyright (C) 2012-{{ site.time | date: '%Y' }}, Nordaaker.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

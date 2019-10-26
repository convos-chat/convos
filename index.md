---
layout: page
title: About
---

Convos is the simplest way to use [IRC](http://www.irchelp.org/). It is always
online, and accessible to your web browser, both on desktop and mobile. Run it
on your home server, or [cloud service](https://www.digitalocean.com/) easily.
It can be deployed to Docker-based cloud services, or you can just run it as a
normal [Mojolicious](http://mojolicious.org/) application.

Learn more about how to install and configure Convos in the
[guides](/doc) or just run the two commands below to
[install](/doc/getting-started.html) and start Convos:

<pre class="highlight"><code>$ curl <a href="https://github.com/Nordaaker/convos/blob/gh-pages/install.sh">https://convos.by/install.sh</a> | sh -
$ ./convos/script/convos daemon</code></pre>

<a href="/2019/10/26/convos-one-point-oh.html"><img src="/public/screenshots/2019-10-26-conversation.jpg" alt="Picture of Convos conversation"></a>

## Demo

There is an online demo running at [demo.convos.by](http://demo.convos.by).
Register with your email address and try it out. There should be someone
lurking in the `#test` channel.

Note that the demo is [locked](/doc/config.html#convosforcedircserver) to the
IRC server running on localhost. This is to prevent the server from getting
banned from IRC networks with strict limitations.

## Features

### Always online

The backend server will keep you logged in and logs all the activity in your
archive.

### Archive

All chats will be logged and indexed, which allow you to search in earlier
conversations.

### Automatic Previews

Links to images and video will be displayed inline. No need to click on the
link to view the data.

### Notifications

Convos will track whenever you are mentioned in a conversation and display
desktop notifications.

## Design principles

* Keep it easy to install.
* Easy to run - Optional complexity.
* Easy to use for both humans and computers.
* Easy to develop and extend.
* Keep the JS simple and manageable.
* Archive logs in plain text format.

## Authors

* Jan Henning Thorsen - jhthorsen@cpan.org
* Marcus Ramberg - marcus@nordaaker.com

## Copyright & License

Copyright (C) 2012-{{ site.time | date: '%Y' }}, Nordaaker.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

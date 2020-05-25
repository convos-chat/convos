---
layout: post
title: "Convos revamped!"
tag: perl
---

## Introduction

[Convos](/) is a chat application that runs in your browser.
It allows you to be persistently connected to IRC servers, where you can leave
the office and up the conversation on the bus without being disconnected.

Convos was born in June 2012. It has been developed to scratch an itch that
both we had: We wanted to be connected to IRC, but felt that IRSSI running in
screen was quite cumbersome, especially seen from a mobile perspective: We
wanted an web interface that was responsive and therefore fit on any medium we
would carry around.

<!--more-->

We have both been using Convos for a long time, but the project itself lost
traction after we found some non-fixable issues in the backend that are seen
when the load on the server goes up. The issue comes from the lack of error
handling to the database, which I will come back to [later](#mojo-redis-and-mojo-redis2)

Note that even with this issue, we still use Convos on a daily basis. Both for
our personal conversations and at work.

This post is about giving an insight into what went wrong, and what the next
version of Convos will do to fix it.

## Technologies

Convos does its best to use code from CPAN and factor out re-usable code back
to CPAN. This chapter will give an insight into the core techonologies
in Convos:

### Mojo-IRC

Convos supports [IRC](https://en.wikipedia.org/wiki/Internet_Relay_Chat). IRC
is a very old, stable but also flexible protocol. The main reason why we
support IRC is that we wanted to talk with people on [irc.perl.org](http://www.irc.perl.org/)
and [freenode](http://freenode.net), but the protocol and server side is
flexible enough to be extended if you want more functionality on an in-house
IRC server.

[Mojo::IRC](https://metacpan.org/release/Mojo-IRC) started off as a part of
Convos, but we released it to CPAN as soon as we thought it was stable enough.
Since then we have had a numerous of contributors and the module as become
quite mature. The latest addition to the distribution is
[Mojo::IRC::UA](https://metacpan.org/pod/Mojo::IRC::UA), which tries to emulate
state and order on top of the "order less" IRC protocol.

### Mojo-Redis and Mojo-Redis2

The current version of Convos use Mojo::Redis. We selected Redis as our
backend, since we wanted the [pub/sub](http://redis.io/topics/pubsub)
feature. Pub/sub is a mehanism where one client can publish a message and all
the listeners receives the message, without the need for polling.

Mojo::Redis has since then been deprecated, since it did not have any error
handling! I think looking back, we thought that the only error we would see
(because of the nature of Redis) would be disconnects, but once you get high
load on a system (client and/or server), anything can happen - and it did.

We hardly ever notice when running with a few users and low load, so Convos is
still usable, but it was still not the kind of product we wanted to ship.

So I made [Mojo::Redis2](https://metacpan.org/release/Mojo-Redis2). This is
an improved version which will eventually replace the original namespace of
Mojo::Redis. It has proper error handling and also support for blocking
requests.

The work to replace Mojo::Redis started in December last year, but I got
sidetracked since there was too much to deal with. Also, after we received
feedback from users that wanted to try out Convos without a database backend,
we decided that we wanted to make a version of Convos that could work with
just memory or file system as "backend".

The current in-progress branch of Convos does not require Mojo::Redis, nor
Mojo::Redis2, just a file system or (a lot of) free memory.

### Mojolicious-Plugin-LinkEmbedder

We wanted more than just a plain text interface. After all, we are working
with web technologies, so any link posted should result at least a link or
preferrably rich content.

We decided to create [Mojolicious::Plugin::LinkEmbedder](https://metacpan.org/release/Mojolicious-Plugin-LinkEmbedder).
This module can take an URL, and extend it into into metadata. In some cases it's
enough to just look at the URL, but in other cases the URL need to be followed
and the content must be parsed. Either way, if the LinkEmbedder has a module
for parsing the URL, it will result in a richer experience.

The current version of LinkEmbedder has support for Imgur, XKCD, Spotify,
Travis, Twitter, Appear In, a bunch of pastebins and many of the most used
video services. There are [open issues](https://github.com/jhthorsen/mojolicious-plugin-linkembedder/issues)
for support for more services, but the sky is really the limit for what to
support.

### Mojolicious-Plugin-Riotjs

The current version of Convos renders all the HTML on the server side. The
decision was made based on the fact that Marcus and I are a whole lot better
at testing Perl code, than HTML/JavaScript code. We also didn't want to
have to keep the server side templates and JavaScript templates in sync, which
this approach handles.

The next version of Convos on the other hand uses [riotjs](http://riotjs.com)
to render the HTML, which makes Convos a pure JavaScript application. This
will enable us to focus on a pure [REST](#swagger2_and_json-validator)
API on the server side.

[Mojolicious::Plugin::Riotjs](https://metacpan.org/pod/Mojolicious::Plugin::Riotjs)
is a [Mojolicious](http://mojolicio.us/) plugin which will compile Riotjs
".tag" files to JavaScript.

### Swagger2

The next version of Convos is focused around the API.
[Swagger2](http://thorsen.pm/perl/programming/2015/07/05/mojolicious-swagger2.html)
is "The World’s Most Popular Framework for APIs". We use this framework in
Convos to document and define the API resources.

This should make it very easy for anyone else to make competing frontends to
the Riotjs based frontend shipped with Convos. This could span from an iOS app
to integration with IRSSI.

### Materialize

The next version of Convos will use the design principles from Google's
Material design, implemented in the [Materialize](http://materializecss.com/)
project. We decided that instead of rolling our own CSS, we should try to
stand on someone else's shoulders to avoid wasting too much time on design
decisions. And besides: Material design looks very good!

## Internals in "Convos revamped"

The next version of Convos is completely redesigned. It's supposed to be
easier to follow the logic, the objects should have a clean separation between
"backend storage" and Perl space, and the API should support hooks provided by
third party plugins.

The working draft can be seen in the [batcode](https://github.com/Nordaaker/convos/tree/batcode)
branch.

### One process

The current version has a single process running the backend, while the frontend
can be started as a
[daemon](https://metacpan.org/pod/Mojolicious::Command::daemon) or under
[hypnotoad](https://metacpan.org/pod/distribution/Mojolicious/script/hypnotoad)

The next version will ultimately be able to be started with a command like
this:

    $ curl https://convos.chat/code-1.0 | perl - daemon

Even if Convos doesn't reach that point, it will run as a single process
- both the backend and frontend.

### Convos.pm

The heart of Convos is "Convos.pm". This package is a
[Mojolicious](https://metacpan.org/pod/Mojolicious) application that glue
together "Convos::Core" (the backend) and the frontend REST API. It also serve
the Riotjs based JavaScript application.

The application has embedded the code from [Mojolicious::Plugin::RequestBase](https://metacpan.org/pod/Mojolicious::Plugin::RequestBase),
which makes it easy to run behind a reverse proxy.

### Convos::Controller

The controller classes holds just enough logic to pass data from the Swagger
based REST API, to "Convos::Core".

There are currently three controllers defined: "User" handles login, register
profile data and deletion of an account. "Connection" handles add/remove
connections to chat servers and joining/parting conversations. "Chat" handles
actions related to a single conversation and should be able to stream messages
in the future.

### Convos::Core

This is the heart of Convos. The core takes care of connections,
conversations, can persist to a backend and provide hooks for plugins.

The core structure is as following:


                  .---------.
              ____| Backend |
    .------._/    '---------'
    | Core |
    '------'   .------.   .-------------.   .---------------.
        \______| User |___| Connections |___| Conversations |
               '------'   '-------------'   '---------------'

This means that Convos is a multi user application, that can persist
to any backend (memory, file storage, redis, ...) and connect to any chat
server, as well as have keeping any number of conversations active.

The way the "Backend" is hooked into the rest of the object graph is by
[events](https://metacpan.org/pod/Mojo::EventEmitter). Any user, connection or
conversation can emit new events that the Backend can choose to persist to
storage. The default backend is a file-based backend, which enables Convos to
be started without any additional dependencies, except Perl and a couple of
modules from CPAN.

The important thing when designing these events is to not think about what
kind of "Backend" you have.

## Status of the revamped version

The current [batcode](https://github.com/Nordaaker/convos/tree/batcode) branch
has a lot of the REST resources defined, implemented and tested, but there is
still missing features such as no way to log out and no way to send/stream
messages. The bottleneck now is however the frontend. We currently have no
tests for the Riotjs code and the user interface is in best case infantile.

I think the next version of Convos has a structure that is quite simple to
follow. The idea behind using events, instead of a third party database makes
the separation of concerns clearer.

Got questions, feedback, want to contribute or just see what's going on with
the project? Follow [Convos](http://twitter.com/convosby) on Twitter or
join the IRC channel #convos on irc.freenode.net.

---
title: Developement guide
toc: true
---

## Overview

This guide is for people who want to hack on Convos.

Not familiar with Perl? That's fine: [Half of Convos](/doc#statistics) is
JavaScript and CSS, so you can modify the frontend using web knowledge.
It is however helpful if you are familiar with [git](http://git-scm.com),
[Mojolicious](http://mojolicious.org) and basic [Perl](http://perl.org) tools,
such as [prove](https://metacpan.org/pod/distribution/TAP-Parser/bin/prove)
and [cpanm](https://metacpan.org/pod/distribution/App-cpanminus/bin/cpanm).

The JavaScript is compiled using [rollupjs](https://rollupjs.org/) and the
JavaScript dependency tree is maintained using [pnpm](https://pnpm.js.org/).

## Getting the source code

The first step is to clone the Convos repository. You can either do this
directly on [github](https://github.com/nordaaker/convos) or by running the
command below:

    git clone https://github.com/nordaaker/convos.git

The command above will create a "convos" directory in the current working
directory. The following steps need to be run from the project root, meaning
you should `cd ./convos` first.

## Installing dependencies

Once you have the source code you should install the dependencies:

    pnpm i
    ./script/convos install --develop

[pnpm](https://pnpm.js.org/) is used to install all the JavaScript dependencies.
You could use "npm" instead, but "pnpm" is highly recommended.

`--develop` will install dependencies which is only required if you want to
make changes to the files in the `assets/` directory. Note that the
dependencies are installed in `local/lib/`. If you want to install them
globally or in your `$HOME/perl5` directy, then use one of these command
instead:

    ./script/cpanm --installdeps --sudo .
    ./script/cpanm --installdeps .

## Installing an IRC daemon

It is highly suggested that you install an IRC daemon, since many networks
will ban you if you reconnect too often. Any IRC compatible server will work,
but [ircd](http://www.ircd-hybrid.org) is a good alternative:

    sudo apt-get install ircd-hybrid # ubuntu
    brew install ircd-hybrid         # osx

Please ask in [#convos on freenode.net](irc://chat.freenode.net/%23convos) if
you want to use the [demo](/#instant-demo) IRC server instead of installing your own.

## Starting the application

The basics of getting the application running in development mode is the
command below:

    ./script/convos dev

The command above is the same as:

    CONVOS_DEBUG=1 script/convos webpack \
      -w lib -w public/convos-api.json -w templates

`CONVOS_DEBUG` will print extra low level debug information to STDERR, which is
useful to discover bugs. The `-w` switch is for watching different files and
directories for changes and reload the web server automatically.

## Secure connection

Running `convos dev` will automatically pick up any certificated files in the
root of your project. This can be useful if you want to work on some features
that require "https". A self-signed certificate is often not enough, so we
suggest using [mkcert](https://github.com/FiloSottile/mkcert) to set up local
development certificates.

After you have installed `mkcert` you can simply run the following commands to
get a secure connection:

    mkcert localhost
    ./script/convos dev

The default address for the secure server will be
[https://localhost:3443/](localhost:3443/), but you can change that:

    ./script/convos dev --listen https://localhost:8443

## Building production assets

The command below will create production assets, which will be used when you
start the [production](/doc/start#git-clone) version of Convos:

    ./script/convos build

## Directory structure

* ./assets/

  The [assets](https://github.com/nordaaker/convos/tree/master/assets)
  directory contains all JavaScript and Sass files, which will be used to
  generate the public files. The conversion is done with
  [Mojolicious::Plugin::Webpack](/doc/Mojolicious/Plugin/Webpack).

* ./cpanfile

  The [cpanfile](https://github.com/nordaaker/convos/blob/master/cpanfile) is
  used to document all the requirements, while the `Makefile.PL` file is
  generated from the content of the cpanfile.

* ./lib/

  The [lib](https://github.com/nordaaker/convos/tree/master/lib) directory
  contains all the Perl source code.

* ./public

  The [public](https://github.com/nordaaker/convos/tree/master/public)
  directory contains fonts and images  which can be downloaded through the
  Convos web server.

* ./script

  The [script](https://github.com/nordaaker/convos/tree/master/script)
  directory contains the main application file
  ([convos](https://github.com/nordaaker/convos/blob/master/script/convos))
  and helper scripts.  The important part here is that every file which has
  the executable bit set will be part of the final CPAN distribution.

* ./t

  The [t](https://github.com/nordaaker/convos/tree/master/t) directory
  contains test files for the Perl code.

* ./\_\_tests__

  The [__tests__](https://github.com/nordaaker/convos/tree/master/__tests__)
  directory contains test files for the JavaScript code.

## Convos frontend

                    .------.
                ____| Core |
    .--------._/    '------'
    | Convos |
    '--------'    .-------------.
          \_______| Controllers |
                  '-------------'

The frontend contains of a single template. The rest of the frontend consist of
a JavaScript application, powered by [Svelte](http://svelte.dev). This
application gets its data from a [OpenAPI powered JSON API](/api.html powered)
with a thin logical layer inside the controllers:

* [Convos::Controller::Connection](/doc/Convos/Controller/Connection)
* [Convos::Controller::Conversation](/doc/Convos/Controller/Conversation)
* [Convos::Controller::Events](/doc/Convos/Controller/Events)
* [Convos::Controller::Notifications](/doc/Convos/Controller/Notifications)
* [Convos::Controller::User](/doc/Convos/Controller/User)

The main layout for the Svelte powered frontend is
[/assets/App.svelte](https://github.com/Nordaaker/convos/blob/master/assets/App.svelte)
and the routes are set up in
[/assets/routes.js](https://github.com/Nordaaker/convos/blob/master/assets/routes.js).

## Convos core

                 .---------.
              ___| Backend |
    .------._/   '---------'
    | Core |
    '------   .------.  .-------------.  .--------------.
        \_____| User |__| Connections |__| Conversation |
              '------'  '-------------'  '--------------'

[Convos::Core](/doc/Convos/Core)
is the heart of Convos. The core takes care of connections, conversations can
persist to a backend and provide hooks for plugins.

The design makes Convos a multi-user application, that can persist to any
backend (memory, file storage, redis, ...) and connect to any chat server,
as well as keeping any number of conversations active.

The way the [backend](/doc/Convos/Core/Backend)
is hooked into the rest of the object graph is by events. Any user, connection
or conversation can emit new events that the Backend can choose to persist to
storage. The default backend is a file-based backend, which enables Convos to
be started without any external database.

## API

Convos has an OpenAPI powered REST API. The specification is used to both
generate Perl code for validation, and to generate documentation. Resources:

* [Documentation](/api.html)
* [Specification](https://github.com/nordaaker/convos/blob/master/public/convos-api.json)
* [OpenAPI](https://www.openapis.org/)
* [Mojolicious::Plugin::OpenAPI](/doc/Mojolicious/Plugin/OpenAPI)

TODO: Need to document the WebSocket API as well.

## Contribute

Any contribution is more than welcome! Examples: If you find typos on this web
page or find something annoying, then please [tell us](/doc/#get-in-touch).

We welcome [pull requests](https://github.com/nordaaker/convos/pulls), but any
form of patches are better than nothing. The pull request does not need to be
complete either, but it is more likely to get merged if it includes tests and
documentation updates.

Check out [the issues](https://github.com/nordaaker/convos/issues) for open
issues. Some of the issues are put into planned
[milestones](https://github.com/Nordaaker/convos/milestones), but any of the
[backlog](https://github.com/Nordaaker/convos/milestone/7) issues are for grabs
at any time.

---
layout: page
title: Developing
---

<ul class="toc"></ul>

## Overview

This guide is for people who want to hack on Convos.

## API

Convos has an OpenAPI powered REST API. The specification is used to both
generate perl code for validation, and to generate documentation. Resources:

* [Documentation](http://demo.convos.by/api.html)
* [Specification](https://github.com/nordaaker/convos/blob/master/public/convos-api.json)
* [OpenAPI](https://www.openapis.org/)
* [Mojolicious::Plugin::OpenAPI](https://metacpan.org/pod/Mojolicious::Plugin::OpenAPI)

TODO: Need to document the WebSocket API as well.

## Tutorial

It is helpful if you are familiar with [git](http://git-scm.com).
[Mojolicious](http://mojolicious.org) and basic [Perl](http://perl.org) tools,
such as [prove](https://metacpan.org/pod/distribution/TAP-Parser/bin/prove)
and [cpanm](https://metacpan.org/pod/distribution/App-cpanminus/bin/cpanm).

The JavaScript is compiled using [rollupjs](https://rollupjs.org/) and the
JavaScript dependency tree is maintained using [pnpm](https://pnpm.js.org/).

### Getting the source code

The first step is to clone the Convos repository. You can either do this
directly on [github](https://github.com/nordaaker/convos) or by running the
command below:

```bash
$ git clone https://github.com/nordaaker/convos.git
```

The command above will create a "convos" directory in the current working
directory. The following steps need to be run from the project root, meaning
you should `cd ./convos` first.

### Installing dependencies

Once you have the source code you should install the dependencies:

```bash
$ pnpm i
$ script/convos install --develop
```

[pnpm](https://pnpm.js.org/) is used to install all the JavaScript dependencies.
You could use "npm" instead, but "pnpm" is highly recommended.

`--develop` will install dependencies which is only required if you want to
make changes to the files in the `assets/` directory. Note that the
dependencies are installed in `local/lib/`. If you want to install them
globally or in your `$HOME/perl5` directy, then use one of these command
instead:

```
$ perl ./script/cpanm --installdeps --sudo .
$ perl ./script/cpanm --installdeps .
```

### Installing an IRC daemon

It is highly suggested that you install an IRC daemon, since many networks
will ban you if you reconnect too often. Any IRC compatible server will work,
but [ircd](http://www.ircd-hybrid.org) is a good alternative:

```bash
$ sudo apt-get install ircd-hybrid # ubuntu
$ brew install ircd-hybrid         # osx
```

Please ask in [#convos on freenode.net](irc://chat.freenode.net/#convos) if
you want to use the [demo](/#demo) IRC server instead of installing your own.

### Starting the application

The basics of getting the application running in development mode is the
command below:

```bash
$ ./script/convos dev
```

The command above is the same as:

```bash
$ MOJO_IRC_DEBUG=1 CONVOS_DEBUG=1 morbo script/convos \
    -w assets -w lib -w public/convos-api.json
```

`MOJO_IRC_DEBUG` and `CONVOS_DEBUG` will print extra low level debug
information to STDERR, which is useful to discover bugs. The `-w` switch is
for watching different files and directories for changes and reload
[morbo](https://metacpan.org/pod/Mojo::Server::Morbo) automatically.

### Directory structure

* ./assets/

  The [assets](https://github.com/nordaaker/convos/tree/master/assets)
  directory contains all JavaScript and Sass files, which will be used to
  generate the public files. The convertion is done with
  [Webpack](https://metacpan.org/pod/Mojolicious::Plugin::Webpack).

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
  contains the test files for the Perl code.

  TODO: Add JavaScript tests.

### Convos frontend

                    .------.
                ____| Core |
    .--------._/    '------'
    | Convos |
    '--------'    .-------------.
          \_______| Controllers |
                  '-------------'

The frontend contains of a single template, embedded inside of
[Convos.pm](https://github.com/nordaaker/convos/blob/master/lib/Convos.pm) The
rest of the frontend consist of a JavaScript application, powered by
[Svelte](http://svelte.dev). This application gets its data from a OpenAPI
powered JSON API with a thin logical layer inside the controllers:

* [Convos::Controller::Connection](https://github.com/nordaaker/convos/blob/master/lib/Convos/Controller/Connection.pm)
* [Convos::Controller::Dialog](https://github.com/nordaaker/convos/blob/master/lib/Convos/Controller/Dialog.pm)
* [Convos::Controller::Events](https://github.com/nordaaker/convos/blob/master/lib/Convos/Controller/Events.pm)
* [Convos::Controller::Notifications](https://github.com/nordaaker/convos/blob/master/lib/Convos/Controller/Notifications.pm)
* [Convos::Controller::User](https://github.com/nordaaker/convos/blob/master/lib/Convos/Controller/User.pm)

### Convos core

                 .---------.
              ___| Backend |
    .------._/   '---------'
    | Core |
    '------   .------.  .-------------.  .---------.
        \_____| User |__| Connections |__| Dialogs |
              '------'  '-------------'  '---------'

[Convos::Core](https://github.com/nordaaker/convos/blob/master/lib/Convos/Core.pm)
is the heart of Convos. The core takes care of connections, dialogs can
persist to a backend and provide hooks for plugins.

The design makes Convos a multi-user application, that can persist to any
backend (memory, file storage, redis, ...) and connect to any chat server,
as well as keeping any number of dialogs active.

The way the [backend](https://github.com/nordaaker/convos/blob/master/lib/Convos/Core/Backend.pm)
is hooked into the rest of the object graph is by events. Any user, connection
or dialog can emit new events that the Backend can choose to persist to
storage. The default backend is a file-based backend, which enables Convos to
be started without any external database.

## Contribute

Any contribution is more than welcome! Examples: If you find typos on this web
page or find something annoying, then please [tell us](/doc/#get-in-touch).

We welcome [pull requests](https://github.com/nordaaker/convos/pulls), but any
form of patches are better than nothing. The pull request does not need to be
complete either, but it is more likely to get merged if it includes tests and
documentation updates.

### Ideas

Check out [the issues](https://github.com/nordaaker/convos/issues) for open
issues. Below is a list of additional ideas:

* User defined avatars.

* Support for arrow up/down in "user input field" for historical commands.

* Support file (image, text, ...) upload.

* Kiosk mode, meaning Convos can act as a support chat on a web page.

* Loopback connection for self hosting Convos, without an IRC backend.

---
layout: sub
title: Developing
---

## Overview

This guide is for people who want to hack on Convos. You can also have a
look at [convos-revamped](http://thorsen.pm/perl/2015/08/31/convos-revamped.html)
for more details.

The complete manual for Convos and its dependencies are available
from inside the application at http://localhost:3000/perldoc.

## Tuturial

It is helpful if you are familiar with [git](http://git-scm.com).
Mojolicious and basic [Perl](http://perl.org) tools, such as
__prove__ and __cpanm__.

### Getting the source code

The first step is to clone the repository. You can either do this directly
in [github](https://github.com/Nordaaker/convos) or by running the command
below:

    $ git clone https://github.com/Nordaaker/convos.git

The command above will create a "convos" directory in the current working
directory. The following steps need to be run from the project root, meaning
inside the "convos" directory.

### Installing dependencies

Once you have the source code you should install the dependencies:

    $ script/convos install --develop

--develop will also install dependencies which is only required if you
want to make changes to the files in the assets/ directory.

### Installing an IRC daemon

It is highly suggested that you install an IRC daemon, since many networks
will ban you if you reconnect to often. Any IRC compatible server will work,
but [ircd](http://www.ircd-hybrid.org) is a good alternative:

    $ sudo apt-get install ircd-hybrid # ubuntu
    $ brew install ircd-hybrid         # osx

Please ask in irc://chat.freenode.net/#convos if you want to use a common
IRC server.

### Starting the application

The basics of getting the application running is the command below:

    $ script/convos dev

The command above is the same as:

    $ MOJO_IRC_DEBUG=1 CONVOS_DEBUG=1 morbo script/convos \
      -w assets/sass -w assets/js -w public/convos-api.json

MOJO_IRC_DEBUG will print IRC debug to STDERR and CONVOS_DEBUG
will print Convos debug to STDERR. The -w switch is for watching
different files and directories for changes.

### Directory structure

* ./assets/

  The "assets" directory contains all JavaScript and Sass files, which will
  be used to generate the "public" files. The dialog is done with
  https://github.com/jhthorsen/mojolicious-plugin-assetpack.

* ./cpanfile

  The cpanfile is used to document all the requirements, while the
  "Makefile.PL" file is generated from the content of the cpanfile.

* ./lib/

  The "lib" directory contains all the Perl source code.

* ./node_modules

  The node_modules/ directory will be generated when installing modules
  with the "npm" command. This directory is ignored by git.

* ./public

  The public directory contains fonts and images  which can be downloaded through
  the Convos web server.

* ./script

  The script directory contains the main application file ("convos") and
  helper scripts. The important part here is that every file which has the
  executable bit set will be part of the final CPAN distribution.

* ./t

  This directory contains the test files for the Perl code.

  TODO: Add JavaScript tests.

### Convos frontend

                    .------.
                ____| Core |
    .--------._/    '------'
    | Convos |
    '--------'    .-------------.
          \_______| Controllers |
                  '-------------'

The frontend contains of a single template, embedded inside of Convos.pm.
The rest of the frontend consist of a JavaScript application, powered by
http://vuejs.org. This application gets its data from a Swagger2
API with a thin logical layer inside the controllers
Convos::Controller::Connection,
Convos::Controller::Dialog,
Convos::Controller::Events,
Convos::Controller::Notifications and
Convos::Controller::User.

### Convos core

                .---------.
              ____| Backend |
    .------._/    '---------'
    | Core |
    '------'   .------.   .-------------.   .---------.
        \______| User |___| Connections |___| Dialogs |
              '------'   '-------------'   '---------'

Convos::Core is the heart of Convos. The core takes care of connections,
dialogs can persist to a backend and provide hooks for plugins.

The design makes Convos a multi-user application, that can persist to any
backend (memory, file storage, redis, ...) and connect to any chat server,
as well as keeping any number of dialogs active.

The way the "Backend" is hooked into the rest of the object graph is by
events. Any user, connection or dialog can emit new events that the
Backend can choose to persist to storage. The default backend is a
file-based backend, which enables Convos to be started without any additional
dependencies, except Perl and a couple of modules from CPAN.

### Contribute

First you need to identify which part you want to contribute to. The current
"master" branch is in beta stage. form The API is pretty usable and
tested, and the frontend is pretty good.

We welcome pull requests on https://github.com/Nordaaker/convos/pulls.

## TODO

Here is a list of features that need to be implemented before "batware" can
be tested.

### Backends

* File backend

  Convos::Core::Backend::File is starting to take form: It can log messages.

  Need to also log join/parted/quit events.

  Need to track notifications.

* Redis backend

  Should to have a Mojo::Redis2 based backend, compatible with the old
  database.

### Connections

* IRC

  Better tests.

  Listen to more relevant IRC events.

  Nickserv password.

  On connect commands.

  Server password.

### Frontends

* Swagger based API

  Convos::Guides::API need to be reviewed.

* Websocket / event stream API

  More events from Mojo::Core::Backend need to be streamed to the frontend.

* Vuejs based user interface

  Emit desktop notifications on mentions.

  Implement "search/goto anything".

  Show notifications.

  Sort dialogs by name/last used/...?

  Add support for showing user defined avatar.

  Add support for arrow up/down in "user input field" for historical commands.

  Change appearance on small screens/phones.

  Proper styling/embedding of "pastebin links".

  Shortcuts for jumping between "user input" and "sidebars".

### Misc

* Add support for embedded pastebin. (Triggered by multi line user input)

* Add support for file (image, text, ...) upload.

* Add support for emoji icons/selector, based on unicode.

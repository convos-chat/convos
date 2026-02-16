---
title: Developement guide
toc: true
---

## Overview

This guide is for people who want to hack on Convos.

Not familiar with Go? That's fine: [Half of Convos](/doc#statistics) is
JavaScript and CSS, so you can modify the frontend using web knowledge.
It is however helpful if you are familiar with [git](http://git-scm.com)
and basic [Go](https://go.dev/) tooling.

The JavaScript is compiled using [rollupjs](https://rollupjs.org/) and the
JavaScript dependency tree is maintained using [pnpm](https://pnpm.io).

To rebuild the frontend with your changes, just do [task](https://github.com/go-task/task) build.

## Getting the source code

The first step is to clone the Convos repository. You can either do this
directly on [github](https://github.com/convos-chat/convos) or by running the
command below:

    git clone https://github.com/convos-chat/convos.git

The command above will create a "convos" directory in the current working
directory. The following steps need to be run from the project root, meaning
you should `cd ./convos` first.

## Installing dependencies

Once you have the source code you should install the dependencies:

    task build

This will build both the frontend assets (using [pnpm](https://pnpm.io)) and
the Go binary. You will need [Go](https://go.dev/dl/),
[Node.js](https://nodejs.org/), and [pnpm](https://pnpm.io) installed.

## Installing an IRC daemon

It is highly suggested that you install an IRC daemon, since many networks will
ban you if you reconnect too often. Any IRC compatible server will work, but
[ergo](https://github.com/ergochat/ergo) is a modern and very simple IRC server
to install.

Please ask in [#convos on irc.libera.chat:6697](https://libera.chat/) if
you want to use the [demo](/#instant-demo) IRC server instead of installing your own.

## Starting the application

The basics of getting the application running in development mode is the
command below:

    CONVOS_MODE=development ./convos daemon

Development mode will print extra low level debug information to STDERR, which is
useful to discover bugs. 

## Running tests

Convos has [GitHub workflows](https://github.com/convos-chat/convos/actions) set
up to run automatic tests when pushing a commit. These tests can also be run
locally:

    # Run all Go tests (API, Core, …)
    task test

    See the go test command for more information on running individual tests.

    # Run all JavaScript tests
    pnpm run test

    # Run a single test and watch for changes. Useful when developing
    npm run test -- --watch __tests__/md.js

## Secure connection

Convos can serve HTTPS using TLS certificates. This can be useful if you want
to work on features that require "https". A self-signed certificate is often
not enough, so we suggest using [mkcert](https://github.com/FiloSottile/mkcert)
to set up local development certificates.

After you have installed `mkcert` you can simply run the following commands to
get a secure connection:

    mkcert localhost
    CONVOS_MODE=development ./convos daemon --listen https://localhost:3443

## Building production assets

The command below will create production assets, which will be used when you
start the [production](/doc/start#git-clone) version of Convos:

    task build

## Directory structure

* ./assets/

  The [assets](https://github.com/convos-chat/convos/tree/main/assets)
  directory contains all JavaScript and Sass files, which will be used to
  generate the public files. The conversion is done with
  [rollupjs](https://rollupjs.org/).

* ./convos.go

  The main entrypoint for the application. Build this using `go build .`

* ./pkg/

  All the internal go packages for convos, like IRC connection and Auth 
  modules and storage backend.

* ./public

  The [public](https://github.com/convos-chat/convos/tree/main/public)
  directory contains fonts and images  which can be downloaded through the
  Convos web server.


* ./\_\_tests__

  The [__tests__](https://github.com/convos-chat/convos/tree/main/__tests__)
  directory contains test files for the JavaScript code.

## Convos frontend

                    .------.
                ____| Core |
    .--------._/    '------'
    | Convos |
    '--------'    .-------------.
          \_______| Handlers    |
                  '-------------'

The frontend consists of a JavaScript application powered by
[Svelte](http://svelte.dev). This application gets its data from an
[OpenAPI powered JSON API](/api.html) with HTTP handlers defined in `pkg/handler/`.

The main layout for the Svelte powered frontend is
[/assets/App.svelte](https://github.com/convos-chat/convos/blob/main/assets/App.svelte)
and the routes are set up in
[/assets/routes.js](https://github.com/convos-chat/convos/blob/main/assets/routes.js).

## Convos core

                 .---------.
              ___| Backend |
    .------._/   '---------'
    | Core |
    '------   .------.  .-------------.  .--------------.
        \_____| User |__| Connections |__| Conversation |
              '------'  '-------------'  '--------------'

The `pkg/core` package is the heart of Convos. The core takes care of
connections, conversations, and persistence.

The design makes Convos a multi-user application that can connect to any IRC
server and keep any number of conversations active. The default backend is a
file-based backend (in `pkg/storage/`), which enables Convos to be started
without any external database.

## API

Convos has an OpenAPI powered REST API. The specification is used to generate
Go server code (via [oapi-codegen](https://github.com/oapi-codegen/oapi-codegen))
and documentation. Resources:

* [Documentation](/api.html)
* [Specification](https://github.com/convos-chat/convos/blob/main/pkg/api/convos-api3.yaml)
* [OpenAPI](https://www.openapis.org/)

TODO: Need to document the WebSocket API as well.

## Contribute

Any contribution is more than welcome! Examples: If you find typos on this web
page or find something annoying, then please [tell us](/doc/#get-in-touch).

We welcome [pull requests](https://github.com/convos-chat/convos/pulls), but any
form of patches are better than nothing. The pull request does not need to be
complete either, but it is more likely to get merged if it includes tests and
documentation updates.

Check out [the issues](https://github.com/convos-chat/convos/issues) for open
issues. Some of the issues are put into planned
[milestones](https://github.com/convos-chat/convos/milestones), but any of the
[backlog](https://github.com/convos-chat/convos/milestone/7) issues are for grabs
at any time.

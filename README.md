# Convos - Multiuser chat application

Convos is a multiuser chat application that runs in your web browser.

The supported chat protocol is currently IRC, but Convos can be extended to
support other protocols as well.

See [convos.by](http://convos.by) for more details.

The backend is powered by [Mojolicious](http://mojolicious.org), while the
frontend is held together by the progressive JavaScript framework
[Vue](https://vuejs.org/).

# Quick start guide

## Snap Install

Install Convos in seconds on [Ubuntu and other snap supported Linux distributions](https://snapcraft.io/docs/core/install) with:

    snap install convos

Installing a snap is very quick. Snaps are secure. They are isolated with all of their dependencies. Snaps also auto update when a new version is released.

## Shell Install

```bash
curl https://convos.by/install.sh | sh -
./convos/script/convos daemon;
```

## Start the daemon

That's it! After the two commands above, you can point your browser to
[http://localhost:3000](http://localhost:3000) and start chatting.

## Invitation code

Note that to register, you need a invitation code. This code is printed to
screen as you start convos:

    [Sun Aug 21 11:18:03 2016] [info] Generated CONVOS_INVITE_CODE="b34b0ab873e80419b9a2170de8ca8190"

# Other deployment strategies

- [Docker](https://hub.docker.com/r/nordaaker/convos/)
- [Snappy](https://uappexplorer.com/app/convos.jhthorsen)
- [![Heroku](https://www.herokucdn.com/deploy/button.png)](https://heroku.com/deploy)

Note! "Heroku" should be deployed from the
[stable](https://github.com/Nordaaker/convos/tree/stable) branch.

# Branch overview

## stable

"[stable](https://github.com/Nordaaker/convos/tree/stable)" is the branch you
should use, if you want to clone and run Convos, instead of just running the
install command above.

[![Build Status](https://travis-ci.org/Nordaaker/convos.svg?branch=stable)](https://travis-ci.org/Nordaaker/convos)

## master

"[master](https://github.com/Nordaaker/convos/tree/master)" is for developers.
It's mostly stable, but might require extra tools and packages to run.

[![Build Status](https://travis-ci.org/Nordaaker/convos.svg?branch=master)](https://travis-ci.org/Nordaaker/convos)

## gh-pages

"[gh-pages](https://github.com/Nordaaker/convos/tree/gh-pages)" is the source
for [http://convos.by](http://convos.by), which is built with
[github pages](https://pages.github.com/).

## backup/convos-0.8604

[backup/convos-0.8604](https://github.com/Nordaaker/convos/tree/backup/convos-0.8604)
is a snapshot for the first iteration of Convos.

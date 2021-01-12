---
title: Getting started
toc: true
image: /screenshots/2020-06-02-install.png
---

## Quick start guide

This guide will give an introduction on how to install and run Convos. It is
very easy to get started, but you can also tweak many [settings](/doc/config)
to make Convos fit your needs.

The two commands below will download and start Convos:

    curl https://convos.chat/install.sh | sh -
    ./convos/script/convos daemon

That's it! After the commands above, you can point your browser to
[http://localhost:3000](http://localhost:3000) to sign up, and start chatting.

You can invite new users to Convos, by sharing an
[invite link](/blog/2019/11/24/convos-one-point-two).

## Running convos

    ./script/convos daemon --help

The command above will provide more information about command line arguments.
One useful switch is how to specify a listen port and make Convos bind to a
specific address:

    ./script/convos daemon --listen http://127.0.0.1:8080

See also the [configuration guide](/doc/config#listen) for more
`--listen` options or the [FAQ](/doc/faq#can-convos-run-behind-behind-my-favorite-web-server)
for how to run Convos behind your favorite web server.

## Upgrading

Upgrading Convos is as simple as installing it. It is suggested to stop Convos
before fetching the latest version, but either way a restart is required to
load in the new version.

    killall convos
    ./convos/script/convos upgrade
    ./convos/script/convos daemon

See the
[FAQ](/doc/faq#why-doesnt-convos-start-after-i-upgraded-my-system) for
more information.

## Optional modules

There are some optional modules that can be installed to enhance the
experience. The command below will show if the modules are installed
or not:

    ./script/convos version

One very useful addition is [EV](/doc/Mojolicious/lib/Mojolicious/Guides/FAQ.pod#Why-doesnt-Mojolicious-have-any-dependencies),
which makes Convos faster. It can be installed with the command below:

    ./script/convos cpanm EV

## Hypnotoad and Prefork

It is *not* possible to run Convos with hypnotoad nor the prefork server. The
reason for this is that the
[Convos core](https://github.com/Nordaaker/convos/blob/master/lib/Convos/Core.pm)
requires shared memory, which a forked environment contradicts.

You need to run Convos in single process, using the
"[daemon](/doc/Mojo/Server/Daemon)" sub command shown
above.

## Alternative install methods

### Docker

You can use the command below to pull and run convos:

    docker pull nordaaker/convos:stable
    mkdir -p $HOME/convos/data
    docker run -it -p 8080:3000 -v $HOME/convos/data:/data nordaaker/convos:stable

The last command will make Convos available on http://localhost:8080, and
persist data in `$HOME/convos/data`.

For Linux distributions with SELinux Enforcing policy (e.g. CentOS, Fedora or RHEL) append `:z` to volumes:

    -v $HOME/convos/data:/data:z

There are some [alternative tags](https://hub.docker.com/r/nordaaker/convos/tags)
available, but we suggest using the "stable" release.

### Git clone

Git can be used to get full flexibility. The command below will only clone the
[stable](https://github.com/Nordaaker/convos/tree/stable) branch. Omit the
`--single-branch --no-tags` to get everything

    # Get the code and install dependencies
    cd $HOME;
    git clone https://github.com/Nordaaker/convos.git \
      --branch stable --single-branch --no-tags
    cd $HOME/convos;
    ./script/convos install
    
    # Start the server
    ./script/convos daemon
    
    # Update and restart
    git pull origin stable
    kill $(pgrep convos)
    ./script/convos daemon

Using the git repo allows you to make changes and build your own frontend.
See the [developement guide](/doc/develop) for more details.

### Snap Install

Install Convos in seconds on [Ubuntu and other snap supported Linux distributions](https://snapcraft.io/docs/core/install) with:

    snap install convos

Installing a snap is very quick. Snaps are secure. They are isolated with all
of their dependencies. Snaps also auto update when a new version is released.

Check out the official page in the [snap store](https://snapcraft.io/convos)
for more information.

## Next

Want to learn more? Check out the [configuration](/doc/config) guide, the
[FAQ](/doc/faq) or the [documentation index](/doc/).

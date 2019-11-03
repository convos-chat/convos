---
layout: page
title: Getting started
---

<ul class="toc"></ul>

## Quick start guide

This guide will give an introduction on how to install and run Convos. It is
very easy to get started, but you can also tweak many
[settings](./config.html) afterwards to make Convos fit your needs.

The two commands below will download and start Convos:

```bash
curl https://convos.by/install.sh | sh -
./convos/script/convos daemon
```

That's it! After the commands above, you can point your browser to
[http://localhost:3000](http://localhost:3000) and start chatting.

Note that to register, you need a invitation code. This code is printed to
screen as you start convos:

    [Sun Aug 21 11:18:03 2016] [info] Generated CONVOS_INVITE_CODE="b34b0ab873e80419b9a2170de8ca8190"

The invite code can be set to anything you like. Check out the
[configuration](./config.html) guide for more details.

## Running convos

```bash
$ ./script/convos daemon --help
```

The command above will provide more information about command line arguments.
One useful switch is how to specify a listen port and make Convos bind to a
specific address:

```bash
$ ./script/convos daemon --listen http://127.0.0.1:8080
```

See also the [configuration guide](/doc/config.html#listen) for more
`--listen` options or the [FAQ](/doc/faq.html#can-convos-run-behind-behind-my-favorite-web-server)
for how to run Convos behind your favorite web server.

## Upgrading

Upgrading Convos is as simple as installing it. Just need to stop Convos
before fetching the latest version:

    $ killall convos
    $ curl https://convos.by/install.sh | sh -
    $ ./convos/script/convos daemon

See the
[FAQ](/doc/faq.html#why-doesnt-convos-start-after-i-upgraded-my-system) for
more information.

## Optional modules

There are some optional modules that can be installed to enhance the
experience. The command below will show if the modules are installed
or not:

```bash
$ ./script/convos version
```

One very useful addition is [EV](https://metacpan.org/pod/distribution/Mojolicious/lib/Mojolicious/Guides/FAQ.pod#Why-doesnt-Mojolicious-have-any-dependencies),
which makes Convos faster. It can be installed with the command below:

```bash
$ perl ./script/cpanm --sudo EV
```
## Hypnotoad and Prefork

It is *not* possible to run Convos with hypnotoad nor the prefork server. The
reason for this is that the
[Convos core](https://github.com/Nordaaker/convos/blob/master/lib/Convos/Core.pm)
requires shared memory, which a forked environment contradicts.

You need to run Convos in single process, using the
"[daemon](https://metacpan.org/pod/Mojo::Server::Daemon)" sub command shown
above.

## Alternative install methods

### Docker

You can use the command below to pull and run convos:

```bash
docker pull nordaaker/convos:stable

docker run -it -p 8080:3000 \
  -v $HOME/convos/data:/data \
  nordaaker/convos:stable
```

The last command will make Convos available on http://localhost:8080, and
persist data in `$HOME/convos/data`.

There are some [alternative tags](https://hub.docker.com/r/nordaaker/convos/tags)
available, but we suggest using the "stable" release.

### Git clone

Git can be used to get full flexibility. The command below will only clone the
[stable](https://github.com/Nordaaker/convos/tree/stable) branch. Omit the
`--single-branch --no-tags` to get everything

```bash
# Get the code and install dependencies
git clone https://github.com/Nordaaker/convos.git \
  --branch stable --single-branch --no-tags

./convos/script/convos install

# Start the server
./convos/script/convos daemon

# Update and restart
git pull origin stable
kill $(pgrep convos)
./convos/script/convos daemon
```

Using the git repo allows you to make changes and build your own frontend.
See the [developement guide](/doc/develop) for more details.

### Snap Install

IMPORTANT! Snap is currently very outdated, since we have
[problems](https://github.com/Nordaaker/convos/issues/366) building
the latest version.

Install Convos in seconds on [Ubuntu and other snap supported Linux distributions](https://snapcraft.io/docs/core/install) with:

```bash
snap install convos
```

Installing a snap is very quick. Snaps are secure. They are isolated with all of their dependencies. Snaps also auto update when a new version is released.



Alternative install methods are documented in the
[install](/doc/install) guide.

## Next

Want to learn more? Check out the [configuration](/doc/config.html) guide, the
[FAQ](/doc/faq.html) or the [documentation index](/doc/).

# Convos - Multiuser chat application

Convos is a multiuser chat application built with Mojolicious.

It currently support the IRC protocol, but can be extended to support
other protocols as well.

See [convos.by](http://convos.by) for more details.

# Quick start guide

Fetch and extract Convos:

```bash
$ curl -L https://github.com/Nordaaker/convos/archive/master.tar.gz | tar xvz
```

Install dependencies:

```bash
$ cd convos-master
$ ./script/convos install
```

Start Convos by running one of the commands below.

```bash
$ ./script/convos daemon;
$ ./script/convos daemon --listen http://*:3000;
```

And connect a browser to [http://localhost:3000](http://localhost:3000).

[![Build Status](https://travis-ci.org/Nordaaker/convos.svg?branch=one-point-oh)](https://travis-ci.org/Nordaaker/convos)

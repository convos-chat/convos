---
layout: sub
title: Installing
---

This guide will give an introduction on how to run Convos. It is very
easy to get started, but you can also tweak many [settings](./configure.html).

### Quick start guide

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

### Basics

```bash
$ ./script/convos daemon --help
```

The command above will provide more information about command line
arguments. One useful switch is how to specify a listen port:

```bash
$ ./script/convos daemon --listen http://127.0.0.1:5000
```

### Optional modules

There are some optional modules that can be installed to enhance the
experience. The command below will show if the modules are installed
or not:

```bash
$ ./script/convos version
```

One very useful addition is EV, which makes Convos faster. It
can be installed with the command below:

```bash
$ cpanm EV
```

### Hypnotoad and Prefork

It is not possible to run Convos with hypnotoad nor the prefork server. The
reason for this is that Convos::Core requires shared memory, which a forked
environment contradicts.

You need to run Convos in single process, using Mojo::Server::Daemon.

---
layout: page
title: Installing
---

This guide will give an introduction on how to run Convos. It is very
easy to get started, but you can also tweak many [settings](./config.html)
afterwards to make it fit your needs.

The first step is to fetch and extract Convos:

```bash
$ curl -L https://goo.gl/kDpvKZ | tar xvz
$ cd convos-stable/
```

Have a look at the [development](/doc/develop.html) guide if you want to use
`git` instead of `curl`.

Check which dependencies are missing, and install them:

```bash
$ ./script/convos
$ ./script/convos install
```

Start Convos by running one of the commands below.

```bash
$ ./script/convos daemon;
$ ./script/convos daemon --listen http://*:3000;
```

That's it! After the commands above, you can point your browser to
[http://localhost:3000](http://localhost:3000) and start chatting.

Note that to register, you need a invitation code. This code is printed to
screen as you start convos:

    [Sun Aug 21 11:18:03 2016] [info] Generated CONVOS_INVITE_CODE="b34b0ab873e80419b9a2170de8ca8190"

The invite code can be set to anything you like. Check out the
[configuration](./config.html) guide for more details.

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
$ perl script/cpanm --sudo EV
```

## Next

Want to learn more? Check out the [running](/doc/running.html) guide, or the
[documentation index](/doc/).

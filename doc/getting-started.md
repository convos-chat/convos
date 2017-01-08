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

<pre class="highlight"><code>$ curl <a href="https://github.com/Nordaaker/convos/blob/gh-pages/install.sh">https://convos.by/install.sh</a> | sh -
$ ./convos/script/convos daemon</code></pre>

That's it! After the commands above, you can point your browser to
[http://localhost:3000](http://localhost:3000) and start chatting.

Note that to register, you need a invitation code. This code is printed to
screen as you start convos:

    [Sun Aug 21 11:18:03 2016] [info] Generated CONVOS_INVITE_CODE="b34b0ab873e80419b9a2170de8ca8190"

The invite code can be set to anything you like. Check out the
[configuration](./config.html) guide for more details.

Have a look at [this blog post](/2016/12/04/convos-loves-docker.html) if you want to
run Convos inside of Docker.

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
`--listen` options.

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
$ ./script/cpanm --sudo EV
```

## Hypnotoad and Prefork

It is *not* possible to run Convos with hypnotoad nor the prefork server. The
reason for this is that the
[Convos core](https://github.com/Nordaaker/convos/blob/master/lib/Convos/Core.pm)
requires shared memory, which a forked environment contradicts.

You need to run Convos in single process, using the
"[daemon](https://metacpan.org/pod/Mojo::Server::Daemon)" sub command shown
above.

## Next

Want to learn more? Check out the [configuration](/doc/config.html) guide, the
[FAQ](/doc/faq.html) or the [documentation index](/doc/).

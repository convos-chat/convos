---
layout: page
title: Installing
---

This guide will give an introduction on how to install and run Convos. It is
very easy to get started, but you can also tweak many
[settings](./config.html) afterwards to make Convos fit your needs.

The two commands below will download and start Convos:

```bash
curl https://convos.by/install.sh | sh -
./convos/script/convos daemon;
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
./script/convos version
```

One very useful addition is [EV](https://metacpan.org/pod/distribution/Mojolicious/lib/Mojolicious/Guides/FAQ.pod#Why-doesnt-Mojolicious-have-any-dependencies),
which makes Convos faster. It can be installed with the command below:

```bash
perl script/cpanm --sudo EV
```

## Next

Want to learn more? Check out the [running](/doc/running.html) guide, or the
[documentation index](/doc/).

# Convos - Multiuser chat application

Convos is a multiuser chat application built with Mojolicious.

It currently support the IRC protocol, but can be extended to support
other protocols as well.

See [convos.by](http://convos.by) for more details.

# Quick start guide

```bash
curl https://convos.by/install.sh | sh -
./convos/script/convos daemon;
```

That's it! After the two commands above, you can point your browser to
[http://localhost:3000](http://localhost:3000) and start chatting.

Note that to register, you need a invitation code. This code is printed to
screen as you start convos:

    [Sun Aug 21 11:18:03 2016] [info] Generated CONVOS_INVITE_CODE="b34b0ab873e80419b9a2170de8ca8190"

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

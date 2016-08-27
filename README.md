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

[![Build Status](https://travis-ci.org/Nordaaker/convos.svg?branch=one-point-oh)](https://travis-ci.org/Nordaaker/convos)

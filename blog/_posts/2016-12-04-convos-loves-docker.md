---
layout: post
title: Convos loves Docker
---

We now have an official [Docker](https://hub.docker.com/r/nordaaker/convos/)
file for Convos! The image is based on [Alpine 3.5](https://alpinelinux.org/),
making it very small and easy to install. You can get up and running with
these commands:

    # Build
    $ docker build --no-cache --rm -t nordaaker/convos .
    # Run
    $ docker run -it --rm -p 8080:3000 -v /var/convos/data:/data nordaaker/convos

<!--more-->

`8080` is the port where you want Convos to be exposed and `/var/convos/data`
is where you want to store settings and logs on the host machine.

We have plans for other ways to install/run Convos. Have a look at issue
[#285](https://github.com/Nordaaker/convos/issues/285) for more details. We
welcome any help and input on making official Convos packages and easy
"install buttons".

---
layout: page
title: Frequently asked questions
---

<ul class="toc"></ul>

## Can Convos be extended and customized?

Yes. Convos supports plugins, but there have not yet been any plugins
developed. We hope to implement
[#244](https://github.com/Nordaaker/convos/issues/244) and
[#90](https://github.com/Nordaaker/convos/issues/90) as the first core
plugins.

Look at the [configuration](/doc/config.html) guide to see which configuration
parameters that have to be set to load a plugin.

## Can Convos run behind behind my favorite web server?

Yes, but it needs some addition configuration to understand how to behave.

There are two things you need to do if you want to run Convos behind a reverse
proxy, such as Apache or nginx:

The first thing is that
[MOJO_REVERSE_PROXY](/doc/config.html#MOJO_REVERSE_PROXY) must be set to a
true value.

The other thing is that the reverse proxy need to pass on some HTTP headers
to Mojolicious/Convos to instruct it into behaving correctly. Below are
links to cookbooks for setting up the reverse web server:

* [nginx](http://mojolicious.org/perldoc/Mojolicious/Guides/Cookbook#Nginx)
* [Apache](http://mojolicious.org/perldoc/Mojolicious/Guides/Cookbook#Apache-mod_proxy)

To sum up, the important things are:

* "Host" header must be set to the original request's "Host" header.
* "X-Forwarded-Proto" header must be set to either "http" or "https".
* "X-Request-Base" header must be set if your application is not available
  from the root of your domain.
* The web server need to support WebSockets.

Here is a complete example:

Start convos:

    $ MOJO_REVERSE_PROXY=1 ./script/convos daemon --listen http://127.0.0.1:8080

Set up nginx:

    # Host and port where convos is running
    upstream convos { server 127.0.0.1:8080; }

    server {
      listen 80;
      server_name your-domain.com;

      # Mount convos under http://your-domain.com/whatever/convos
      location /whatever/convos {

        # Pass requests on to the upstream defined above
        proxy_pass http://convos;

        # Instruct Convos to do the right thing regarding
        # HTTP and WebSockets
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # Enable Convos to construct correct URLs by passing on custom
        # headers. X-Request-Base is only required if "location" above
        # is not "/".
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Request-Base "$scheme://$host/whatever/convos";
      }
    }

## Why does Convos stop when I close putty/xterm/some terminal?

Convos does not daemonize. It runs in foreground, so if you close a terminal
application, such as putty it will also kill any running instance of Convos.

To prevent this, you can run this command:

    nohup script/convos daemon &

The `&` at the end will send Convos to the background. `nohup` is mostly
optional, but is usually a good idea.

## Why can't Convos do X?

In most of the cases it's either because we haven't thought about it or
haven't had time to implement it yet. It might also be because we do not want
to implement certain features. We do not want Convos to support every weird
feature, since we want both the user experience and code base to be clean.

Please submit an [issue](https://github.com/Nordaaker/convos/issues), come
and talk with us in [#convos](irc://chat.freenode.net:6697/#convos) on
Freeenode or send a tweet to [@convosby](https://twitter.com/convosby).

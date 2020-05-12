---
layout: page
title: Frequently asked questions
---

<ul class="toc"></ul>

## Can Convos run behind behind my favorite web server?

Yes, but Convos and the web server need to be configured properly and
[WebSockets](https://www.websocket.org/) need to be supported through the
chain.

The first thing is that the environment variable
[CONVOS_REVERSE_PROXY](/doc/config.html#CONVOS_REVERSE_PROXY) must be set to a
true value.

The other thing is that the reverse proxy needs to pass on some HTTP headers to
Convos, so correct URLs will be generated. Below are two examples for
setting up Convos behind nginx or Apache. Here are the important headers:

* "Host" header must be set to the original request's "Host" header.
* "X-Forwarded-Proto" header must be set to either "http" or "https".
* "X-Request-Base" header must be set to the root URL for Convos.

Here is a complete example on how to start Convos, and configur either nginx
or Apache:

Start convos behind a reverse proxy:

    $ CONVOS_REVERSE_PROXY=1 ./script/convos daemon --listen http://127.0.0.1:8080

Example nginx config:

    # Host and port where convos is running
    upstream convos { server 127.0.0.1:8080; }

    server {
      listen 80;
      server_name your-domain.com;

      # Mount convos under http://your-domain.com/whatever/convos
      location /whatever/convos {

        # Pass requests on to the upstream defined above
        rewrite ^/whatever/convos/?(.*)$ /$1 break;
        proxy_pass http://convos;

        # Instruct Convos to do the right thing regarding
        # HTTP and WebSockets
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # http://nginx.org/en/docs/http/ngx_http_core_module.html#client_max_body_size
        client_max_body_size 0;

        # Enable Convos to construct correct URLs by passing on custom
        # headers. X-Request-Base is only required if "location" above
        # is not "/".
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Request-Base "$scheme://$host/whatever/convos";
      }
    }

Example Apache config:

    <VirtualHost your-domain.com:80>
      ServerAdmin admin@your-domain.com
      ServerName your-domain.com

      <Proxy *>
        Order allow,deny
        Allow from all
      </Proxy>

      # Enable Convos to construct correct URLs by passing on custom headers.
      ProxyRequests Off
      ProxyPreserveHost On
      RequestHeader set X-Forwarded-Proto "http"
      RequestHeader set X-Request-Base "http://your-domain.com/"

      # https://httpd.apache.org/docs/current/mod/mod_remoteip.html
      RemoteIPHeader X-Forwarded-For

      # http://httpd.apache.org/docs/2.0/mod/core.html#limitrequestbody
      LimitRequestBody 0

      # Pass requests on to Convos
      ProxyPass /events ws://localhost:8080/events
      ProxyPass / http://localhost:8080/ keepalive=On
      ProxyPassReverse / http://localhost:8080/
    </VirtualHost>

## Can Convos be extended and customized?

Yes. Convos supports plugins, but there have not yet been any plugins
developed. We hope to implement
[#244](https://github.com/Nordaaker/convos/issues/244) and
[#90](https://github.com/Nordaaker/convos/issues/90) as the first core
plugins.

Look at the [configuration](/doc/config.html) guide to see which configuration
parameters that have to be set to load a plugin.

## Is Convos supported on my flavor of Linux?

Yes, Convos runs on all flavors of Linux, but Redhat based (Centos, Fedora)
Linux distros might need the extra "perl-core" package to be installed.

## Why does Convos stop when I close putty/xterm/some terminal?

Convos does not daemonize. It runs in foreground, so if you close a terminal
application, such as putty, it will also kill any running instance of Convos.

To prevent this, you can run this command:

    $ nohup script/convos daemon &

The `&` at the end will send Convos to the background. `nohup` is mostly
optional, but is usually a good idea.

## Why doesn't Convos start after I upgraded my system?

You might have gotten a new version of Perl which is not compatible with the
modules you have already installed. To fix this issue, you can try to
re-install Convos:

    # Go to where you downloaded Convos
    cd /path/to/convos/
    # Purge all the installed packages
    rm -rf local/{bin,lib,man}
    # Reinstall packages
    $ perl script/cpanm -n -l $PWD/local Module::Install
    $ ./script/convos install

Please [contact us](/doc/#get-in-touch) if the above instructions do not work.

## Why can't Convos do X?

In most cases it's either because we haven't thought about it or haven't had
time to implement it yet. It might also be because we do not want to implement
certain features. We do not want Convos to support every weird feature, since
we want both the user experience and code base to be clean.

Please submit an [issue](https://github.com/Nordaaker/convos/issues), come
and talk with us in [#convos](irc://chat.freenode.net:6697/#convos) on
Freenode or send a tweet to [@convosby](https://twitter.com/convosby).

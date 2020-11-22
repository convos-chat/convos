---
title: Running Convos behind my favorite web server
toc: true
---

Convos and the web server need to be configured properly and
[WebSockets](https://www.websocket.org/) need to be supported through the whole
chain.

The first thing is that the environment variable
[CONVOS_REVERSE_PROXY](/doc/config#CONVOS_REVERSE_PROXY) must be set to a
true value.

The second thing is that the reverse proxy needs to pass on some HTTP headers
to Convos, so correct URLs will be generated. Below are two examples for
setting up Convos behind nginx or Apache. Here are the important headers:

* "Host" header must be set to the original request's "Host" header.
* "X-Request-Base" header must be set to the root URL for Convos.

Here is a complete example on how to start Convos, and configur either nginx
or Apache:

Start convos behind a reverse proxy:

    CONVOS_REVERSE_PROXY=1 ./script/convos daemon --listen http://127.0.0.1:8080

Example nginx config:

    # Host and port where convos is running
    upstream convos_upstream { server 127.0.0.1:8080; }

    server {
      listen 80;
      server_name your-domain.com;

      # Mount convos under http://your-domain.com/whatever/convos
      # Replace all occurrences of "/whatever/convos" with just "/",
      # and remove the "rewrite" rule if Convos is mounted directly on "/".
      location /whatever/convos {

        # Pass requests on to the upstream defined above
        rewrite ^/whatever/convos/?(.*)$ /$1 break;
        proxy_pass http://convos_upstream;

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
        proxy_set_header X-Request-Base "$scheme://$host/whatever/convos";
      }
    }

Example Apache config:

    &lt;VirtualHost your-domain.com:80>
      ServerAdmin admin@your-domain.com
      ServerName your-domain.com

      &lt;Proxy *>
        Order allow,deny
        Allow from all
      &lt;/Proxy>

      # Enable Convos to construct correct URLs by passing on custom headers.
      ProxyRequests Off
      ProxyPreserveHost On
      RequestHeader set X-Request-Base "http://your-domain.com/"

      # https://httpd.apache.org/docs/current/mod/mod_remoteip.html
      RemoteIPHeader X-Forwarded-For

      # http://httpd.apache.org/docs/2.0/mod/core.html#limitrequestbody
      LimitRequestBody 0

      # Pass requests on to Convos
      ProxyPass /events ws://localhost:8080/events
      ProxyPass / http://localhost:8080/ keepalive=On
      ProxyPassReverse / http://localhost:8080/
    &lt;/VirtualHost>



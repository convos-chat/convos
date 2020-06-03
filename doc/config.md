---
title: Configuration
toc: true
---

## Introduction

Most of the configuration is available from ["Settings"](/blog/2019/11/24/convos-one-point-two)
after you have logged in as an admin user. Even so, there are some settings
that can be tweaked when starting Convos.

    CONVOS_HOME=/var/convos ./script/convos daemon

## Listen

You can make convos listen to a variety of addresses:

    # Listen on all IPv4 interfaces
    ./script/convos daemon --listen http://*:8080

    # Listen on all IPv4 and IPv6 interfaces
    ./script/convos daemon --listen "http://[::]:8000"

    # Listen on a specific IPv4 and IPv6 interface
    ./script/convos daemon \
      --listen "http://127.0.0.1:8080" \
      --listen "http://[::1]:8080"

    # Listen on HTTPS with a default untrusted certificate
    ./script/convos daemon --listen https://*:4000
    
    # Use a custom certificate and key
    ./script/convos daemon --listen \
      "https://*:8000?cert=/path/to/server.crt&key=/path/to/server.key"
    
    # Make convos available behind a reverse proxy
    CONVOS_REVERSE_PROXY=1 ./script/convos daemon \
      --listen http://127.0.0.1:8080

See [CONVOS_REVERSE_PROXY](#mojoreverseproxy) for more details about setting
up Convos behind a reverse proxy.

## Automatic startup with systemd

Here is an example systemd file, that can be placed in
`/etc/systemd/system/convos.service`.

Note that the [Environment](#environment) variables should be review and
changed to suit your needs.

    [Unit]
    Description=Convos service
    After=network.target
    
    [Service]
    Environment=CONVOS_HOME=/var/convos
    Environment=CONVOS_REVERSE_PROXY=1
    User=www
    ExecStart=/path/to/convos/script/convos daemon --listen http://*:8081
    KillMode=process
    Restart=on-failure
    SyslogIdentifier=convos
    
    [Install]
    WantedBy=multi-user.target

After creating the file, you can run the following commands to start the
service:

    systemctl daemon-reload
    systemctl enable convos.service
    systemctl start convos.service
    systemctl status convos.service

Running Convos under systemd without a custom `CONVOS_LOG_FILE` will send all
the log messages to syslog, which normally logs to `/var/log/syslog`.

## Configuration parameters

### CONVOS_BACKEND

Can be set to any class name that inherit from
[Convos::Core::Backend](https://github.com/Nordaaker/convos/blob/master/lib/Convos/Core/Backend.pm).

Default: `Convos::Core::Backend::File`

### CONVOS_CONNECT_DELAY

This variable decides how many seconds to wait between each user to connect
to a chat server. The reason for this setting is that some servers will set
a permanent ban if you "flood connect".

Default: `4`

### CONVOS_DEBUG

Setting this variable to a true value will print extra debug information to
STDERR. Another useful debug variable is `MOJO_IRC_DEBUG` which gives you
IRC level debug information.

### CONVOS_HOME

This variable is used by
[Convos::Core::Backend::File](https://github.com/Nordaaker/convos/blob/master/lib/Convos/Core/Backend/File.pm)
to figure out where to store settings and log files.

See the [FAQ](./faq) for more details.

Default: `$HOME/.local/share/convos/`

However if you are running Convos as a [snap](https://snapcraft.io/convos/), then
`CONVOS_HOME` will be
[SNAP_USER_COMMON](https://snapcraft.io/docs/environment-variables).

Example: `$HOME/snap/convos/common`

### CONVOS_INVITE_LINK_VALID_FOR

This variable is used for invite and password recovery links, and specifies how
many hours the link will be valid for. Not however that when a link is used
(after a new user is registered or changed the password), then link will
instantly become invalid.

Default: `24`.

### CONVOS_LOG_FILE

This value can be used to specify where Convos should write the log messages
to. This settings has no default value which makes Convos write the log to
STDERR.

### CONVOS_MAX_UPLOAD_SIZE

Set this variable to specify the max size in bytes of a file that is uploaded
to Convos. See also the [FAQ](/doc/faq#can-convos-run-behind-behind-my-favorite-web-server),
in case your Convos installation runs behind a reverse proxy.

Default: `40000000` (40MB)

### CONVOS_PLUGINS

A list (comma separated) of Perl modules that can be loaded into the backend
for optional functionality. Example

    CONVOS_PLUGINS=My::Cool::Plugin,My::Upload::Override ./script/convos daemon

### CONVOS_REQUEST_BASE

`CONVOS_REQUEST_BASE` can be used instead of `CONVOS_REVERSE_PROXY` and
the `X-Request-Base` HTTP header set in your [web server config](/doc/faq.html).

Examples:

    CONVOS_REQUEST_BASE=https://convos.example.com/
    CONVOS_REQUEST_BASE=https://example.com/apps/convos

### CONVOS_REVERSE_PROXY

The `CONVOS_REVERSE_PROXY` environment variable must be set to "1" to enable
reverse proxy support. This will then allow Convos to automatically pick up the
`X-Forwarded-For` HTTP headers set in your reverse proxy web server.

Note that setting this environment variable without a reverse proxy in front
will be a security issue.

The [FAQ](/doc/faq#can-convos-run-behind-behind-my-favorite-web-server)
has more details on how to set up Convos behind a reverse proxy server.

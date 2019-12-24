---
layout: page
title: Configuration
---

<ul class="toc"></ul>

## Introduction

Most of the configuration is available from ["Settings"](https://convos.by/2019/11/24/convos-one-point-two.html)
after you have logged in as an admin user. Even so, there are some settings
that can be tweaked when starting Convos.

```bash
$ CONVOS_HOME=/var/convos ./script/convos daemon
```

## Listen

You can make convos listen to a variety of addresses:

```bash
# Listen on all IPv4 interfaces
$ ./script/convos daemon --listen http://*:8080

# Listen on all IPv4 and IPv6 interfaces
$ ./script/convos daemon --listen "http://[::]:8000"

# Listen on a specific IPv4 and IPv6 interface
$ ./script/convos daemon \
  --listen "http://127.0.0.1:8080" \
  --listen "http://[::1]:8080"

# Listen on HTTPS with a default untrusted certificate
$ ./script/convos daemon --listen https://*:4000

# Use a custom certificate and key
$ ./script/convos daemon --listen \
  "https://*:8000?cert=/path/to/server.crt&key=/path/to/server.key"

# Make convos available behind a reverse proxy
$ CONVOS_REVERSE_PROXY=1 ./script/convos daemon \
  --listen http://127.0.0.1:8080
```

See [CONVOS_REVERSE_PROXY](#mojoreverseproxy) for more details about setting
up Convos behind a reverse proxy.

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

Default: `$HOME/.local/share/convos/`

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
to Convos. See also the [FAQ](./faq.html#can-convos-run-behind-behind-my-favorite-web-server),
in case your Convos installation runs behind a reverse proxy.

Default: `40000000` (40MB)

### CONVOS_PLUGINS

A list (comma separated) of perl modules that can be loaded into the backend
for optional functionality. Example

```bash
$ CONVOS_PLUGINS=My::Cool::Plugin,My::Upload::Override ./script/convos daemon
```

### CONVOS_REVERSE_PROXY

The `CONVOS_REVERSE_PROXY` environment variable can be used to enable proxy
support, this allows Mojolicious to automatically pick up the
`X-Forwarded-For` and `X-Forwarded-Proto` HTTP headers.

Note that setting this environment variable without a reverse proxy in front
will be a security issue.

The [FAQ](./faq.html#can-convos-run-behind-behind-my-favorite-web-server)
has more details on how to set up Convos behind a reverse proxy server.

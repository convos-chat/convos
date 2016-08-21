---
layout: page
title: Configuration
---

Convos can be configured with either a config file or environment variables.

Here is a list of all the available settings:

### CONVOS_BACKEND

Can be set to any class name that inherit from
[Convos::Core::Backend](https://github.com/Nordaaker/convos/blob/master/lib/Convos/Core/Backend.pm).

Default: `Convos::Core::Backend::File`

### CONVOS_CONNECT_DELAY

This variable decides how many seconds to wait between each user to connect
to a chat server. The reason for this setting is that some servers will set
a permanent ban if you "flood connect".

Default: `3`

### CONVOS_CONTACT

Used when rendering "Contact" links in the frontend.

Default: `mailto:root@localhost`

### CONVOS_DEBUG

Setting this variable to a true value will print extra debug information to
STDERR. Another useful debug variable is `MOJO_IRC_DEBUG` which gives you
IRC level debug information.

### CONVOS_DEFAULT_SERVER

Used to declare which server should be pre-filled when a user creates a new
connection.

Default: `localhost`

### CONVOS_FORCED_IRC_SERVER

Will force any connection made to use this server. Note that this
environment variable also overrride `CONVOS_DEFAULT_SERVER`.

There is no forced IRC server by default.

### CONVOS_HOME

This variable is used by
[Convos::Core::Backend::File](https://github.com/Nordaaker/convos/blob/master/lib/Convos/Core/Backend/File.pm)
to figure out where to store settings and log files.

Default: `$HOME/.local/share/convos/`

### CONVOS_INVITE_CODE

The value of this setting need to be used by the person who wants to
register. It can be disabled by setting `CONVOS_INVITE_CODE=""`. Check out
the [running](/doc/running.html) guide for more details.

The default value is a semi-random string.

### CONVOS_ORGANIZATION_NAME

Should be set to the name of the organization running this instance of
Convos.

Default: `Nordaaker`

### CONVOS_PLUGINS

A list (comma separated) of perl modules that can be loaded into the backend
for optional functionality.

There are currently no plugins loaded by default.

### CONVOS_SECRETS

Should be set to list (comma separated) of random strings. This value is used
to secure the Cookies written to the client.

The default value is a semi-random secret.

### CONVOS_SECURE_COOKIES

Should be set to true if Convos is served over HTTPS.

### MOJO_CONFIG

Can hold the path to a config file, which is read by Convos instead of using
the environment variables. See also the [running](/doc/running.html) guide
for more details.

### MOJO_REVERSE_PROXY

The `MOJO_REVERSE_PROXY` environment variable can be used to enable proxy
support, this allows Mojolicious to automatically pick up the
`X-Forwarded-For` and `X-Forwarded-Proto` HTTP headers.

See also the [Nginx cookbook](https://metacpan.org/pod/distribution/Mojolicious/lib/Mojolicious/Guides/Cookbook.pod#Nginx)
in the Mojolicious distribution for more information about these headers.

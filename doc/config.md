---
title: Configuration
toc: true
---

## Introduction

Convos wants to have as little configuration as possible, since we believe that
good defaults are much better for the end user. Even so, there things you can
change to set up Convos to behave the way you want.

## Listen

You can make convos listen to a variety of addresses:

    # Listen on all IPv4 interfaces
    ./convos daemon --listen http://*:8080

    # Listen on all IPv4 and IPv6 interfaces
    ./convos daemon --listen "http://[::]:8000"

    # Listen on a specific IPv4 and IPv6 interface
    ./convos daemon \
      --listen "http://127.0.0.1:8080" \
      --listen "http://[::1]:8080"

    # Listen on a UNIX Socket
      ./convos daemon \
      --listen "http+unix://%2Ftmp%2Fmyapp.sock"

    # Listen on HTTPS with a default untrusted certificate
    ./convos daemon --listen https://*:4000

    # Use a custom certificate and key
    ./convos daemon --listen \
      "https://*:8000?cert=/path/to/server.crt&key=/path/to/server.key"

    # Make convos available behind a reverse proxy
    CONVOS_REVERSE_PROXY=1 ./convos daemon \
      --listen http://127.0.0.1:8080

See [`CONVOS_REVERSE_PROXY`](#convos_reverse_proxy) for more details about setting
up Convos behind a reverse proxy.

## Environment variables

The following settings need to be set before starting Convos. New to shell
environment variables? Remember to set them before the "convos" command.

    # Right
    CONVOS_HOME=/var/convos ./convos daemon;
    CONVOS_REVERSE_PROXY=1 ./convos daemon;

    # Wrong
    CONVOS_HOME=/var/convos;
    ./convos daemon;
    ./convos daemon CONVOS_REVERSE_PROXY=1;

The environment variables can also be specified when you run Convos inside
[Docker](https://docs.docker.com/compose/environment-variables/).

Changing an environment variable require Convos to be restarted before they
take effect.

### `CONVOS_BACKEND`

Currently only the file-based backend is supported.

Default: `File`

### `CONVOS_CONNECT_DELAY`

This variable decides how many seconds to wait between each user to connect
to a chat server. The reason for this setting is that some servers will set
a permanent ban if you "flood connect".

Default: `4`

### `CONVOS_DEFAULT_THEME` and `CONVOS_DEFAULT_SCHEME`

These two environment variables can be used to set the default theme for the CMS pages
and new users.

Default: `CONVOS_DEFAULT_THEME=convos CONVOS_DEFAULT_SCHEME=light`

### `CONVOS_HOME`

This variable is used by the file backend to figure out where to store
settings and log files.

See the [FAQ](./faq) for more details.

Default: `$HOME/.local/share/convos/`

However if you are running Convos as a [snap](https://snapcraft.io/convos/), then
`CONVOS_HOME` will be
[`SNAP_USER_COMMON`](https://snapcraft.io/docs/environment-variables).

Example: `$HOME/snap/convos/common`

### `CONVOS_INVITE_LINK_VALID_FOR`

This variable is used for invite and password recovery links, and specifies how
many hours the link will be valid for. Not however that when a link is used
(after a new user is registered or changed the password), then link will
instantly become invalid.

Default: `24`.

### `CONVOS_LOCAL_SECRET`

This variable is used when generating invite links, but also useful for Convos
admins who have forgotten their password. Look at "Forgotten password and
invitation links" in
"[Convos is more user-friendly than ever](https://convos.chat/blog/2019/11/24/convos-one-point-two)"
for more details.

Default value is auto generated and available in the log output when Convos is
started the first time.

### `CONVOS_LOG_FILE`

This value can be used to specify where Convos should write the log messages
to. This settings has no default value which makes Convos write the log to
STDERR.

### `CONVOS_LOG_LEVEL`

This variable can be set to trace, debug, info, warn, error or fatal, and the
number of log lines will increase or decrease accordingly.

NOTE! Setting it to "trace" will most probably also log passwords and other
private information though, but it can be very useful if you have to figure
out what happens on the (IRC) protocol level.

### `CONVOS_MAX_UPLOAD_SIZE`

Set this variable to specify the max size in bytes of a file that is uploaded
to Convos. See also the [FAQ](/doc/faq#can-convos-run-behind-behind-my-favorite-web-server),
in case your Convos installation runs behind a reverse proxy.

Default: `40000000` (40MB)

### `CONVOS_REQUEST_BASE`

`CONVOS_REQUEST_BASE` can be used instead of `CONVOS_REVERSE_PROXY` and
the `X-Request-Base` HTTP header set in your [web server config](/doc/faq.html).

Examples:

    CONVOS_REQUEST_BASE=https://convos.example.com/
    CONVOS_REQUEST_BASE=https://example.com/apps/convos

### `CONVOS_REVERSE_PROXY`

The `CONVOS_REVERSE_PROXY` environment variable must be set to "1" to enable
reverse proxy support. This will then allow Convos to automatically pick up the
`X-Forwarded-For` and `X-Request-Base` HTTP headers set in your
[reverse proxy web server](/doc/reverse-proxy).

Note that setting this environment variable without a reverse proxy in front
will be a security issue.

### `CONVOS_WEBIRC_PASSWORD_NNN`

You can enable the WEBIRC extension by setting an environment variable per
connection name. Example:

1. You have a connection ID "irc-localhost". (Shown as "localhost" in the sidebar)
2. Set the following environment variable to enable WEBIRC:

   CONVOS_WEBIRC_PASSWORD_LOCALHOST=SomeSuperSecretPassword

## Global config settings

The global config settings are available for Convos admins from within the
[Convos UI](/blog/2019/11/24/convos-one-point-two).

### Organization name

Can be set if you want to add a touch of your organization. It will be used on
the login and on the help page, to name some.

### Organization URL

Used together with "Organization name" to add a link to your organization on
the login screen.

### Admin email

This email can be used by users to get in touch with the Convos admin. It will
be displayed on login, error and help pages.

### Default connection URL

This is the default connection _new_ users will connect to. The path part is
the default channel to join. "%23convos" means "#convos".

Changing this setting will not affect users who already registered.

### Force default connection

Tick this box if you want to prevent users from creating connections to other
than what "Default connection URL" is set to.

### Registration is open to public

Tick this box if you want users to be able to register without an invite URL.
If this box is _not_ ticked then a Convos admin must go to "Users" in the web
UI and generate an [invite URL](/blog/2019/11/24/convos-one-point-two).

## User settings

These settings are available from the Convos UI, and are specific per user
account or per browser session.

### Notification keywords

Can be set to a list of words that you want to get notifications about. You
will always be notified if someone mention your active nick, but you can also
add "milk, bread, butter" if that are your interests.

### Enable notifications

Tick this checkbox if you want to get desktop notifications.

This settings is only remembered in your current browser, since it also require
a browser action.

### Expand URL to media

Tick this checkbox if you want images, videos and other previews inside the
chat. Unticking this will require you to click on the posted link to understand
what is on that page.

This settings is only remembered in your current browser.

### Theme

Choose a theme for your chat. You can also create your own themes. Look at
"[Theming support in Convos
4.00](/blog/2020/5/14/theming-support-in-4-point-oh)" or
"[Create your own theme in minutes!](/blog/2020/6/14/create-your-own-theme-detailed-walkthrough)"
for more details.

This setting is only remembered inside the current browser. This is considered
a feature, since you might want one theme on your cell phone and another on
your desktop computer.

### Color scheme

Some themes support dark and light color schemes. The default is to follow your
desktop settings, but you can also force a dark/light scheme.

This settings is only remembered in your current browser.

### Password

Use this to change your login password. Keeping the field empty will _not_
change your password.

## Overriding assets/templates

You can override files under `/public` and `/templates` by placing your own
versions under `$CONVOS_HOME/content` and matching their relative paths. See
[the CMS blog post](/blog/2020/6/3/content-management-system) for details.

## Automatic startup with systemd

### With root access

Here is an example systemd file, that can be placed in
`/etc/systemd/system/convos.service`.

Note that the [Environment](#environment) variables should be reviewed and
changed to suit your needs.

    [Unit]
    Description=Convos service
    After=network.target

    [Service]
    Environment=CONVOS_HOME=/var/convos
    User=www
    ExecStart=/path/to/convos daemon --listen http://*:8081
    KillMode=process
    Restart=on-failure
    SyslogIdentifier=convos

    [Install]
    WantedBy=multi-user.target

After creating the file, you can run the following commands to manage the
service:

    # To make systemd aware of the new service unit
    systemctl daemon-reload

    # Enable Convos to be restarted on reboot
    systemctl enable convos.service

    # Start Convos
    systemctl start convos.service

    # See current Convos status
    systemctl status convos.service

    # Stop Convos
    systemctl stop convos.service

### As a normal user

_**NOTE**: This was tested on Ubuntu 18.04 and newer but should work on all distros that have systemd support_

To enable user systemd units you need to perform some extra steps as the user, which are the following:

    loginctl enable-linger

Then you need to create the `$HOME/.config/systemd/user` folder. You can do it with the following command:

    mkdir -p ~/.config/systemd/user

Note that the [Environment](#environment) variables should be review and changed to suit your needs (current ones use Convos's default paths).

Here is an example of a user systemd file, that can be placed in `~/.config/systemd/user/convos.service`:

    [Unit]
    Description=Convos User Service
    After=default.target

    [Service]
    ExecStart=/path/to/convos daemon --listen http://*:8081
    Restart=on-failure

    [Install]
    WantedBy=default.target

After creating the file, you can run the following commands to manage the
service:

    # To make systemd aware of the new service unit
    systemctl --user daemon-reload

    # Enable Convos to be restarted on reboot
    systemctl --user enable convos.service

    # Start Convos
    systemctl --user start convos.service

    # See current Convos status
    systemctl --user status convos.service

    # Stop Convos
    systemctl --user stop convos.service

Running Convos under systemd without a custom `CONVOS_LOG_FILE` will send all
the log messages to journald.

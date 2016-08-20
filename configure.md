---
layout: sub
title: Configuration
---

Convos can be configured with either a config file or environment variables.

Here is a list of all the available settings:

* CONVOS_BACKEND

  Can be set to any class name that "is a" Convos::Core::Backend.
  Defaults: "Convos::Core::Backend::File"

* CONVOS_CONNECT_DELAY

  This variable decides how many seconds to wait between each user to connect
  to a chat server. The reason for this setting is that some servers will set
  a permanent ban if you "flood connect".

  Default: 3.

* CONVOS_CONTACT

  Used when rendering "Contact" links in the frontend.

  Default: "mailto:root@localhost".

* CONVOS_DEBUG

  Setting this variable to a true value will print extra debug information to
  STDERR. Other useful debug variable is __MOJO_IRC_DEBUG__.

* CONVOS_DEFAULT_SERVER

  Used to declare which server should be pre-filled when a user creates a new
  connection.

  Default: "localhost".

* CONVOS_FORCED_IRC_SERVER

  Will force any Convos::Controller::Connection to use this server
  instead of whatever was posted in. Note that this environment variable also
  overrride __CONVOS_DEFAULT_SERVER__.

  This is disabled by default.

* CONVOS_HOME

  This variable is used by Convos::Core::Backend::File to figure out where
  to store settings and log files.

  Default: "$HOME/.local/share/convos/".

* CONVOS_INVITE_CODE

  This variable need to be used by the person who wants to register. It can be disabled
  by setting __CONVOS_INVITE_CODE=""__.

  Default: Semi-random string, which is written to log output:

      [info] Generated CONVOS_INVITE_CODE="b34b9a3ad3f80479b9c218effa3a8190"

* CONVOS_ORGANIZATION_NAME

  Should be set to the name of the organization running this instance of
  Convos.

  Default: "Nordaaker".

* CONVOS_PLUGINS

  A list of perl modules that can be loaded into the Convos::Core::Backend for
  optional functionality.

  Default: No plugins.

* CONVOS_SECRETS

  Should be set to list (colon separated) of random strings. This value is used
  to secure the Cookies written to the client.

  Default: A single generated unsafe value.

* CONVOS_SECURE_COOKIES

  Should be set to true if Convos is served over HTTPS.

  Default: "0".

* MOJO_CONFIG

  Can hold the path to a config file, which is read by Convos instead of
  using the environment variables. Example config:

      {
        backend        => $ENV{CONVOS_BACKEND},
        name           => $ENV{CONVOS_ORGANIZATION_NAME},
        secrets        => $ENV{CONVOS_SECRETS},
        secure_cookies => $ENV{CONVOS_SECURE_COOKIES},
        plugins        => {
          "Plugin::Name" => {plugin => "settings"},
        },
        settings       => {
          contact        => $ENV{CONVOS_CONTACT},
          default_server => $ENV{CONVOS_DEFAULT_SERVER},
        },
      }


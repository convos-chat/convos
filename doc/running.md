---
layout: page
title: Running
---

```bash
$ ./script/convos daemon --help
```

The command above will provide more information about command line arguments.
One useful switch is how to specify a listen port and make Convos bind to a
specific address:

```bash
$ ./script/convos daemon --listen http://127.0.0.1:8080
```

## Configuration

Any of the [settings](/doc/config.html) can be specified either in a
configuration file or as environment variables. Here is an example on how to
specific environment variables:

```bash
$ CONVOS_INVITE_CODE=s3cret ./script/convos daemon
```

One way of setting a bunch of environment variables is by putting them all in
a shell script:

```bash
#!/bin/sh
export CONVOS_CONTACT=jhthorsen@cpan.org
export CONVOS_HOME=/var/convos
export CONVOS_INVITE_CODE=s3cret
export MOJO_LOG_LEVEL=debug

exec /home/www/convos-stable/script/convos \
  daemon --listen http://*:3001            \
  1>>/home/www/log/convos.log              \
  2>>/home/www/log/convos.log
```

Instead of using environment variables, you can start convos with a config
file:

```bash
$ /home/www/convos-stable/script/convos /path/to/convos.conf \
    --listen http://*:3002

$ cat /path/to/convos.conf
{
  backend           => "Convos::Core::Backend::File",
  contact           => "mailto:root@localhost",
  default_server    => "localhost:6667",
  forced_irc_server => "localhost:6667",
  invite_code       => "s3cret",
  organization_name => "Awesome hackers",
  plugins           => [],
  secure_cookies    => 0,
  session_secrets   => ["signed-cookie-secret"],
}
```

## Hypnotoad and Prefork

It is *not* possible to run Convos with hypnotoad nor the prefork server. The
reason for this is that the
[Convos core](https://github.com/Nordaaker/convos/blob/master/lib/Convos/Core.pm)
requires shared memory, which a forked environment contradicts.

You need to run Convos in single process, using the
"[daemon](https://metacpan.org/pod/Mojo::Server::Daemon)" sub command shown
above.

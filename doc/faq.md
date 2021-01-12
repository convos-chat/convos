---
title: Frequently asked questions
toc: true
---

## Where does Convos store logs, settings and uploaded files?

All files are located in the [$CONVOS_HOME](./config#convos_home) directory.
The exact location will be written to the application log, or to screen
when you start Convos. Look for a log message such as:

    [2020-05-12 00:00:00.00000] [1234] [info] CONVOS_HOME="/home/superwoman/.local/share/convos" # https://convos.chat/doc/config#convos_home"

Here is a short overview of an example directory structure:

* [Global settings](/doc/Convos/Core/Settings)

        /home/superwoman/.local/share/convos/settings.json

* [User themes](/blog/2020/5/14/theming-support-in-4-point-oh)

        /home/superwoman/.local/share/convos/themes/

* User settings and logs

        /home/superwoman/.local/share/convos/joe@example.com/
        /home/superwoman/.local/share/convos/joe@example.com/user.json
        /home/superwoman/.local/share/convos/joe@example.com/irc-server/

* User uploaded and paste files

        /home/superwoman/.local/share/convos/joe@example.com/upload

  Uploaded files are stored with a ".data" extension, and meta information can
  be found in the companion ".json" file.

IMPORTANT! The "json" files located in `$CONVOS_HOME` should never be edited
while Convos is running.

## Can Convos be extended and customized?

Yes. Convos supports plugins, but there have not yet been any plugins
developed. We hope to implement
[#244](https://github.com/Nordaaker/convos/issues/244) and
[#90](https://github.com/Nordaaker/convos/issues/90) as the first core
plugins.

Look at the [configuration](/doc/config) guide to see which configuration
parameters that have to be set to load a plugin.

## Is Convos supported on my system?

Convos runs on MacOS and all flavors of Linux, but you might have to install
some dependencies:

    # MacOS
    brew install coreutils perl openssl

    # Debian, Ubuntu
    apt-get update
    apt-get install gcc libio-socket-ssl-perl make openssl perl

    # Redhat
    yum update
    yum install gcc make openssl-devel perl-core perl-io-socket-ssl

## Can Convos run behind behind my favorite web server?

Yes. See [Running Convos behind my favorite web server](/doc/reverse-proxy).

## Can I rename my connection names?

Currently it is not possible to rename the connection names from the web
interface, so you have to do it manually from the command line. You can do so
by following these steps:

1. Make sure Convos is stopped.
2. Find the `connection.json` file you want to edit in your
   [$CONVOS_HOME](./config#convos_home) directory.
3. Use your favorite editor and edit the file. Example:

        $EDITOR $CONVOS_HOME/you@example.com/irc-whatever/connection.json

4. Look for all occurances of "irc-whatever" and "whatever" and replace the
   "whatever" part with the name you want.
5. Rename the `$CONVOS_HOME/you@example.com/irc-whatever` directory to what
   you used as the new name above. Do not forget to keep the "irc-" prefix.
6. Start Convos again and you should see your new connection names after
   reloading the web page.

Make sure you use lower-case for "name" and "connection_id".

## Why does Convos stop when I close putty/xterm/some terminal?

Convos does not daemonize. It runs in foreground, so if you close a terminal
application, such as putty, it will also kill any running instance of Convos.

To prevent this, you can run this command:

    nohup script/convos daemon &

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
    ./script/cpanm -n -l $PWD/local Module::Install
    ./script/convos install

Please [contact us](/doc/#get-in-touch) if the above instructions do not work.

## Why can't Convos do X?

In most cases it's either because we haven't thought about it or haven't had
time to implement it yet. It might also be because we do not want to implement
certain features. We do not want Convos to support every weird feature, since
we want both the user experience and code base to be clean.

Please submit an [issue](https://github.com/Nordaaker/convos/issues), come
and talk with us in [#convos](irc://chat.freenode.net:6697/#convos) on
Freenode or send a tweet to [@convosby](https://twitter.com/convosby).

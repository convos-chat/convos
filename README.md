[![Build Status](http://strider.vm.nordaaker.com/523f43dc5893510900000008/marcusramberg/wirc/badge)](http://strider.vm.nordaaker.com/marcusramberg/wirc)

# WIRC

## About

WiRC is to a multi-user IRC Proxy, that also provides a easy to use Web Interface with a persistent connection.

## Installation

$ git submodule update -i
$ perl Makefile.PL
$ cpanm --installdeps .
# edit web_irc.conf, point to a working redis server
$ morbo script/web_irc
# open :3000

## Wanted Features

* Per client state (track seen messages).
* Web Notifications that integrate with notification center.
* Fast JS Web Interface with async communication (Web Sockets)
* Use HTML5 pushstate to be restful and fall back to page reloads for fully functioning non-async lite version.
* Monospaced to be compatible with old school IRC clients/ascii
* Rich media preview for links.
* Facebook Connect for registration/Avatars.
* Useful Archive search/viewer

## Architecture principles
* Keep the JS simple and manageable
* Use Redis to manage state / publish subscribe
* Archive logs in plain text format, use ack to search them.
* Bootstrap-based user interface

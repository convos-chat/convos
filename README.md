# WIRC

## Design goals

The goal of WiRC is to make a great multi-user IRC Proxy, that also provides a easy to use Web Interface with a persistent connection.

## Wanted Features

* Per client state (track seen messages).
* Web Notifications that integrate with notification center.
* Fast JS Web Interface with async communication (Web Sockets)
* Use HTML5 pushstate to be restful and fall back to page reloads for fully functioning non-async lite version.
* Monospaced to be compatible withth old school IRC clients/ascii 
* Rich media preview for links.
* Facebook Connect for registration/Avatars.
* Useful Archive search/viewer

## Architecture principles 
* Keep the JS simple and manageable
* Use Redis to manage state / publish subscribe
* Archive logs in plain text format, use ack to search them.
* Bootstrap-based user interface
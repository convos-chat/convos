---
title: Video support in Convos v4.08
---

Convos [v4.08](https://github.com/Nordaaker/convos/blob/4.08/Changes#L3) is
fresh from the bakery, and this time we are proud to announce video support!

<!--more-->

## How do I enable video support in Convos?

If you are just testing out Convos, you won't see any button to start the video
chat. The reason for this is that the underlying technology require a
[secure connection](#a-secure-connection), a [STUN server](#stun-server)
and optionally a [TURN](#turn-server) server.

### A secure connection

WebRTC will (probably) not function properly if you connect to Convos without a
secure connection. SSL certificates can either be bought or set up for free with
[Let's Encrypt](https://letsencrypt.org/). If you expose Convos directly on the
internet you can specify the certificates from the command line:

    ./script/convos daemon --listen "https://*:8443?cert=./server.crt&key=./server.key"

Keep in mind that the STUN and TURN server also require secure connections.

### STUN server

The absolute minimum to enable video support is a
[STUN server](https://en.wikipedia.org/wiki/STUN). This server is needed for
clients to exchange basic information for how to reach each other.

To start Convos with a given STUN server, you need to specify the
`CONVOS_STUN` environment variable. Example:

    CONVOS_STUN=stun://stun.services.mozilla.com:3478 ./script/convos daemon

A STUN server does not require much bandwidth, so there are many
[free alternatives](https://gist.github.com/mondain/b0ec1cf5f60ae726202e)
to choose from. If you want to set up your own server then
[Coturn](https://github.com/coturn/coturn) is a solid project to try out.

### TURN server

A TURN server *might* be needed some cases where the network between the two
clients is "complicated". The two clients will in that case send the video and
audio streams to the TURN server, instead of using peer-to-peer connections.

To start Convos with a given TURN server, you need to specify the
`CONVOS_TURN` environment variable. Example:

    CONVOS_TURN=turn://superwoman:kryptonite@stun.mydomain.com:3478

There are (to my knowledge) no free alternatives for this, so you have to set
up your own server for this. The [Coturn](https://github.com/coturn/coturn)
server also supports TURN, so you only need one external server to get a
video connection for all cases.

## How do I start a video chat?

Once you have started Convos with the `CONVOS_STUN` environment variable, you
can go to any conversation and there should be a video camera symbol on the
right side of the conversation name.

[![Picture of video button](/screenshots/2020-05-23-start-video.jpg)](/screenshots/2020-05-23-start-video.jpg)

Clicking on the video button will notify the other user(s) in the conversation
that you are ready to video chat. Any other user can then join and you will
then see and hear each other.

## Who can I video chat with?

The signalling protocol use IRC to send the WebRTC signals. The
[signalling protocol](https://github.com/Nordaaker/convos/blob/4.08/lib/Convos/Core/Connection/Irc.pm#L63-L64)
is however specific for Convos, so you can only video chat with other people
who have the same Convos version as yourself.

## Why is video support currently experimental?

There are several reasons why video support is currently marked as
experimental:

* The signalling protocol *might* cause issues for certain IRC networks. It is
  unknown which, but there are no guaranty that it will work with your favorite
  IRC server/network.
* The signalling protocol *might* change/break in future versions of Convos.
* There are very little error handling currently implemented. You probably have
  to peak into the developer console in your browser to look for issues if
  video does not work for you.

## What is next?

We hope to stabilize video support in Convos
[v5.00](https://github.com/Nordaaker/convos/milestone/21). It might sound like
that that is way into the future, but in reality Convos will jump from 4.xx to
5.00 once video support seems to work properly.

Want to help? Give us feedback either in #convos on freeenode.net or on
[GitHub](https://github.com/Nordaaker/convos/issues).

---
title: Convos features
description: Information about some of the Convos features
toc: true
---

This document is a work in progress, and some of the screenshots might be
inaccurate. Please submit a PR or let us know in the #convos channel on
[Libera](https://libera.chat/) if you think something is wrong or missing.

To see what Convos really support, we recommend trying out the
[demo](https://demo.convos.chat/register).

## Always online

Convos will keep you connected to a network, even if you close your browser.
This means you can come back later and see historic messages.

## Autocomplete

Convos feature autocompletion for commands, nicks, channels and emojis.

## Bot

Convos has a builtin bot. The bot has some core features listed in the link
below, but it can also be extended to cater your own needs.

* [Bot plugin](https://convos.chat/doc/Convos/Plugin/Bot)

## CMS

The CMS system in convos is no removed after the go rewrite. We recommend using
a static renderer like [hugo](https://gohugo.io/)

## Developer friendly

Want to contribute to Convos? The [Developement guide](/doc/develop) will get
you up and running. The backend is written in Go, the frontend in common web
technologies, but if you don't know either you can still contribute with
documentation patches.

* [Backend documentation](/doc/Convos)
* [REST API](/api.html)
* [WebSocket API](/doc/Convos/Controller/Events)

## Easy to install

No need for external servers or complex config files to [get up and
running](/doc/start).

## File uploads

* [Merry Christmas and happy uploading!](/blog/2019/12/24/merry-christmas-and-happy-uploading)
* [`CONVOS_MAX_UPLOAD_SIZE`](/doc/config#convos_max_upload_size)

## Forgotten password and invitation links

* [Forgotten password and invitation links](/2019/11/24/convos-one-point-two#forgotten-password-and-invitation-links)

## Notifications

Convos will show desktop notifications when your nick is mentioned, or if any
of the notification keywords are seen in a conversation. In addition, you can
also enable notifications for all messages in a channel, or turn off notifications
for a given private conversation.

* [Desktop notifications for messages in a channel](/blog/2019/11/24/convos-one-point-two#desktop-notifications-for-messages-in-a-channel)

Convos also supports webpush for notifications on mobile devices. Note that on ios you will need to add convos as an app on your home screen for this to work.

## On connect commands

* [On connect commands](/blog/2017/1/8/version-0-99-21#on-connect-commands)

## Pastebin

* [Convos got a built in pastebin](/blog/2017/5/9/convos-has-builtin-pastebin)

## Privacy

We believe that you should be in control of your own data. This means that all
the messages, file uploads and other information is kept on your server, and
not shared with a third party.

## Quick search

Convos has a quick search input in the upper left corner. This allows you to
filter conversations, search for historic messages or show conversations with
unread messages.

* [FAQ](/doc/faq)

## Rich formatting

* Convos can render emojis and will automatically turn common ASCII smileys into
  graphical emojis.
* Messages starting with ">" will be rendered as a quote.
* Common markdown formatting for bold and italic is supported.
* URLs will automatically be clickable.
* URLs will be expanded directly in the chat, giving you a quick preview.

## Settings

* [Environment variables](/doc/config#environment-variables)
* [Global config settings](/doc/config#global-config-settings)
* [User settings](/doc/config#user-settings)
* [Frontend settings](/2019/11/24/convos-one-point-two#a-new-settings-page)

## Theming

* [How to define custom styling for Convos](/blog/2019/11/2/custom-styling)
* [Create your own theme in minutes!](/blog/2020/6/14/create-your-own-theme-detailed-walkthrough)
* [Default theme config](/doc/config#convos_default_theme-and-convos_default_scheme)

## Translations

Convos is translated to Italian, Norwegian and Spanish. Want Convos to be
available in your language? Please open a PR!

## User administration

* [User administration](/blog/2019/11/24/convos-one-point-two#user-administration)

## Video support

Convos integrates with [Jitsi](https://meet.jit.si/). Clicking on "Camera"
symbol in the chat input will start a Jitsi video conference and post a
generated link into the current chat.

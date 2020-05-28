---
title: Convos version 0.99_33 is out with bugfixes
---

Version [0.99_33](https://github.com/Nordaaker/convos/tree/stable) has been
released with a bunch of updates. Run the
[install](/doc/start#quick-start-guide) command to get the
latest version!

## IRC servers with credentials

<!--more-->

A Convos user [reported in](https://github.com/Nordaaker/convos/issues/334)
that username/password was not handled correctly when you click "Save". The
existing logic at the time was very complicated and therefor also very buggy.
The idea was that the password submitted on web should not be sent back to the
web interface, because of security concerns. This logic is now changed, since
we think there's no issue sending the password over the web as long as you
protect your Convos installation with HTTPS.

And you do [protect](/doc/config#listen) Convos with HTTPS, right..?

## Online/offline state for private dialogs

Version [0.99_31](https://github.com/Nordaaker/convos/blob/master/Changes) was
released with a new method to detect if the user in a private dialog is online
or not: Convos now uses the
[ISON](https://tools.ietf.org/html/rfc2812#section-4.9) command instead of
[WHOIS](https://tools.ietf.org/html/rfc2812#section-3.6.2). This change was
introduced since ISON is a much lighter command to run, and simply answers
the question we want to know: Is this user online? The problem with "ISON" is
that the returned data looks like this:

    :hybrid8.debian.local 303 test21362 :
    :hybrid8.debian.local 303 test21362 :superman

The first reply is for an offline user, while the second is for a user that is
online. This looks quite sane, but it does not seem like the IRC server
returns the ISON reply in the same order as it is sent, so it's hard to track
if the offline response was for "superman" or some other nick, before you have
received all the replies. This logic is now improved in version
[0.99_33](https://github.com/Nordaaker/convos/issues/336) and seems to work as
expected.

I wonder if I have misunderstood something. Please
[contact](/doc#get-in-touch) me, if you have any information
regarding this.

## Active user tracking

Users in a channel has improved "active" tracking, which means that Convos will
track users who *was* active as well as currently active users. This helps
the autocomplete to order the nick list by last seen in the dialog. Pressing
"tab" will now autocomplete the last user who said anything in the dialog,
which makes sense since it's probably the person you want to reply to.

As a sidenote: The autocomplete has a better matcher for emojis, so you don't
need to remember the emoji name exactly by name.

## Enjoy!

Hope you enjoy these changes! Like to see your favorite chat feature
implemented? Then [get involved](/doc/develop). Need some help?
Ask us in [#convos](irc://chat.freenode.net:6697/convos) on chat.freenode.net.

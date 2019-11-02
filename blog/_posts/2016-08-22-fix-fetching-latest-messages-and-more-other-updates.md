---
layout: post
title: Fixed fetching latest messages on websocket reconnect and other juicy updates
---

The [stable](https://github.com/Nordaaker/convos/tree/stable) branch has now
been updated with major bugfixes:

## Server didn't like my code regarding "unread" count

<!--more-->

* [8b119352741074cf75f53b8973172f5cd7ed7cdd](https://github.com/Nordaaker/convos/commit/8b119352741074cf75f53b8973172f5cd7ed7cdd)
* Author: Jan Henning Thorsen <jhthorsen@cpan.org>
* Date: Mon Aug 22 14:57:12 2016 +0200

The "unread" count for the dialogs are now calculated on server side, instead
of in the browser. This is a far better solution than what was introduced in
[be445819cf01d22095b63e8a6dc10f3999c03d54](https://github.com/Nordaaker/convos/commit/be445819cf01d22095b63e8a6dc10f3999c03d54).
The problem with the previous solution was even worse than what I expected:
Seems like fetching participants and messages for a bunch of dialogs results
in either the server or browser to drop some of the requests. I could be
fooling myself, but that's what it looks like from browser dev console.

So now instead, the code does one `/api/user` request which retrieves the
connections, notifications and dialogs _with_ the unread count.  Later the
javascript lazy loads the messages from the backend when a dialog goes from
"inactive" to "active" state and also handles websocket reconnects.

## Participants where all over place

* [6d54a42a7f9d9e6cc2f268b072a19deae197514e](https://github.com/Nordaaker/convos/commit/6d54a42a7f9d9e6cc2f268b072a19deae197514e)
* Author: Jan Henning Thorsen <jhthorsen@cpan.org>
* Date: Mon Aug 22 19:50:10 2016 +0200

This was a pretty dumb bug, which would probably been avoided if there was any
unit tests for the vuejs/javascript code: There was two attributes tracking
the participants, but only one of them was actually in use when doing
autocomplete in the input field.

Which reminds me: Would very much appreciate
[help](http://localhost:4000/doc/#getintouch), regarding choosing a test
framework for the vuejs code.

## Send button to /dev/null

* [142a39f4c519b1c319ab23117fdbd88e7f4b13a9](https://github.com/Nordaaker/convos/commit/142a39f4c519b1c319ab23117fdbd88e7f4b13a9)
* Author: Jan Henning Thorsen <jhthorsen@cpan.org>
* Date: Sun Aug 21 14:44:00 2016 +0200

The "send button" next to the input field simply didn't work. This is fixed
now.

## Keep sending us those issue reports

[Denis Brækhus](https://github.com/denisbr) has been the first person to open
an issue regarding the new codebase on [github](https://github.com/Nordaaker/convos/issues/266).
This is much appreciated! He also posted a question on
[Twitter](https://twitter.com/denisb/status/767644051432673280):

<blockquote class="twitter-tweet" data-lang="en"><p lang="en" dir="ltr"><a href="https://twitter.com/convosby">@convosby</a> Sure short urls are nice etc, but why use “goo.gl” in the download url?</p>&mdash; Denis Braekhus (@denisb) <a href="https://twitter.com/denisb/status/767644051432673280">August 22, 2016</a></blockquote>
<script async src="//platform.twitter.com/widgets.js" charset="utf-8"></script>

## Thanks to everyone

Thanks to everyone who's active in #convos on
[chat.freenode.net](http://chat.freenode.net) and other channels, giving
feedback regarding the user experience and other minor bugs.

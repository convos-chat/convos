---
title: Add participants list and more
author: Jan Henning Thorsen
---

The [stable](https://github.com/Nordaaker/convos/tree/stable) branch has now
been updated. Want the updates? Run the [install](/doc/start) command!

## Who am I talking to?

<!--more-->

* [23bb5efabfaf30e6625256eda4b004999f110369](https://github.com/Nordaaker/convos/commit/23bb5efabfaf30e6625256eda4b004999f110369)
* Author: Jan Henning Thorsen <jhthorsen@cpan.org>
* Date: Wed Aug 31 20:34:02 2016 +0200

So in Convos a "channel" is called a dialog, and "users" are called
"participants". But until now, there was no good way to see the participant
list for a channel. This is now changed: A "cog wheel" button, next to the
"notifications" button will now show dialog settings.

[![Participants](/screenshots/2016-09-01-participants.png)](/screenshots/2016-09-01-participants.png)

## Why can't I install this awesome application?

* [5878ae229c431e4e6acc31f839f4b1ebd32672fd](https://github.com/Nordaaker/convos/commit/5878ae229c431e4e6acc31f839f4b1ebd32672fd)
* Author: Jan Henning Thorsen <jhthorsen@cpan.org>
* Date: Tue Aug 30 14:53:05 2016 +0200

There was an issue installing Convos if you did not already have
`IO::Socket::SSL` installed. This SSL module was added to the
[dependency list](https://github.com/Nordaaker/convos/blob/master/cpanfile),
but that doesn't help much when the module is required to install itself...
The fix is to install modules over HTTP instead of HTTPS, until
`IO::Socket::SSL` is installed.

## But wait! There's more!

Check out the
[Changes](https://github.com/Nordaaker/convos/blob/master/Changes) or have
a look at the [git history](https://github.com/Nordaaker/convos/commits/stable)
if you want all the details, but here are some highlights:

* Prevent showing join/part messages in all channels.
* Fix loading Convos on Windows Mobile.
* Fix parsing UTC time in Firefox.
* Add favicon.
* Add support for /kick and /mode IRC commands.

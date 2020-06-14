---
title: Convos version 0.99_24 is out
author: Jan Henning Thorsen
---

Version [0.99_24](https://github.com/Nordaaker/convos/tree/stable/Changes) is
out in the wild. This release feature some cool changes in the user interface,
but also some important bug fixes.

## Listing of available rooms

<!--more-->

The "Join dialog" page now shows a list of available rooms, which makes it
more intuitive and easy to find the correct chat room to join. The "Dialog
name" input field can be used to search in the list of available rooms.
The default list is sorted by number of participants, which makes it easy to
find the most popular rooms on the current server.

[![Join dialog](/screenshots/2017-01-29-join-dialog.png)](/screenshots/2017-01-29-join-dialog.png)

## You can now send any IRC command

There used to be a limitation to which IRC commands you could send. This
limitation is now [removed](https://github.com/Nordaaker/convos/issues/317).

Convos still handle some commands with custom logic (such as JOIN, WHOIS,
...), but other commands (such as WHOWAS) is now sent and received as raw IRC
messages. Please let us know if your favorite IRC command should get some
extra love, so it will render in a more pleasing way.

## Bug fixes

This version includes some bug fixes, here are the two most important fixes:

- Fix registration process: There used to be a bug which require you to refresh
  the browser window, after adding a new server. This is now fixed.
- You can now go to the profile and help pages while running the initial
  registration wizard.

## Enjoy!

So what are you waiting for? Get the new version of
[Convos](/doc/start#quick-start-guide) now!

And don't forget to [contact us](/doc/#get-in-touch) if something doesn't work
as expected, or you just want to say hi.

---
layout: post
title: We all like shiny things
---

It's been a while since the last post, but that doesn't mean there aren't cool 
things happening!

Version [0.99_15](https://github.com/Nordaaker/convos/tree/stable) is just out
with a bunch of updates. Run the
[install](/doc/getting-started.html#quick-start-guide) command to get up and
running!

### New shiny things

The user interface has a lot of improvements: Among other things, we now support 
emojis! Type in a smiley or an UTF-8 emoji, and it will render correctly using 
[emojione](http://emojione.com). The input field also support entering emojis, 
using the same interface as [github](https://github.com): Type ":" (colon) and 
then press "tab" to see possible emojis.

Are you a programmer? You can now format your code using backticks, just like
regular markdown supports, it will be rendered like `my.cool.code`.

The menu bar has fewer icons now. The "edit profile" and "help" icons are
removed, and the functionality moved to the left side menu, below
the dialog list.

### Major bug fix by a new contributor

[@alilles](https://github.com/alilles) had an issue where Convos would
truncate setting files when the disk is full. We tracked down the issue
and fixed it. The result is that Convos will now throw an error
instead of nuking all the settings for the users.

Thanks Anders, for helping out!

### Support for channel redirects

There are some IRC servers that support channel redirects – if
you join a channel called `#cool_channel`, then you might end up in
`##even_cooler_channel` instead. This feature made Convos very confusing,
where you could‘t part the origin channel. This is now fixed, and Convos
will correctly track channel redirects.

### More?

Want more details? Check out the
[Changelog](https://github.com/Nordaaker/convos/blob/master/Changes), or come
and [talk to us](/doc#get-in-touch).

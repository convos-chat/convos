---
layout: post
title: Convos 1.00 is out in the wild
---

It sure did take way too long time, but I've finally managed to release Convos
[1.00](https://github.com/Nordaaker/convos/blob/1.00/Changes#L3).

A new shiny tool for building webapps called [Svelte](https://svelte.dev) had a
[major release](https://github.com/sveltejs/svelte/commit/7382a9f811c830502e96aaad7fad7976def93d22)
in April, which fueled me with a new drive to give Convos a well deserved
overhaul. Svelte changes everything by moving the heavy lifting from your
browser to compile time &mdash; making web applications such as Convos more
snappy than ever!

<!--more-->

Svelte is truly a joy to work with. It's so much easier to predict when your
code will use CPU and render time.

## Highlights

But enough with what made Convos more fun to develop. What is new for you, the
user? You can see all the changes on [GitHub](https://github.com/Nordaaker/convos/blob/1.00/Changes#L3),
but here are some highlights:

### New sidebar

The old sidebar was pretty nice for the simple cases, but it got very hard to
understand which conversation you were in when you had multiple connections.
The new design fixes this by using a more traditional tree-view design, where
each conversation is grouped underneath its connection.

<a href=""><img src="/public/screenshots/2019-10-26-conversation.jpg" alt="Picture of Convos conversation"></a>

### Icons and colors for nicks

Each nick has a custom icon and color. The icon and color is calculated from the
actual nick, so it will be the same in each conversation and will not change.

A future version of Convos will also allow you to customize your own icon. Also if
you are recognized as a developer, you will get your own icon which will be
visible across all installations of Convos.

### Fixes for Safari on iOS

Running Convos inside Safari on iOS has been very annoying the last year,
because of some bugs related to `fixed` positioning set on elements such as the
text field where you write your messages. All this have been fixed in 1.00, by
using `absolute` positioning instead.

### Simpler registration process for new users

Before you had to create a connection during the registration process.
This could be very confusing for new users, that are not familiar with how IRC
works, but rather just wanted to chat. In 1.00, a new user will automatically
get the [default connection](/doc/config.html#convos_default_connection)
specified by the Convos admin.

### Improved help section

The [Help](http://demo.convos.chat/help) page now has information about rich
formatting support and autocomplete. Check it out for new features and changes!

### Nicks with MixedCaps

Nicks with mixed casing had many issues in the earlier versions of Convos.
One of the worst issue was that users might appear offline, even if they were
not. This is fixed in 1.00.

## Features that have been removed

### Custom styling

There is no longer any support for custom styling. This was removed when the
CSS build tool was changed to
[Mojolicious::Plugin::Webpack](https://metacpan.org/pod/Mojolicious::Plugin::Webpack).
But do not fear &mdash; A future release of Convos will allow you to customize
the theme and colors directly from your settings panel. Some presets might also
be included, allowing you to change to Dark Mode!

### ShareDialog plugin

The ShareDialog plugin was very buggy, and it also had a bunch of privacy issues.
That is the reason why this plugin is no longer available.

## Moving onwards

The next releases in Convos should be covered in different milestones. Check
out the [1.01](https://github.com/Nordaaker/convos/milestone/9) milestone for
planned tasks.

Curious about Convos? Try out the [demo](http://demo.convos.chat) or
[install](/doc/getting-started.html#quick-start-guide) Convos on your
computer/server.

Enjoy!

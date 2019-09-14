---
layout: page
title: Documentation
---

## Getting started

Check out the [getting started](/doc/getting-started.html) guide if you need
help regarding how to download, install, and run Convos.

## Configuring

The [configuration](/doc/config.html) guide explains how to customize Convos.
Note that there is no need to configure Convos to get it running! Convos has
sane defaults, which makes it a breeze to start.

You might also want to check out the [faq](/doc/faq.html) for the most common
obstacles while setting up and running Convos.

## Developing

Are you interested in developing Convos? The check out the
[develop](/doc/develop.html) guide. We want _you_ on our team!

## Get in touch

There are several ways to get in touch. We would love to hear from you in
either way you choose!

You can join [#convos](irc://chat.freenode.net:6697/#convos) on
[freenode.net](http://freenode.net/) for an interactive chat, send us a
message on [twitter](https://twitter.com/convosby) or create an
[issue](https://github.com/Nordaaker/convos/issues) on Github. If you're more
of the email type, then send an email to
<a href="mailto:jhthorsen@cpan.org">jhthorsen@cpan.org</a>.

## Statistics

The backend of Convos is written in [Perl](https://www.perl.org/) and
[Mojolicious](http://mojolicious.org/), while the frontend is written
with [JavaScript](https://developer.mozilla.org/en-US/docs/Web/JavaScript)
and [Vue](https://vuejs.org/).

| Language        | Files |  Code | Comment                 |
|-----------------|-------|-------|-------------------------|
| Perl            |    21 |  2380 | Without counting tests  |
| JavaScript      |    21 |  1613 | jQuery and vanilla      |
| Vuejs Component |    30 |  1529 | Reactive web components |
| Sass            |    12 |   947 | CSS / Sass              |
| JSON            |     1 |   685 | OpenAPI specification   |
| Total           |    85 |  7154 |                         |

Updated 2017-04-24 using `cloc assets/{js,vue,sass}/ lib/`

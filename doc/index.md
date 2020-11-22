---
title: Documentation
description: Getting started - FAQ - Configuring - Guide for developers - Statistics
---

<ul class="toc">
  <li><a href="/doc/start">Getting started</a></li>
  <li><a href="/doc/faq">Frequently asked questions</a></li>
  <li><a href="/doc/config">Configuring Convos</a></li>
  <li><a href="/doc/develop">Guide for developers</a></li>
</ul>

## Getting started

Check out the [getting started](/doc/start) guide if you need
help regarding how to download, install, and run Convos.

## Configuring

The [configuration](/doc/config) guide explains how to customize Convos.
Note that there is no need to configure Convos to get it running! Convos has
sane defaults, which makes it a breeze to start.

You might also want to check out the [FAQ](/doc/faq) for the most common
obstacles while setting up and running Convos.

Have a look at "[Running Convos behind my favorite web server](/doc/reverse-proxy)"
if you want to run Convos behind nginx, Apache or some other reverse proxy.

## Developing

Are you interested in developing Convos? The check out the
[develop](/doc/develop) guide. We want _you_ on our team!

## Get in touch

There are several ways to get in touch. We would love to hear from you in
either way you choose!

You can join [#convos](irc://chat.freenode.net:6697/#convos) on
[freenode.net](http://freenode.net/) for an interactive chat, send us a
message on [twitter](https://twitter.com/convosby) or create an
[issue](https://github.com/Nordaaker/convos/issues) on Github. If you're more
of the email type, then send an email to
<a href="mailto:contact@convos.chat">contact@convos.chat</a>.

## Statistics

The backend of Convos is written in [Perl](https://www.perl.org/) and
[Mojolicious](http://mojolicious.org/), while the frontend is written
with [JavaScript](https://developer.mozilla.org/en-US/docs/Web/JavaScript)
and [Svelte](https://svelte.dev/).

<table class="table">
  <thead>
    <tr><th>Language</th><th>Files</th><th>Lines</th></tr>
  </thead>
  <tbody>
    <tr><td>Perl</td><td>26</td><td>4071</td></tr>
    <tr><td>Svelte</td><td>29</td><td>2148</td></tr>
    <tr><td>JavaScript</td><td>29</td><td>2868</td></tr>
    <tr><td>Sass</td><td>30</td><td>2768</td></tr>
    <tr><td>SVG</td><td>1</td><td>11</td></tr>
    <tr><td>Total</td><td>117</td><td>12188</td></tr>
  </tbody>
</table>

Updated after 4.35 release, using `cloc assets/ lib/ --force-lang=CoffeeScript,svelte`

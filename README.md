[![convos](https://snapcraft.io//convos/badge.svg)](https://snapcraft.io/convos)
[![Docker Status](https://github.com/convos-chat/convos/workflows/Docker%20Image%20CI/badge.svg?branch=master)](https://hub.docker.com/r/convos/convos)
[![Build Status](https://github.com/convos-chat/convos/workflows/Linux%20CI/badge.svg?branch=master)](https://github.com/convos-chat/convos/actions)
[![GitHub issues](https://img.shields.io/github/issues/convos-chat/convos)](https://github.com/convos-chat/convos/issues)

# Convos - Multiuser chat application

Convos is a multiuser chat application that runs in your web browser.

The supported chat protocol is currently IRC, but Convos can be extended to
support other protocols as well.

See [convos.chat](http://convos.chat) for more details.

The backend is powered by [Mojolicious](http://mojolicious.org), while the
frontend is held together by the progressive JavaScript framework
[Svelte](https://svelte.dev/).

## Quick start guide

See "[Getting started](https://convos.chat/doc/start)" for other
options and more information.

### Install locally

```bash
curl https://convos.chat/install.sh | sh -
./convos/script/convos daemon
```

That's it! After the two commands above, you can point your browser to
[http://localhost:3000](http://localhost:3000) and start chatting.

### Docker install

You can use the command below to pull and run convos:

```bash
docker pull convos/convos:stable
mkdir -p $HOME/convos/data
docker run -it -p 8080:3000 -v $HOME/convos/data:/data convos/convos:stable
```

Note that [Nordaaker/convos](hub.docker.com/r/Nordaaker/convos/) will be around
for a while, but the new official image is "convos/convos".

## How to make a release

Notes for developers so a new release is made in a proper way.

```
# Update with the recent changes and make sure the timestamp is proper
$EDITOR Changes

# Build the production assets and update and check that all the files
# have the correct version information
./script/convos build release
```

## Branch overview

### alpha

The "alpha" branch will be force pushed to when we need to make a new docker
builds with working assets, but with experimental features. Example:

  git checkout -b user/some-feature
  $EDITOR assets/store/Conversation.js
  ./script/convos build
  git add .
  git commit -a -m "made some experimental changes"
  git push origin -f user/some-feature:alpha

### master

"[master](https://github.com/convos-chat/convos/tree/master)" is for
developers. It's mostly stable, but might require extra tools and packages to
run. This branch might have outdated assets (JavaScript, CSS files), so it
might not work properly.

### stable

"[stable](https://github.com/convos-chat/convos/tree/stable)" is the branch you
should use, if you want to clone and run Convos. The JavaScript assets and the
Perl code will be in sync here.

### www.convos.chat

"[www.convos.chat](https://github.com/convos-chat/convos/tree/www.convos.chat)" is the source
for [http://convos.chat](http://convos.chat), which is powered by the built-in CMS
In Convos.

# Convos - Making IRC chat application smooth and easy!

Convos is a multiuser web-based chat application that let you enjoy comfortable chatting without leaving browser and memory-intensive IRC clients. With its dynamic features, Convos enables you to stay in touch with worldwide IRC channels and communicate with the users in an interactive way. You can get access to the most popular chat protocol IRC in Convos and can customize it for extending support for other protocols you want.

[![convos](https://snapcraft.io//convos/badge.svg)](https://snapcraft.io/convos)
[![Docker Status](https://github.com/convos-chat/convos/workflows/Docker%20Image%20CI/badge.svg?branch=main)](https://hub.docker.com/r/convos/convos)
[![Build Status](https://github.com/convos-chat/convos/workflows/Linux%20CI/badge.svg?branch=main)](https://github.com/convos-chat/convos/actions)
[![GitHub issues](https://img.shields.io/github/issues/convos-chat/convos)](https://github.com/convos-chat/convos/issues)


## Key Features

* Interactive chatting experience.
* Easy-to-use Web interface.
* Multiuser chat options with real-time channels.
* Runs on modern browsers.
* Filtering and highlighting messages.
* Customizable messages set up.

See [convos.chat](http://convos.chat) for more details.

The backend is powered by the modern Perl framework [Mojolicious](http://mojolicious.org), which enables developers to create minimal web frameworks for building practical, real-time Web applications with expressiveness and flexibility. Along with that, Convos' user interface is powered by the blazing-fast progressive JavaScript framework [Svelte](https://svelte.dev/), making your web application's frontend performance super amazing.

## Getting Started

Choose one of the following options to get started quickly with Convos:

### Installing Locally

Using the following commands, you can set up Convos on your local environment with ease.

```bash
curl https://convos.chat/install.sh | sh -
./convos/script/convos daemon
```

Now you are all set to chat online! Just point your browser to http://localhost:3000 and get started.

### Docker Installation

You can use the command below to pull and run convos with Docker:

```bash
docker pull convos/convos:stable
mkdir -p $HOME/convos/data
docker run -it -p 8080:3000 -v $HOME/convos/data:/data convos/convos:stable
```

Note that [Nordaaker/convos](hub.docker.com/r/Nordaaker/convos/) will be around for a while, but the new official image is "convos/convos".

Please check out our [Getting Started Guide](https://convos.chat/doc/start) for more information on setting up Convos on your machine.

## How to Make a Release

Follow the below steps correctly for making a new release:

```bash
# Update with the recent changes and make sure the timestamp is proper
$EDITOR Changes

# Build the production assets and update and check that all the files
# have the correct version information
./script/convos build release
```

## Branch Overview

### Main

"[main](https://github.com/convos-chat/convos/tree/main)" is for developers. Though it is mostly stable, it may require additional tools and packages to run. The branch may contain outdated assets (JavaScript, CSS files), making it potentially unstable.

### Stable

"[stable](https://github.com/convos-chat/convos/tree/stable)" is the branch users should use to clone and run Convos. The JavaScript assets and the Perl code are always in sync here.

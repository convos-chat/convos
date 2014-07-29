![Convos](http://convos.by/images/logo.png)

Convos is the simplest way to use IRC. It is always online, and accessible to your web browser, both on desktop and mobile. Run in on your home server, or cloud service easily. It can be deployed to Heroku or Docker-based cloud services, or you can just run it as a normal Mojolicious application, using any of the Deployment Guides.

![Screenshot](http://convos.by/images/screenshot.jpg)

You can also check out our [live demo](http://demo.convos.by).

## Features
#### Always online
The backend server will keep you logged in and logs all the activity in your archive.

### Archive
All chats will be logged and indexed, which allow you to search in earlier conversations.

### Avatars
The chat contains profile pictures which can be retrieved from Facebook or from gravatar.com.

### Include external resources
Links to images and video will be displayed inline. No need to click on the link to view the data.

## Installation
Convos requires a Redis server to function. If you are deploying on osx you can use homebrew, or if you are on ubuntu or similar install redis-server using apt-get. Note that we require Redis 2.6+. If your distro version is too old, you can easily build redis from source.

To install convos we provide a simple script. All it requires in addition to redis is a working build environment with make, Perl and a C compiler. Copy/paste this to the command line:

    $ curl -L https://convos.by/install.sh | bash -

Then just follow the simple instructions. If you're worried about running a script directly from a web server, just download it and inspect it before you run it.

## Running convos in production

morbo is an excellent tool for testing, but hypnotoad should be used to run Convos in production:

    $ ./vendor/bin/carton exec hypnotoad script/convos

The command above will start a full featured, UNIX optimized, preforking non-blocking webserver. Run the same command again, and the webserver will hot reload the source code without losing any connections. By default it will listen to http://*:8080/ but you can easily configure this in convos.conf - It can even serve HTTPS directly if you install IO::Socket::SSL from CPAN.

See also the [Mojolicious Guides](http://mojolicio.us/perldoc/Mojolicious/Guides/Cookbook#DEPLOYMENT) for production deployment.

For convenience, we also include a Dockerfile so you can build a Docker image easily if you want a custom config, or  pull our image directly from the [docker index](https://index.docker.io/u/nordaaker/convos/).

If you are interested in deploying Convos on Digital Ocean, you should follow
[this guide](http://thorsen.pm/perl/2014/03/02/convos-on-digitalocean.html).

Note: By default Convos will use the Mojo IOLoop, which is pure perl. In production you might want to install [EV](https://metacpan.org/release/EV) - we automatically use it if it is installed, and it performs much better.

### Running the backend separately.

In production setups, you might want to start the backend separately from the web application, for various reasons. To do so, just turn off the 'embedded' flag in the backend section of the convos.conf file. The just start it up separately:

    # Start up the backend
    $ ./vendor/bin/carton exec script/convos backend &

## Upgrading Convos

To get the latest version of convos, you can run the install script above again from the parent directory of your convos-release directory, and it will download a newer version and overwrite your installation. Before you do this, make sure to stop the running application, then start it again once you've updated. Note that if we've changed the schema, Convos will ask you to upgrade it before you can start the app. to do this, run

    $ ./script/convos upgrade

From the convos-release folder. This should automatically update your schema to the latest version.

Note that if you downloaded convos using git, you should do `git pull` instead of using the install script.

## Architecture principles
* Keep it easy to install
* Keep the JS simple and manageable
* Use Redis to manage state / publish subscribe
* Archive logs in plain text format, use ack to search them.



## Authors
Jan Henning Thorsen - jhthorsen@cpan.org
Marcus Ramberg - marcus@nordaaker.com

## Copyright & License
Copyright (C) 2012-2014, Nordaaker.

This program is free software, you can redistribute it and/or modify it under the terms of the Artistic License version 2.0.

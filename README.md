# Convos - Multiuser chat application


 Convos is a multiuser chat application built with Mojolicious.

 It currently support the IRC protocol, but can be extended to support
 other protocols as well.


# Getting Started 


First we are going to need to install some dependencies:

```  $ ./script/convos install

Once this is done can start Convos by running one of the commands below.

```  $ ./script/convos daemon;
   $ ./script/convos daemon --listen http://*:3000;
```


And connect a browser to localhost:3000.

To run Convos on a server, check out the relevant (Mojolicious Guides)[http://mojolicious.org/perldoc/Mojolicious/Guides/Cookbook#DEPLOYMENT].

[![Build Status](https://travis-ci.org/Nordaaker/convos.svg?branch=one-point-oh)](https://travis-ci.org/Nordaaker/convos)

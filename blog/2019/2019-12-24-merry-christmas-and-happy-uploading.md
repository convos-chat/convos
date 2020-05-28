---
title: Merry Christmas and happy uploading!
---

Santa's Little Helpers have been working hard to bring you the
[3.0](https://github.com/Nordaaker/convos/blob/3.00/Changes#L3) release of
Convos, but it's all done and ready to come down a chimney where you live.

This is probably my favorite release so far. "Why?", you might ask. Well, the
reason is simple: You can now upload photos (or any file you like) directly
using Convos, without the hassle of going through a third party service.

<!--more-->

## File sharing

Not using a third party service is very important, since Convos is about
privacy. You run your own instance. You're in charge of the logs and data, so
sharing a file should be no different. Did you upload the wrong file? No
problem - [just delete it](https://github.com/Nordaaker/convos/issues/426),
and it will be gone forever.

Uploading a file can be done in two ways:

1. Drag and drop the file into the conversation.
2. Click on the new "upload" icon, next to the "send" icon in the message input.

[![Picture of Convos upload icon](/screenshots/2019-12-24-upload.jpg)](/screenshots/2019-12-24-upload.jpg)

Either will result in a link being inserted into the message input field.
Clicking on send afterwards will share the file with the person/people in the
conversation. The link is not password protected, so non-convos users can see
it as well.

Uploading text files will create a paste, just like when you insert a long
message or many lines into the message input field.

Uploading an image will result in a clickable thumbnail.

The maximum upload size is 40MB by default. The
[config page](/doc/config#convos_max_upload_size) has details on how to
change this value

## A codebase full of promises

Convos jumped directly from 2.0 to 3.0, because this release also features some
breaking changes in the Perl codebase: The non-blocking API is now powered by
[promises](https://mojolicious.org/perldoc/Mojo/Promise), instead of the
callback based API. This makes the codebase a lot smaller and easier to work
with. The PR actually saved about 100 lines of code, while at the same time
getting rid of the [Mojo::IRC](https://github.com/jhthorsen/mojo-irc)
dependency.

Please see [#423](https://github.com/Nordaaker/convos/pull/423) for all the
major changes. There were some bugfixes after that PR was merged as well, but
most of the changes are there.

## Snap build

I'm very happy to see that we are finally up to date in the
[Snap store](https://snapcraft.io/convos/)! Big thanks to
[Adam Stokes](https://github.com/Nordaaker/convos/pull/421) for fixing the
config file and explaining how to set up automatic builds.

## Moving onwards

Hopefully we'll see 3.01 (and not another major release) in January, with the
following changes:

* [#380](https://github.com/Nordaaker/convos/issues/380) - Add nickserv certfp authentication
* [#422](https://github.com/Nordaaker/convos/issues/422) - Multi-language User Interface
* [#425](https://github.com/Nordaaker/convos/issues/425) - Get rid of Unicode::UTF8 as dependency
* [#426](https://github.com/Nordaaker/convos/issues/426) - As a user, I would like to manage my uploaded files

I don't know exactly how to solve #380 and #425 though, so any input is more
than welcome!

Got something else that you think should be prioritized? Come talk to us in
\#convos at [chat.freenode.net](irc://chat.freenode.net:6697/%23convos?tls=1) or
use the [issue tracker](https://github.com/Nordaaker/convos/issues).

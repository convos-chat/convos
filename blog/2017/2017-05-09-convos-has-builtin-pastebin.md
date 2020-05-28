---
title: Convos got a built in pastebin
---

Convos has a high focus on privacy. Convos can be run on closed network, and
no external resources on the public internet should ever be needed. This ideas
was also taken into consideration when we decided bundle a
[pastebin](https://github.com/Nordaaker/convos/pull/329) with Convos. The
pastebin implementation stores the data in
[CONVOS_HOME](/doc/config#convos_home), meaning you are
in full control of the data shared.

<!--more-->

The pastebin works like this:

1. Copy a chunk of multiline text
2. Paste it into the the input text box in a conversation
3. Hit enter
4. Convos will create a paste, and send the link to the past as a message

Here is an example paste:

![Example paste](/screenshots/2017-05-09-pastebin.png)

## Multiline messages

If the text is three lines (subject to change) or less, then Convos will
simply send the them as three messages instead. There is an environment variable
that decides how many lines you need to have before it is converted to a paste.
It is not public, so changing this might not work in the future, but if you want
to play around and tweak the setting, you can try the command below:

    CONVOS_MAX_BULK_MESSAGE_SIZE=1 ./script/convos daemon

## External pastebin service

There are currently no plan to implement support for sending a paste to an
external service, but that doesn't prevent you from making your own. The
pastebin is implemented as a
[plugin](https://github.com/Nordaaker/convos/blob/master/lib/Convos/Plugin/Paste.pm),
meaning you can create your own and load that instead.

The plugin simply listens to a `multiline_message` event and creates a paste
based on the information from the backend. Below is an alternative that post
the paste to [ix.io](http://ix.io/):

    $app->core->backend->on(multiline_message => sub {
        my ($backend, $connection, $text, $cb) = @_;
        $app->ua->post("http://ix.io", form => {"f:1" => $$text}, sub {
          my ($ua, $tx) = @_;
          my $err = $tx->error ? $tx->error->{message} : "";
          $backend->$cb($err, $tx->res->body);
        });
    });

The `$connection` object is there so you can get the user object, which again
can hold authentication details for the paste service. Note that this is
currently not implemented in the frontend, but this can of course be changed.

After all... Convos is Open Source!

## Want to know more?

Please [contact us](/doc/#get-in-touch) if you're interested into learning
more about how to make a plugin, or have questions about Convos in general.

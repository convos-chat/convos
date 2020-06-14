---
title: Convos is more user-friendly than ever
author: Jan Henning Thorsen
---

Convos has always been about making the most user-friendly chat interface for
IRC networks. We wanted to create the easiest user interface to keep in touch
with our friends and fellow open source developers. Focusing on the chat
experience is still the main focus, but we also see that it is important for
our users to be able to tweak settings in a convenient way. Convos
[2.00](https://github.com/Nordaaker/convos/blob/2.00/Changes#L3) addresses some
of these needs.

<!--more-->

You can see a list of all the changes and bug fixes on
[GitHub](https://github.com/Nordaaker/convos/blob/2.00/Changes#L3).

## Administration user

One of the main reasons why this is a major release, is the introduction of
user roles. Currently a user can be either "admin" or just a regular user.

The first user to register will become the "admin", so that means that if you
have an existing Convos installation then we try to guess who to upgrade to
"admin":

1. If the `user.json` file has a "registered" key then that will be used to
   see if you are the first to register.
2. If you have a very old Convos installation and there's no "registered" key,
   then the created timestamp of the `user.json` file will be used instead.

This means that if you are upgrading, you might want to double check which
`user.json` file has `roles:["admin"]` inside it. If the wrong user is upgraded
then you have to edit the files in [CONVOS_HOME](/doc/config) manually.

## A new settings page

We used to support many [environment variables](/doc/config) and/or the
option to give Convos a config file. Most of these settings can now be
configured on a settings page:

* Organization name - This can be changed if you want to add a touch of your
  organization to the login/register page.
* Organization URL - This can be used together with the organization name to
  add a custom link in the login navigation.
* Admin email - A public email that can be used by your Convos user to get in
  touch with you.
* Default connection URL - Will be the server and channel a new user connects
  to after registering.
* Registration is open to public - Tick this box, if you want users to be able
  to join, without an invite link.

[![Picture of Convos server settings](/screenshots/2019-11-24-server-settings.jpg)](/screenshots/2019-11-24-server-settings.jpg)

Please do [let us know](https://github.com/Nordaaker/convos/issues) if you want
any other settings to be available on this screen.

## Forgotten password and invitation links

Prior to version 2.00, you would share an invitation code with your users to
register. This meant a shared secret that could be used by anybody at any time.
Not only was it less secure, but it also made the registration unnecessarily
complicated.

The invite code logic is completely replaced with an invite link in Convos 2.0.
This link can be created by the Convos admin on the settings page This together
with the "default connection URL" makes joining Convos incredible easy for new
user. Also, the link is
[unique](https://github.com/Nordaaker/convos/blob/2.00/t/web-register-invite-only.t)
for the invited user, making your Convos instance more secure.

[![Picture of Convos invite and recover link](/screenshots/2019-11-24-invite-link.jpg)](/screenshots/2019-11-24-invite-link.jpg)

The same form can be used to generate a "forgotten password" link for existing
users. But what if you're the only user, and you forget your password..? Fear
not, you can generate your a recovery link from the command line:

    ./script/convos get -k -M POST \
      -H X-Local-Secret:YOUR_LOCAL_SECRET \
      "/api/user/YOUR@EMAIL.COM/invite"

Note that the host and port part of the URL printed to the console might need
to be changed if you're running the command on a remote host. Also,
"YOUR_LOCAL_SECRET" need to be changed to your actual
[CONVOS_LOCAL_SECRET](/doc/config) variable.

## Desktop notifications for messages in a channel

Convos now supports getting desktop notifications for all activities in a
channel, just like from a private conversation. This is incredible useful if
you are in a low traffic channel, or in a channel where important log messages
are posted.

[![Picture of channel settings for desktop notifications](/screenshots/2019-11-24-channel-desktop-notifications.jpg)](/screenshots/2019-11-24-channel-desktop-notifications.jpg)

## Shortcut for getting to conversation settings

Tired of moving all over the screen to get to the connection or conversation
settings? You can click on the icon next to the conversation name to get to
the settings.

[![Picture of settings shortcut](/screenshots/2019-11-24-settings-shortcut.jpg)](/screenshots/2019-11-24-settings-shortcut.jpg)

(Clicking on the conversation title and the "sliders" icon still works)

## Moving onwards

Next up will be the [2.01](https://github.com/Nordaaker/convos/milestone/12)
release, where we focus on being able to share images and documents in your
Convos chat. This is something I've wanted for a long, since it's very often
I take a photo and would love to post it in a chat.

Can't wait to get started!

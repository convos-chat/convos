---
title: Local secret is more secure in Convos 4.20
author: Jan Henning Thorsen
---

Convos 4.20 has an important update - especially if you are running Convos in
Docker.

## Secrets in Convos

There are two secrets that is very important for the overall security of
Convos: `CONVOS_LOCAL_SECRET` and `CONVOS_SECRETS`.

* `CONVOS_SECRETS` is used to check that the [session cookie](/doc/Mojolicious#secrets)
  is not altered on the client side. If this value is known to the public then a
  hacker can change the session cookie and log in as any existing user.
* `CONVOS_LOCAL_SECRET` on the other hand is used by admins who generates either
  a reset password link or an invite link.

The initial value of these to secrets can be set in environment variables, but
after Convos has been started the first time they will be saved and read from
`$CONVOS_HOME/settings.json`.

## What has been changed?

The `CONVOS_SECRETS` setting was relatively safe before v4.20, since it used a
pseudo random number and a floating point timestamp. `CONVOS_LOCAL_SECRET` on
the other hand can be guessed by hacker, especially if you were running Convos
inside [Docker](https://www.docker.com/).

This security issue has now been patched in
[54d1763ac](https://github.com/Nordaaker/convos/commit/54d1763ac65c05aad27ad454b4e5a62ba8352d39#diff-ea66a76f841b0b3c8843d07100b36304R134-R144).

The new way to calculate secrets is either...

1. Read some random bytes from `/dev/urandom`, if that device is available.
2. Fall back on using a pseudo random number and a floating point timestamp
   for both `CONVOS_LOCAL_SECRET` and `CONVOS_SECRETS`.

## What should you do?

Either if you are running inside Docker or not, then we urge you to restart
Convos with a new secret right away. You can do so by following these steps:

1. Stop Convos
2. Generate new secrets either from
   [this website](https://onlinehashtools.com/generate-random-sha1-hash)
   or even better with a command like this:

        # Run this command twice
        echo "$(&lt; /dev/urandom tr -dc A-Za-z0-9 | head -c 40)"

4. Edit `$CONVOS_HOME/settings.json` and replace the existing value for
   `local_secret` and `session_secrets`.
5. Start a fresh Convos that is more secure than before!

Here is a sample `settings.json` file:

    {
      "contact": "",
      "default_connection": "",
      "forced_connection": false,
      "open_to_public": false,
      "organization_name": "",
      "organization_url": "",
      "local_secret": "710da2cf2fd8e3cf0f65f405293858e607d70bc7",
      "session_secrets": ["9563bcbd5853f7871f1f2585317aa9c573f7d9a6"]
    }

## What if you do not know how to edit settings.json?

If you do not know how to change the values of the settings file, then simply
stop Convos, delete
[`$CONVOS_HOME/settings.json`](/doc/faq#where-does-convos-store-logs-settings-and-uploaded-files)
and start Convos again. You have to manually go to "Settings" in Convos to
restore your application settings, but that is a small price to pay.

## How can I tell if my system has been exploited?

If you do not have unexpected users `$CONVOS_HOME`, then your system has not
been exploited.

## For the future

You might want to rotate your secrets from time to time. This means that you
follow the steps [above](#what-should-you-do) every now and then to make sure
your secrets are indeed private to Convos.

## Special thanks

Special thanks to [Stig P](https://github.com/stigtsp) for pointing out how bad the
"local_secret" generator was inside Docker.

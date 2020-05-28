---
title: How to get Convos up and running on DigitalOcean
---

Not sure how to get your Convos to be truly always online in the cloud? Fear
not: This tutorial will help you get up and running on
[DigitalOcean](https://www.digitalocean.com/).

It should only take ***ten minutes*** to get up and running, and the running
cost will be about 5USD per month.

<!--more-->

## Registration

The first thing you need is an account at DigitalOcean:

1. Go to [digitalocean.com](https://www.digitalocean.com/) and click on
   "[Sign up](https://cloud.digitalocean.com/registrations/new)" in the upper
   right corner.
2. Follow the instructions.

## Create your droplet

You can follow the official
"[How to Create a Droplet from the DigitalOcean Control Panel](https://www.digitalocean.com/docs/droplets/how-to/create/)",
which has the latest screenshots, but you can try to
[this link](https://cloud.digitalocean.com/droplets/new?region=sfo2&size=s-1vcpu-1gb&distro=ubuntu&distroImage=ubuntu-19-10-x64&options=ipv6,install_agent)
to get a pre-filled page.

Note that that the link might be outdated, so below is a breakdown of all the
choices. Everything that is not mentioned here, can be left to the default
choice.

1. Click the green **Create** button in the upper right corner.
2. Choose **Droplets** from the dropdown menu.
3. A **Create Droplets** page should appear, where you choose your configuration.
   It should be enough with the following setup to just get started:
   * **Distribution**: We suggest selecting "Ubuntu 19.10 x64".
   * **Plan**: The cheapest one (5USD/month) should be enough to get started.
   * **Datacenter region**: Choose one close to where you live for lowest latency,
     but any location will work.
   * **Select additional options**:
     * Tick **IPv6** - Not important, but nice to have.
     * Tick **Monitoring** - Will allow you to see CPU, memory and disk usage from
       the DigitalOcean admin panel.
     * Tick **User data** and copy/paste in these two lines of code:

         #!/bin/sh
         wget https://convos.chat/scripts/2019-11-26-digital-ocean-user-data.txt -O - | /bin/sh -

   * **Authentication**: "SSH keys" is highly recommended, but Choose one-time
     password, if you don't have any experience with SSH.
   * **Choose a hostname**: This is *not* a public domain name, but rather just a
     way to find your host in the admin panel later on.
   * **Enable backups**: Nice to have, in case something terrible goes wrong, but
     optional.
4. After you've made all the choices on the **Create Droplets** page, you can
   click on **Create droplet** in the bottom of the page.
5. Have a cup of coffee and wait for a couple of minutes, since running the
   instructions from **User data** might take some time. This means that even
   after the droplet was created successfully, you have to wait about five minutes.

## After the droplet is created

You can visit your newly created Convos installation by going to something like
**http://178.62.18.95/** in your browser, where "178.62.18.95" should be
replaced by the **IP address** you find on the
[droplets](https://cloud.digitalocean.com/droplets) page.

Note however that this is an insecure connection. There's also a secure
connection created, but this is unfortunately rejected in Google Chrome. You
can however try it out in Firefox: Just replace "http://" with "https://" in
the address bar.

A truly secure connection can be accomplished using
[Cloudflare](https://www.cloudflare.com/) or
[Let's encrypt](https://letsencrypt.org/), but that is too much information
to fit into this tutorial.

DNS is another thing, where you have a ton of providers to choose from, so
it's hard to put that into this tutorial as well. If you want a domain name,
we suggest [Cloudflare](https://www.cloudflare.com/) or
[Gandi](https://www.gandi.net/).

## Upgrading Convos

If a new Convos version is available, you can upgrade Convos by following these
instructions:

    # Replace 178.62.18.95 with your Droplets' IP address
    ssh root@178.62.18.95
    cd /opt/convos && git pull && ./script/convos install
    systemctl restart convos

Doing a refresh in your browser afterwards should give you the latest version
of Convos. You can check the current version number in the "Help" page.

## Got any issues or questions?

If you run into any issues, then don't hesitate to as us on either
[Twitter](https://twitter.com/convosby) or in the official support
channel on freenode, named [#convos](irc://chat.freenode.net/%23convos).

Enjoy your newly created Convos installation!

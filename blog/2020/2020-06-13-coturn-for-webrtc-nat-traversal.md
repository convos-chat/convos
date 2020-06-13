---
title: "Coturn for WebRTC NAT Traversal"
canonical: https://marcus.nordaaker.com/post/coturn-for-webrtc-nat-traversal/
---

This article will show you how to set up [Coturn](https://github.com/coturn/coturn). This is a service that allows hosts behind NAT to communicate peer to peer with webrtc. STUN is helping to negotiate port/ip and TURN will proxy the actual traffic if all else fails.

We're using this with [Convos](https://convos.chat/)' video IRC feature, but the same applies to other WebRTC projects.


## Installation {#installation}

I'll be assuming you're on Ubutunu for this tutorial, so users on other distros will have to adjust the setup for their environment. First we'll install the actual ubuntu package. If you don't already have it, you will also need letsencrypt to generate valid ssl certs.

    apt-install coturn certbot

Then we edit `/etc/turnserver.conf` - It should look roughly like this:

    listening-port=3478
    tls-listening-port=5349

    listening-ip=<server public interface>
    relay-ip=<Ip used for relaying>
    external-ip=<actual external ip>

    realm=example.org
    server-name=coturn.example.org

    fingerprint
    lt-cred-mech

    user username:pass

    cert=/etc/letsencrypt/live/coturn.example.org/fullchain.pem
    pkey=/etc/letsencrypt/live/coturn.example.org/privkey.pem
    cipher-list="ECDH+AESGCM:ECDH+CHACHA20:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:RSA+AESGCM:RSA+AES:!aNULL:!MD5:!DSS"

## Set up letsencrypt. {#set-up-letsencrypt-dot}

    $ sudo certbot certonly --standalone --preferred-challenges http \\
        --deploy-hook "systemctl restart coturn" \\
        -d coturn.example.com

certbort will automatically set up renewal of the certificate

Now let's enable the service. Add `TURNSERVER_ENABLED=1` to /etc/default/coturn and then
`systemctl start coturn`


## Convos configuration {#convos-configuration}

To use such a server with Convos, it requires a couple of environment variables to be set:

    Environment=CONVOS\_STUN=stun://user:pass@coturn.example.<5349>
    Environment=CONVOS\_TURN=turn://user:pas@coturn.example.<5349>

(Assuming you run Convos under systemd)

Remember to `systemctl daemon-reload` and `restart` after updating the service :)

If you're running convos a different way like under [Docker](https://convos.chat/doc/start#docker), adjust the relevant settings.

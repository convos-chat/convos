## NOTES:

We are assuming you've installed _Convos_ with the commands from the [Quick start guide](https://convos.chat/doc/start#quick-start-guide).

This systemd unit was tested on Ubuntu 20.04, but should work on all the distros with systemd support.

We are assuming you'll be using _Convos_ behind a reverse proxy. If that's not the case, change:

`CONVOS_REVERSE_PROXY=1` to `CONVOS_REVERSE_PROXY=0`

`LISTEN=http://127.0.0.1:8081` to `LISTEN=http://[::]:8081`
#
## Instructions

1 - Enable lingering for the user that will or is already running _Convos_, by executing the following command as **root**:

    loginctl enable-linger $USER

2 - Login as the user that will be or is already running _Convos_.

3 - As the user, type the following command to enable the systemd user directory (so you don't need to create it manually):

    systemctl --user enable enable systemd-tmpfiles-clean.timer

4 - You can disable this systemd timer, although it is harmless, with:

    systemctl --user disable enable systemd-tmpfiles-clean.timer

5 - Copy the _convos_user.service_ to `$HOME/.config/systemd/user/`.

6 - Reload the user systemd daemon with:

    systemctl --user daemon-reload

7 - Enable the systemd unit and start _Convos_ with:

    systemctl --user enable convos_user.service --now

8 - Watch your _Convos_ user(s) appearing on IRC.
#
## Useful commands

1 - To stop _Convos_:

    systemctl --user stop convos_user.service

2 - To start _Convos_:

    systemctl --user start convos_user.service

3 - To restart _Convos_ (after an update):

    systemctl --user restart convos_user.service
#
From  now on, your convos instance will be automatically started if your machine/computer is rebooted. 
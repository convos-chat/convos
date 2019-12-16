## Resources

* (Create your first snap)[https://tutorials.ubuntu.com/tutorial/create-first-snap]
* (The snapcraft syntax)[https://snapcraft.io/docs/build-snaps/syntax]
* (Common keywords)[https://snapcraft.io/docs/reference/plugins/common]
* (Commands, daemons and assets)[https://snapcraft.io/docs/build-snaps/metadata]

# Building and testing the snap

    - Install snapcraft `sudo snap install snapcraft --classic`
    - Clone convos repo
    - Run `snapcraft` to build the snap (this will install multipass for vm based building)

Other (unsorted) commands:

    $ snapcraft prime
    $ sudo snap try --devmode prime
    $ snap run --shell convos

## Resetting

    $ snapcraft clean
    $ snapcraft clean convos --step build
    $ sudo snap remove convos

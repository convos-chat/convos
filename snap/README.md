## Resources

* (Create your first snap)[https://tutorials.ubuntu.com/tutorial/create-first-snap]
* (The snapcraft syntax)[https://snapcraft.io/docs/build-snaps/syntax]
* (Common keywords)[https://snapcraft.io/docs/reference/plugins/common]
* (Commands, daemons and assets)[https://snapcraft.io/docs/build-snaps/metadata]

# Building and testing the snap

Make sure that Convos is checked out in your `$HOME` directory:

    $ ./snap/build.sh

Other (unsorted) commands:

    $ snapcraft prime
    $ sudo snap try --devmode prime
    $ snap run --shell convos

## Resetting

    $ snapcraft clean
    $ snapcraft clean convos --step build
    $ sudo snap remove convos

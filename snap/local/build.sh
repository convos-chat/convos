#!/bin/sh

if [ "$HOME/convos" != "$PWD" ]; then
  echo "Convos need to be cloned in $HOME";
  exit 1;
fi

if [ ! -e "snap/snapcraft.yaml" ]; then
  echo "This script need to be run from the project root";
  exit 1;
fi

set -x;
snap list convos;
sudo snapcraft cleanbuild;

if grep -q "confinement:[ ]*devmode" snap/snapcraft.yaml; then
  sudo snap install --devmode convos_*_amd64.snap;
else
  sudo snap install --dangerous convos_*_amd64.snap;
fi

snap list convos;

set +x;
echo "To release";
echo "\$ snapcraft push convos_*_amd64.snap --release=candidate";

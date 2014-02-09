#!/bin/sh

CURL=$(which curl);
PERL=$(which perl);
WGET=$(which wget);
TAR_GZ="https://codeload.github.com/Nordaaker/convos/tar.gz/release";

if [ -z $PERL ]; then
  echo "! Cannot install Convos: Cannot find 'perl' in PATH";
  exit 2;
fi

download () {
  if [ -n $CURL ]; then
    curl $TAR_GZ | tar zxvf -
  elif [ -n $WGET ]; then
    wget $TAR_GZ -O - | tar zxvf -
  else
    echo "! Cannot install Convos: Cannot find 'curl' or 'wget' in PATH";
    exit 2;
  fi
}

deps () {
  cd convos-release;

  if ./vendor/bin/carton; then
    echo "";
    echo "# Convos was installed successfully!";
  else
    EXIT_VALUE=$?
    echo "! Carton could not install dependencies. ($EXIT_VALUE)";
    exit $EXIT_VALUE;
  fi
}

post_message () {
  echo "";
  echo "# You can test convos by running the command below,";
  echo "# and then open http://localhost:3000 in your favorite browser.";
  echo "";
  echo "  cd $PWD && ./vendor/bin/carton exec script/convos daemon --listen http://*:3000";
  echo "";
  echo "# Visit http://convos.by for more information.";
  echo "";
}

download;
deps;
post_message;

exit 0;

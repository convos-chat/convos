#!/bin/sh

CURL=$(which curl);
GIT=$(which git);
PERL=$(which perl);
WGET=$(which wget);
REPO="https://github.com/Nordaaker/convos.git";
TAR_GZ="https://codeload.github.com/Nordaaker/convos/tar.gz/release";

if [ -z $PERL ]; then
  echo "! Cannot install Convos: Cannot find 'perl' in PATH";
  exit 2;
fi

deps () {
  if ./vendor/bin/carton; then
    echo "";
    echo "# Convos was installed successfully!";
    [ -n $GIT ] && git checkout cpanfile.snapshot
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

if [ -n $GIT ]; then
  if [ $(git init --help | grep repository | wc -l) -ge 1 ]; then
    $GIT clone --branch release --depth 1 --progress $REPO;
    cd convos;
  else
    GIT="";
  fi
fi

if [ -z $GIT ]; then
  if [ -n $CURL ]; then
    echo "! Could not find git. Will download Convos using curl";
    curl $TAR_GZ | tar zxvf -
  elif [ -n $WGET ]; then
    echo "! Could not find git. Will download Convos using wget";
    wget $TAR_GZ -O - | tar zxvf -
  else
    echo "! Cannot install Convos: Cannot find 'curl' or 'wget' in PATH";
    exit 2;
  fi
  cd convos-release;
fi

deps;
post_message;

exit 0;

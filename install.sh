#!/bin/sh
REPO="https://github.com/Nordaaker/convos.git";
TAR_GZ="https://github.com/Nordaaker/convos/archive/stable.tar.gz";

fetch_tar () {
  find_bin tar || return $?;
  find_bin curl || find_bin wget || return $?;
  mkdir convos;
  if [ -n "$curl" ]; then
    echo "> $curl -s -L $TAR_GZ | $tar xz -C convos --strip-components 1";
    $curl -s -L $TAR_GZ | $tar xz -C convos --strip-components 1;
  else
    echo "> $wget -q -O - $TAR_GZ | $tar xz -C convos --strip-components 1";
    $wget -q -O - $TAR_GZ | $tar xz -C convos --strip-components 1;
  fi
}

git_clone () {
  find_bin git || return $?;
  if [ -d convos ]; then
    cd convos;
    echo "> $git pull origin stable";
    $git pull origin stable;
    cd ..;
  else
    echo "> $git clone --branch stable $REPO";
    $git clone --branch stable $REPO;
  fi
}

find_bin () {
  bin=$(which $1);
  [ -z "$bin" ] && return 1;
  export $1="$bin";
}

missing () {
  echo "";
  echo "! Cannot install Convos: $1 is required.";
  echo "";
  exit 1;
}

find_bin perl || missing "perl";
git_clone || fetch_tar || missing "git, curl or wget";
echo "> $perl convos/script/convos install";
$perl convos/script/convos install;
exit $?;

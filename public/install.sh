#!/bin/sh
REPO="https://github.com/Nordaaker/convos.git";
TAR_GZ="https://github.com/Nordaaker/convos/archive/stable.tar.gz";

fetch_tar () {
  find_bin tar || return $?;
  find_bin curl || find_bin wget || return $?;
  mkdir convos;
  if [ -n "$curl" ]; then
    echo "\$ $curl -s -L $TAR_GZ | $tar xz -C convos --strip-components 1";
    $curl -s -L $TAR_GZ | $tar xz -C convos --strip-components 1;
  else
    echo "\$ $wget -q -O - $TAR_GZ | $tar xz -C convos --strip-components 1";
    $wget -q -O - $TAR_GZ | $tar xz -C convos --strip-components 1;
  fi
}

git_clone () {
  find_bin git || return $?;
  if [ -d convos ]; then
    cd convos;
    echo "\$ $git pull origin stable";
    $git pull origin stable;
    cd ..;
  else
    echo "\$ $git clone --branch stable $REPO";
    $git clone --branch stable $REPO;
  fi
}

find_bin () {
  bin=$(which $1);
  [ -z "$bin" ] && return 1;
  export $1="$bin";
}

cannot_install () {
  echo "";
  echo "! Cannot install Convos: $1";
  echo "";
  echo "See https://convos.chat/doc/faq#is-convos-supported-on-my-system";
  echo "for more information.";
  echo "";
  exit 1;
}

echo "Installing Convos...";
find_bin perl || cannot_install "perl is required.";
find_bin make || cannot_install "make is required.";
find_bin gcc  || cannot_install "gcc is required.";

git_clone || fetch_tar || cannot_install "git, curl or wget is required.";

echo "\$ $perl convos/script/convos install";
if $perl convos/script/convos install; then
  echo "";
  echo "Thank you for trying out Convos! Need help? Check";
  echo "out https://convos.chat/doc, or come talk to us in"
  echo "#convos on irc.freenode.net."
  echo "";
else
  cannot_install "Dependencies missing.";
fi

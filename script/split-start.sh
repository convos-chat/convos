#!/bin/sh

PORT=$1;
[ "x$PORT" = "x" ] && PORT=3000;

export MOJO_IRC_DEBUG=1
export WIRC_DEBUG=1
morbo script/web_irc --listen http://*:9876 --watch /dev/null &
PID=$!;

trap "kill $PID" INT
export SKIP_CONNECT=1
export DISABLE_PROXY=1
morbo script/web_irc --listen http://*:$PORT

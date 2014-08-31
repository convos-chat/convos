#!/bin/sh

[ -z $CONVOS_DEBUG ] && export CONVOS_DEBUG=1;
[ -z $MOJO_REDIS_DEBUG ] && export MOJO_REDIS_DEBUG=1;
[ -z $MOJO_IRC_DEBUG ] && export MOJO_IRC_DEBUG=1;
[ -z $CONVOS_REDIS_URL ] && export CONVOS_REDIS_URL="localhost";

exec script/convos backend $@;

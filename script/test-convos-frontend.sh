#!/bin/sh

[ -z $CONVOS_DEBUG ]            && export CONVOS_DEBUG=1
[ -z $CONVOS_MANUAL_BACKEND ]   && export CONVOS_MANUAL_BACKEND=1
[ -z $CONVOS_REDIS_URL ]        && export CONVOS_REDIS_URL="localhost"
[ -z $MOJO_ASSETPACK_NO_CACHE ] && export MOJO_ASSETPACK_NO_CACHE=1
[ -z $MOJO_IRC_DEBUG ]          && export MOJO_IRC_DEBUG=1
[ -z $MOJO_LOG_LEVEL ]          && export MOJO_LOG_LEVEL=debug
[ -z $MOJO_REDIS_DEBUG ]        && export MOJO_REDIS_DEBUG=1

exec morbo script/convos $@

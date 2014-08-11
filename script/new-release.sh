#!/usr/bin/sh
export CONVOS_REDIS_URL="test";

rm public/packed/c-*;
prove -vl t/release-production.t;

for i in public/packed/c-*; do
  git add --force $i;
done

rsync -va templates public lib/Convos/;

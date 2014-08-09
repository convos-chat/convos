#!/usr/bin/sh
export CONVOS_REDIS_URL="test";

rm public/packed/*;
prove -vl t/release-production.t;

for i in public/packed/*; do
  git add --force $i;
done

rsync -va templates public lib/Convos/;

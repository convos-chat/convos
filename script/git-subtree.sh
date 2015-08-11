#!/bin/sh
# The purpose of this script is to maintain the subtrees under vendor/.
# This script exists because of an bug in git-stree making "pull" not work.
# This script also solves the issue with sharing the git-stree config.
# Note: Part of this code is copy/paste from git-stree.

REMOTE_NAME="${1:-materialize}";
GIT_BRANCH=${2:-master};
GIT_REPO="";
PREFIX="vendor/$REMOTE_NAME";
LATEST_FILE="vendor/.$REMOTE_NAME.latest";

case "$REMOTE_NAME" in
  materialize) GIT_REPO="https://github.com/Dogfalo/materialize.git" ;;
  *) echo "Unknown project name $REMOTE_NAME"; exit 1 ;;
esac

function commit () {
  if git diff --cached --quiet; then
    echo "Pulled $REMOTE_NAME/$GIT_BRANCH, but no updates found."
  else
    msg_file="$(git rev-parse --git-dir)/SQUASH_MSG"
    latest_sync=$(cat $LATEST_FILE);
    [ -n "$latest_sync" ] || latest_sync='(use all)';
    git log --format='%H' -n1 $REMOTE_NAME/$GIT_BRANCH > $LATEST_FILE;
    git add $LATEST_FILE;
    msg="Pulled $REMOTE_NAME/$GIT_BRANCH ($GIT_REPO)"$'\n\n'"$(sed "/^commit $latest_sync/,100000d" "$msg_file")";
    echo "$msg" > "$msg_file";
    git commit -F "$msg_file";
  fi
}

if [ "x$(git remote -v | grep "^$REMOTE_NAME")" = "x" ]; then
  git remote add $REMOTE_NAME $GIT_REPO || exit $?;
fi

git remote update $REMOTE_NAME;

if [ -e $LATEST_FILE ]; then
  git merge -s subtree --no-commit --squash $REMOTE_NAME/$GIT_BRANCH;
  commit;
else
  mkdir -p $PREFIX || exit $?;
  git merge -s ours --no-commit --squash $REMOTE_NAME/$GIT_BRANCH;
  git read-tree --prefix=$PREFIX -u $REMOTE_NAME/$GIT_BRANCH;
  commit;
fi

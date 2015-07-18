#!/bin/sh
#
# This script is used for auto maintaining
# - merging with original repo
# - regenerating sources and headers
# - push changes to repository
#
ORIGINAL_REPO_URL=https://github.com/nigels-com/glew.git
if [ -z "$WORKSPACE" ]; then
  echo "Set WORKSPACE as default value"
  SCRIPT_PATH=$(readlink -f "$0")
  WORKSPACE=$(dirname "$SCRIPT_PATH")
  echo "WORKSPACE=$WORKSPACE"
fi

if [ -z "$TEST_MODE" -o "$TEST_MODE" != "false" ]; then
  PUSH_ARG="--dry-run"
else
  PUSH_ARG=""
fi

prepare () {
  if [ -d "$WORKSPACE/auto/registry" ]; then
    cd "$WORKSPACE/auto/registry"
    echo "Update registry repo"
    git pull
  fi
  cd "$WORKSPACE"
}

source_update () {
  GIT_BRANCH_NAME=$1
  # for recovery when test mode.
  PUSH_COUNT=0

  echo "Checkout branch ${GIT_BRANCH_NAME}"
  if [ `git branch | grep ${GIT_BRANCH_NAME} | wc -l` = 0 ]; then
    git checkout origin/${GIT_BRANCH_NAME} -b ${GIT_BRANCH_NAME}
  else
    git checkout -f $GIT_BRANCH_NAME
    git pull -s recursive -X theirs --no-edit --progress origin
  fi
  echo "Pull from origin repository(${ORIGINAL_REPO_URL})"
  BEFORE_COMMIT=`git rev-parse HEAD`
  git pull -s recursive -X theirs --no-edit --commit --progress original_repo ${GIT_BRANCH_NAME}
  AFTER_COMMIT=`git rev-parse HEAD`
  if [ "$BEFORE_COMMIT" != "$AFTER_COMMIT" ]; then
    echo "Source Updated"
    git commit --amend -m "Merge ${ORIGINAL_REPO_URL} into ${GIT_BRANCH_NAME} HEAD at $(TZ=GMT date)"
    git push ${PUSH_ARG} origin $GIT_BRANCH_NAME:$GIT_BRANCH_NAME
    PUSH_COUNT=$((PUSH_COUNT + 1))
  fi

  echo "Fetch tags from origin repository(${ORIGINAL_REPO_URL})"
  BEFORE_TAG_COUNT=`git tag | wc -l`
  git fetch --tags --progress original_repo
  AFTER_TAG_COUNT=`git tag | wc -l`
  if [ ! $BEFORE_TAG_COUNT -eq $AFTER_TAG_COUNT ]; then
    echo "Tags updated"
    git push ${PUSH_ARG} --tags origin
    PUSH_COUNT=$((PUSH_COUNT + 1))
  fi

  cd "$WORKSPACE/auto"
  echo "CleanUp"
  make clean
  echo "Generated Source Update"
  cd "$WORKSPACE"
  make extensions
  echo "Diff sources"
  git add --force src/glew.c src/glewinfo.c include/GL/* doc/* build/*.rc
  # Check is there any staged changes?
  if [ `git diff --cached | wc -c` -ne 0 ]; then
    # Commit and push it
    echo "Sources updated"
    git commit -m"Generate Sources of ${GIT_BRANCH} updated at $(TZ=GMT date)"
    echo "Push to repository"
    git push ${PUSH_ARG} origin ${GIT_BRANCH_NAME}:${GIT_BRANCH_NAME}
    PUSH_COUNT=$((PUSH_COUNT + 1))
  else
    echo "Differences Not found"
  fi

  # when test mode, reset created commits
  if [ -n "$PUSH_ARG" ]; then
    echo "Reset commits"
    git reset --hard HEAD~${PUSH_COUNT}
  fi
}

# add remote when original repo is not found in local repo
if [ `git remote | grep original_repo | wc -l` = 0 ]; then
  git remote add original_repo ${ORIGINAL_REPO_URL}
fi

git fetch original_repo

branch_list () {
  eval "$2=\"`git branch -r | grep $1 | sed "s/\s\+$1\///g" | sed ':a;N;$!ba;s/\n/ /g'`\""
}

contains () {
  local OUT=$1
  shift
  local seeking=$1
  shift
  local in=1
  for element in $*; do
    if [ $element = $seeking ]; then
      in=0
      break
    fi
  done
  eval "$OUT=\"${in}\""
}

#branch_list original_repo ORIGINAL_REPO_BRANCH_LIST
#branch_list origin ORIGIN_REPO_BRANCH_LIST

join () {
  local OUT=$1
  shift
  local value="`echo $* | sed "s/ /\n/g" | sort -u | sed ':a;N;$!ba;s/\n/ /g'`"
  eval "$OUT=\"${value}\""
}

#join ALL_BRANCH_LIST $ORIGINAL_REPO_BRANCH_LIST $ORIGIN_REPO_BRANCH_LIST
#
#for branch in $ALL_BRANCH_LIST; do
#  contains IN_ORIGINAL_REPO $branch $ORIGINAL_REPO_BRANCH_LIST
#  if [ $IN_ORIGINAL_REPO = 1 ]; then
#    if [ $branch != "glew-cmake-release" ]; then
#      git push ${PUSH_ARG} origin :$branch
#    fi
#  else
#    source_update $branch
#  fi
#done

prepare

source_update master

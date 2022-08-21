#!/bin/bash
#
# This script is used for auto maintaining
# - merging with original repo
# - regenerating sources and headers
# - push changes to repository
#
set -euxo pipefail

ORIGINAL_REPO_URL=https://github.com/nigels-com/glew.git
absolute_path () {
  local TARGET_FILE=$1
  shift
  local OUT=$1
  shift
  pushd `dirname $TARGET_FILE`
  TARGET_FILE=`basename $TARGET_FILE`

  # Iterate down a (possible) chain of symlinks
  while [ -L "$TARGET_FILE" ]
  do
    TARGET_FILE=`readlink $TARGET_FILE`
    cd `dirname $TARGET_FILE`
    TARGET_FILE=`basename $TARGET_FILE`
  done

  # Compute the canonicalized name by finding the physical path 
  # for the directory we're in and appending the target file.
  PHYS_DIR=`pwd -P`
  RESULT=$PHYS_DIR/$TARGET_FILE
  eval "$OUT=\"${RESULT}\""
  popd
}

if [ -z "${WORKSPACE:-}" ]; then
  echo "Set WORKSPACE as default value"
  absolute_path "$0" SCRIPT_PATH
  WORKSPACE=$(dirname "$SCRIPT_PATH")
  WORKSPACE=$(dirname "$WORKSPACE")
  echo "WORKSPACE=$WORKSPACE"
fi

if [ -z "${TEST_MODE:-}" -o "${TEST_MODE:-}" != "false" ]; then
  PUSH_ARG="--dry-run"
else
  PUSH_ARG=""
fi

source_update () {
  GIT_BRANCH_NAME=$1
  # for recovery when test mode.
  PUSH_COUNT=0

  echo "Checkout branch ${GIT_BRANCH_NAME}"
  git reset --hard
  git clean -f .
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
    git checkout "original_repo/${GIT_BRANCH_NAME}" -- README.md
    git mv -f README.md README_glew.md
    git checkout $BEFORE_COMMIT -- README.md
    git add -f README.md README_glew.md
    git commit --amend -m "Merge ${ORIGINAL_REPO_URL} into ${GIT_BRANCH_NAME} HEAD at $(TZ=GMT date)"
    git push ${PUSH_ARG} origin $GIT_BRANCH_NAME:$GIT_BRANCH_NAME
    PUSH_COUNT=$((PUSH_COUNT + 1))
  fi

  cd "$WORKSPACE/auto"
  echo "CleanUp"
  make clean
  cd "$WORKSPACE/auto"
  REGISTRIES=`find . -name .git -type d -exec dirname {} \;`
  for REGISTRY in $REGISTRIES
  do
    rm -rf $REGISTRY
  done
  cd "$WORKSPACE"
  echo "Generated Source Update"
  make extensions
  echo "Diff sources"
  git add --force src/glew.c src/glewinfo.c include/GL/* doc/* build/*.rc
  # Check is there any staged changes?
  if [ `git diff --cached | wc -c` -ne 0 ]; then
    # Commit and push it
    echo "Sources updated"
    git commit -m"Generate Sources of ${GIT_BRANCH_NAME} updated at $(TZ=GMT date)"
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

import_tags () {
  echo "Fetch tags from origin repository(${ORIGINAL_REPO_URL})"
  BEFORE_TAG_COUNT=`git tag | wc -l | sed "s/^ \+//"`
  git fetch --tags --progress original_repo
  AFTER_TAG_COUNT=`git tag | wc -l | sed "s/^ \+//"`
  NEW_VERSION_TAGS=`diff -u <(git tag | grep glew-cmake- | sed s/glew-cmake/glew/) <(git tag | grep "glew-[0-9]") | grep ^+ | sed 1d | sed s/^+// || true`
  if [ ! $BEFORE_TAG_COUNT -eq $AFTER_TAG_COUNT -o ! -z "$NEW_VERSION_TAGS" ]; then
    echo "Tags updated"
    git push ${PUSH_ARG} --tags origin

    git checkout glew-cmake-release
    for TAG in $NEW_VERSION_TAGS
    do
      echo "Import $TAG"
      git checkout $TAG -- .
      git mv -f README.md README_glew.md
      git checkout master -- CMakeLists.txt GeneratePkgConfig.cmake README.md
      cd "$WORKSPACE/auto"
      COMMIT_TIME=`git log -1 $TAG --format=%ct`
      echo "Patch perl scripts for new version"
      find bin -name '*.pl' -exec sed -i "s/do 'bin/use lib '.';\ndo 'bin/" {} \;
      echo "Remove registries"
      REGISTRIES=`find . -name .git -type d -exec dirname {} \;`
      for REGISTRY in $REGISTRIES
      do
        rm -rf $REGISTRY
      done
      echo "Run code generation to download registries"
      make clean
      cd "$WORKSPACE"
      make extensions
      echo "Rewind registry repos"
      cd "$WORKSPACE/auto"
      make clean
      REGISTRIES=`find . -name .git -type d -exec dirname {} \;`
      for REGISTRY in $REGISTRIES
      do
	      cd "$WORKSPACE/auto/$REGISTRY"
        PROPER_COMMIT=`git log --until=$COMMIT_TIME -1 --format=%H`
        git checkout --force $PROPER_COMMIT
        find . -name .dummy -exec touch {} \;
      done
      echo "CleanUp for tag"
      cd "$WORKSPACE/auto"
      # remove previous data
      rm -rf extensions
      echo "Generate source code"
      make
      cd "$WORKSPACE"
      git reset
      git add --force src include doc CMakeLists.txt GeneratePkgConfig.cmake build/*.rc config/version
      if [ `git diff --cached | wc -c` -ne 0 ]; then
        git commit -m"glew-cmake release from $TAG"
        NEW_TAG=`echo $TAG | sed s/glew-/glew-cmake-/`
        git tag $NEW_TAG
      else
        echo "No difference! something wrong"
      fi
    done

    git push ${PUSH_ARG} origin glew-cmake-release
    if [ -z "$PUSH_ARG" ]; then
      git push --tags ${PUSH_ARG} origin
    fi

    # when test mode, reset created commits
    if [ -n "$PUSH_ARG" ]; then
      echo "Reset commits for tags"
      for TAG in $NEW_VERSION_TAGS
      do
        NEW_TAG=`echo $TAG | sed s/glew-/glew-cmake-/`
        git tag -d $NEW_TAG
        git reset --hard HEAD~1
      done
    fi
  fi
}

# add remote when original repo is not found in local repo
if [ `git remote | grep original_repo | wc -l` = 0 ]; then
  git remote add original_repo ${ORIGINAL_REPO_URL}
fi

git fetch -n original_repo

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

source_update master

import_tags
#!/usr/bin/env bash
# usage: build_pub_repo_v2.sh local_repo_name
# example: build_pub_repo_v2.sh athena_working

# fileglob of private files and directories
# the filename needs to include the path with respect
# to the top of the Git repo
# Here is an example for excluding multiple directories
# PRIVATE="{pub,private,inputs}"
# Note: for a single directory, you should not use the curly
# brackets e.g.
# incorrect: PRIVATE="{pub}"
#   correct: PRIVATE="pub"
PRIVATE="{pub,tst/ci,.travis.yml,.github,CONTRIBUTING.md,CHANGELOG.md}"

# Repo HTTPS URLs:
# PRIV_REPO_URL="https://github.com/PrincetonUniversity/athena.git"
# PUB_REPO_URL="https://github.com/PrincetonUniversity/athena-public-version.git"
# Repo SSH URLs:
PRIV_REPO_URL="git@github.com:PrincetonUniversity/athena.git"
PUB_REPO_URL="git@github.com:PrincetonUniversity/athena-public-version.git"

# data for this script
## branch on remote private repo from which to create public release
## (must be an actual branch and not a tag in order to rewrite local history/filter-branch)
PRIV_REPO_PRIV_BRANCH="release/1.1.1"
## local workspace branch for drafting the public release
PRIV_REPO_PUB_BRANCH="public"

PUB_REMOTE_NAME="public_repo"
PUB_REPO_BRANCH="master"

PRE_PUSH_HOOK="pub/pre-push"
POST_COMMIT_HOOK="pub/post-commit"

LOCAL_REPO_NAME=$1

# clone private repo
git clone $PRIV_REPO_URL $LOCAL_REPO_NAME
cd $LOCAL_REPO_NAME
git pull --tags

# Copy the pre-push hook to the cloned repo
if [ -e $PRE_PUSH_HOOK ]
then
    cp $PRE_PUSH_HOOK .git/hooks/
    chmod 766 .git/hooks/pre-push
else
    echo the pre-push hook does not exists
    exit 1
fi

# get the private repo branch to be made public
# (if this is called after the "git filter-branch ... " command, the checkout
#  will return a non-filtered copy of the remote branch)
git checkout $PRIV_REPO_PRIV_BRANCH

# clean up the files and directories we don't want to make public
git filter-branch --force --index-filter \
    "git rm -r --cached --ignore-unmatch $PRIVATE" \
    --prune-empty --tag-name-filter cat -- --all

# add the public_repo remote
git remote add $PUB_REMOTE_NAME $PUB_REPO_URL
git fetch --all # will not overwrite the filtered tags

# Create the "public" branch by pulling the master branch of
# the public repo. The "public" branch of the private repo is
# now tracking the master branch of the public repo so that
# "git push" and "git pull" will be towards public_repo:master
git checkout -b $PRIV_REPO_PUB_BRANCH
git branch -u $PUB_REMOTE_NAME/$PUB_REPO_BRANCH $PRIV_REPO_PUB_BRANCH
# squash commits on previous public version
git reset --soft $PUB_REMOTE_NAME/$PUB_REPO_BRANCH

# configure git so it pushes from the public branch to public_repo:master
git config push.default upstream

# purge the deleted files from the packfile
git for-each-ref --format='delete %(refname)' refs/original | git update-ref --stdin
git reflog expire --expire=now --all
git gc --aggressive --prune=now

# git diff public..public_repo/master
# git commit -m "Second public release of Athena++"
# git branch -vv

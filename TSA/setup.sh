#! /bin/bash

# ------------
# IMPORTANT!
#
# This script uses an environment variable named 'email' to properly
# configure git repos upon checkout. If you don't have it set in your
# environment, the email of the git repos will be set to an empty value.
# For best experience, set the variable in your .bashrc, .zshrc, etc.
#
# export email="myemail@company.com"
# ------------

# pull the main branch of a given git repository.
# User will be prompted for manual action if another branch is checked out or a problem occurs.
# $1 - name of the repo to pull.
function pull() {
  local repo=$1

  pushd "${repo}"

  local branch=`git rev-parse --abbrev-ref HEAD`
  if [ $branch == "main" ]; then
    echo "Pulling ${repo}/main..."
    git pull origin main || read -p "Could not pull ${repo}/main. Fix the issue and press ENTER to continue:"
  else
    echo "${repo}/${branch} is checked out"
    read -p "Pull ${repo} manually now or press ENTER to skip:"
  fi

  popd
}

# getServices clones or pulls the services with separate repos
# in ${GOPATH}/src/gitlab.eclipse.org/eclipse/xfsc/tsa
function getServices() {
  local XFSC_TSA_DIR="${GOPATH}/src/gitlab.eclipse.org/eclipse/xfsc/tsa"
  mkdir -p "${XFSC_TSA_DIR}" && cd "$_"

  local services=(
    "cache"
    "infohub"
    "login"
    "policy"
    "signer"
    "task"
  )

  for repo in ${services[@]}; do
    echo

    if [ -d "${repo}" ]; then
      pull $repo
      continue
    fi

    mkdir -p "$XFSC_TSA_DIR/$repo" && pushd "$XFSC_TSA_DIR/$repo"

    echo "Cloning $repo repository to $XFSC_TSA_DIR/$repo"
    git clone "ssh://git@gitlab.eclipse.org/eclipse/xfsc/tsa/${repo}.git" .
    if [ ! -d "./vendor" ]; then
      go mod tidy && go mod vendor # download dependencies to vendor
    fi


    git config user.email $EMAIL && popd
  done
}

getServices

echo
echo "All repos are updated successfully."

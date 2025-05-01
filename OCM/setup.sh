#! /bin/bash

if [[ "$1" != "" ]]; then
    CHECKOUT_BRANCH="$1"
else
    CHECKOUT_BRANCH='main'
fi

ROOT_DIR=".."

# ------------
# checkout the main branch of a given git repository.
# User will be prompted for manual action if another branch is checked out or a problem occurs.
# $1 - name of the repo to pull.
function checkout() {
  local repo=$1
  pushd "${ROOT_DIR}/${repo}"

  echo "Checkout ${repo}/${CHECKOUT_BRANCH}..."
  git fetch
  git checkout "${CHECKOUT_BRANCH}" || read -p "Could not checkout ${repo}/${CHECKOUT_BRANCH}. Fix the issue and press ENTER to continue:"
  git pull origin "${CHECKOUT_BRANCH}" || read -p "Could not pull ${repo}/${CHECKOUT_BRANCH}. Fix the issue and press ENTER to continue:"

  popd
}

# getServices clones or pulls the services with separate repos
# in .. (Parent folder)
function getServices() {
  local services=(
    "proof-manager"
    "connection-manager"
    "principal-manager"
    "attestation-manager"
    "ssi-abstraction"
#    "bdd"
    "profile-manager"
  )

  for repo in ${services[@]}; do
    echo ""
    if [ -d "${ROOT_DIR}/${repo}" ]; then
      checkout $repo
      continue
    fi

    mkdir -p "$ROOT_DIR/$repo" && pushd "$ROOT_DIR/$repo"

    echo "Cloning $repo repository to $ROOT_DIR/$repo"
    git clone "ssh://git@gitlab.eclipse.org:eclipse/xfsc/ocm/${repo}.git" .

    checkout $repo
  done
}

getServices

echo
echo "All repos are updated successfully."

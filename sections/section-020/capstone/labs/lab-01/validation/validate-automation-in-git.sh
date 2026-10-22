#!/usr/bin/env bash
# PASS when: confirms the automation author, push branch and update path.
set -uo pipefail

BIN_DIR="/usr/local/bin"
[ -w "$BIN_DIR" ] || BIN_DIR="$HOME/.local/bin"
export PATH="$BIN_DIR:$PATH"

sync_from_git() {
  # sync_from_git: makes Flux apply the current Git state now, so anything
  # changed by hand in the cluster is put back to what Git says.
  flux reconcile kustomization fleet --with-source >/dev/null 2>&1 || true
}

in_fleet_inventory() {
  # in_fleet_inventory ID: true when the Flux Kustomization fleet applied the object.
  kubectl -n flux-system get kustomization fleet \
    -o jsonpath='{range .status.inventory.entries[*]}{.id}{"\n"}{end}' 2>/dev/null | grep -qx "$1"
}

GIT_USER="gitops"
GIT_PASSWORD="gitops-password"
REPO="fleet"

git_raw() {
  # git_raw PATH: prints one file from gitops/fleet on main, read through the Gitea API.
  kubectl -n gitea exec deploy/tester -- \
    curl -fsS -u "$GIT_USER:$GIT_PASSWORD" \
    "http://gitea-http.gitea:3000/api/v1/repos/$GIT_USER/$REPO/raw/$1?ref=main" 2>/dev/null
}

last_commit_email() {
  # last_commit_email: prints the author email of the newest commit on main.
  kubectl -n gitea exec deploy/tester -- sh -c \
    "curl -fsS -u '$GIT_USER:$GIT_PASSWORD' 'http://gitea-http.gitea:3000/api/v1/repos/$GIT_USER/$REPO/commits?sha=main&limit=1' | jq -r '.[0].commit.author.email'" 2>/dev/null
}

last_change_email() {
  # last_change_email PATH: prints the author email of the newest commit on main that changed PATH.
  kubectl -n gitea exec deploy/tester -- sh -c \
    "curl -fsS -u '$GIT_USER:$GIT_PASSWORD' 'http://gitea-http.gitea:3000/api/v1/repos/$GIT_USER/$REPO/commits?sha=main&path=$1&limit=1' | jq -r '.[0].commit.author.email'" 2>/dev/null
}

push_podinfo_tag() {
  # push_podinfo_tag TAG: copies podinfo TAG from ghcr.io into the lab registry.
  kubectl -n registry exec deploy/registry-tools -- \
    regctl image copy "ghcr.io/stefanprodan/podinfo:$1" "registry.localtest.me:5000/podinfo:$1"
}

retag_image() {
  # retag_image REPOSITORY FROM TO: adds tag TO to the image that tag FROM
  # points at, in one repository of the lab registry.
  kubectl -n registry exec deploy/registry-tools -- \
    regctl image copy "registry.localtest.me:5000/$1:$2" "registry.localtest.me:5000/$1:$3"
}

sync_from_git
if ! in_fleet_inventory "flux-system_podinfo_image.toolkit.fluxcd.io_ImageUpdateAutomation"; then
  echo "FAIL: the ImageUpdateAutomation podinfo is not applied by the Flux Kustomization fleet. Commit it under clusters/kind."
  exit 1
fi
EMAIL="$(kubectl -n flux-system get imageupdateautomation podinfo -o jsonpath='{.spec.git.commit.author.email}')"
if [ "$EMAIL" != "fluxcdbot@example.com" ]; then
  echo "FAIL: the automation commits as '${EMAIL:-nobody}'; the task asks for fluxcdbot@example.com."
  exit 1
fi
PUSH="$(kubectl -n flux-system get imageupdateautomation podinfo -o jsonpath='{.spec.git.push.branch}')"
if [ -n "$PUSH" ] && [ "$PUSH" != "main" ]; then
  echo "FAIL: the automation pushes to the branch '$PUSH'. Flux applies main, so releases must land on main."
  exit 1
fi
UPDATE_PATH="$(kubectl -n flux-system get imageupdateautomation podinfo -o jsonpath='{.spec.update.path}')"
case "$UPDATE_PATH" in
  ""|"./"|"."|"./apps"|"./apps/"|"./apps/podinfo"|"./apps/podinfo/"|"apps"|"apps/podinfo") ;;
  *) echo "FAIL: the automation updates the path '$UPDATE_PATH', which does not hold apps/podinfo/kustomization.yaml."; exit 1 ;;
esac
echo "PASS: the ImageUpdateAutomation podinfo comes from Git, commits as fluxcdbot@example.com and pushes to main under '${UPDATE_PATH:-the repository root}'."
exit 0

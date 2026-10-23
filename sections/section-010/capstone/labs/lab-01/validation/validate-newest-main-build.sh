#!/usr/bin/env bash
# PASS when: adds a newer main build and a pull request build and confirms the policy follows the main build.
set -uo pipefail
# grep -q stops reading at the first match; under pipefail the command
# writing into the pipe then fails with SIGPIPE and a match looks like a
# failure. This wrapper reads all input instead and keeps grep's exit status.
grep() {
  local arg quiet=0 args=()
  for arg in "$@"; do
    case "$arg" in
      --quiet|--silent) quiet=1 ;;
      --*) args+=("$arg") ;;
      -*q*) quiet=1; [ "$arg" = "-q" ] || args+=("${arg//q/}") ;;
      *) args+=("$arg") ;;
    esac
  done
  if [ "$quiet" = 1 ]; then command grep "${args[@]}" >/dev/null; else command grep "$@"; fi
}

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
if ! in_fleet_inventory "flux-system_podinfo-main_image.toolkit.fluxcd.io_ImagePolicy"; then
  echo "FAIL: the ImagePolicy podinfo-main is not applied by the Flux Kustomization fleet. Change it in Git."
  exit 1
fi
# A newer main build and a much newer pull request build. Only the main build counts.
retag_image podinfo-builds main-0c1d2e3-1760007200 main-aaaaaaa-1760010800 >/dev/null 2>&1 &&
  retag_image podinfo-builds main-0c1d2e3-1760007200 pr-42-bbbbbbb-1760099999 >/dev/null 2>&1 || {
  echo "FAIL: could not add the new build tags to the lab registry."
  exit 1
}
flux reconcile image repository podinfo-builds -n flux-system >/dev/null 2>&1 || true

CHOSEN=""
for _ in $(seq 1 30); do
  CHOSEN="$(kubectl -n flux-system get imagepolicy podinfo-main -o jsonpath='{.status.latestRef.tag}' 2>/dev/null)"
  [ "$CHOSEN" = "main-aaaaaaa-1760010800" ] && break
  sleep 3
done
if [ "$CHOSEN" != "main-aaaaaaa-1760010800" ]; then
  echo "FAIL: after a newer main build and a pull request build were added, the ImagePolicy podinfo-main chose '${CHOSEN:-nothing}'. It must choose main-aaaaaaa-1760010800."
  exit 1
fi
echo "PASS: the ImagePolicy podinfo-main follows the newest main build by its timestamp and ignores pull request builds."
exit 0

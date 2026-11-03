#!/usr/bin/env bash
# PASS when: confirms the automation is not suspended and the Provider and Alert come from Git.
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
if ! in_fleet_inventory "flux-system_podinfo_image.toolkit.fluxcd.io_ImageUpdateAutomation"; then
  echo "FAIL: the ImageUpdateAutomation podinfo is not applied by the Flux Kustomization fleet."
  exit 1
fi
SUSPENDED="$(kubectl -n flux-system get imageupdateautomation podinfo -o jsonpath='{.spec.suspend}')"
if [ "$SUSPENDED" = "true" ]; then
  echo "FAIL: the ImageUpdateAutomation podinfo is still suspended. Change the file in Git; a flux resume alone is undone at the next sync."
  exit 1
fi
if ! in_fleet_inventory "flux-system_image-events_notification.toolkit.fluxcd.io_Provider"; then
  echo "FAIL: no Provider named image-events is applied by the Flux Kustomization fleet."
  exit 1
fi
if ! in_fleet_inventory "flux-system_image-updates_notification.toolkit.fluxcd.io_Alert"; then
  echo "FAIL: no Alert named image-updates is applied by the Flux Kustomization fleet."
  exit 1
fi
PROVIDER="$(kubectl -n flux-system get alert image-updates -o jsonpath='{.spec.providerRef.name}')"
if [ "$PROVIDER" != "image-events" ]; then
  echo "FAIL: the Alert image-updates sends to '${PROVIDER:-no provider}', not to the Provider image-events."
  exit 1
fi
SOURCES="$(kubectl -n flux-system get alert image-updates -o jsonpath='{range .spec.eventSources[*]}{.kind}/{.name}{"\n"}{end}')"
for SOURCE in ImageUpdateAutomation/podinfo ImagePolicy/podinfo ImageRepository/podinfo; do
  if ! printf '%s\n' "$SOURCES" | grep -qx "$SOURCE"; then
    echo "FAIL: the Alert image-updates does not watch $SOURCE. It watches: ${SOURCES:-nothing}"
    exit 1
  fi
done
echo "PASS: the automation runs, and the Alert image-updates sends events for the automation, the policy and the repository to the Provider image-events."
exit 0

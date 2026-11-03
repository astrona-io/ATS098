#!/usr/bin/env bash
# PASS when: confirms the ImageRepository podinfo comes from Git, uses a Secret for credentials and scans the private registry.
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
if ! in_fleet_inventory "flux-system_podinfo_image.toolkit.fluxcd.io_ImageRepository"; then
  echo "FAIL: the ImageRepository podinfo is not applied by the Flux Kustomization fleet. Change it in Git, under clusters/kind."
  exit 1
fi
if ! git_raw clusters/kind/image-podinfo.yaml | grep -q 'secretRef:'; then
  echo "FAIL: clusters/kind/image-podinfo.yaml in Git has no secretRef. The cluster must match Git."
  exit 1
fi
SECRET="$(kubectl -n flux-system get imagerepository podinfo -o jsonpath='{.spec.secretRef.name}' 2>/dev/null)"
if [ -z "$SECRET" ]; then
  echo "FAIL: the ImageRepository podinfo has no secretRef."
  exit 1
fi
TYPE="$(kubectl -n flux-system get secret "$SECRET" -o jsonpath='{.type}' 2>/dev/null)"
if [ "$TYPE" != "kubernetes.io/dockerconfigjson" ]; then
  echo "FAIL: the Secret '$SECRET' in flux-system is missing or is not of type kubernetes.io/dockerconfigjson."
  exit 1
fi
flux reconcile image repository podinfo -n flux-system >/dev/null 2>&1 || true
COUNT=""
for _ in $(seq 1 30); do
  COUNT="$(kubectl -n flux-system get imagerepository podinfo -o jsonpath='{.status.lastScanResult.tagCount}' 2>/dev/null)"
  [ -n "$COUNT" ] && [ "$COUNT" -ge 3 ] 2>/dev/null && break
  sleep 3
done
if [ -z "$COUNT" ] || [ "$COUNT" -lt 3 ] 2>/dev/null; then
  echo "FAIL: the scan of the private registry found '${COUNT:-no}' tags. It must find the three tags that exist."
  exit 1
fi
echo "PASS: the ImageRepository podinfo scans the private registry with the Secret '$SECRET' and finds $COUNT tags."
exit 0

#!/usr/bin/env bash
# PASS when: adds 6.15.1, 6.16.0-rc.2 and 7.0.0 and confirms the policy chooses 6.15.1.
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

# Add a newer stable 6.x tag, a newer release candidate and a 7.x release.
# Only 6.15.1 fits "the newest stable 6.x release".
for new_tag in 6.15.1 6.16.0-rc.2 7.0.0; do
  retag_image podinfo 6.15.0 "$new_tag" >/dev/null 2>&1 || {
    echo "FAIL: could not add the tag $new_tag to the lab registry."
    exit 1
  }
done
flux reconcile image repository podinfo -n flux-system >/dev/null 2>&1 || true

CHOSEN=""
for _ in $(seq 1 30); do
  CHOSEN="$(kubectl -n flux-system get imagepolicy podinfo -o jsonpath='{.status.latestRef.tag}' 2>/dev/null)"
  [ "$CHOSEN" = "6.15.1" ] && break
  sleep 3
done
if [ "$CHOSEN" != "6.15.1" ]; then
  echo "FAIL: after adding 6.15.1, 6.16.0-rc.2 and 7.0.0, the ImagePolicy podinfo chose '${CHOSEN:-nothing}'. It must choose 6.15.1."
  exit 1
fi
echo "PASS: the ImagePolicy podinfo follows the newest stable 6.x tag and skips release candidates and 7.x."
exit 0

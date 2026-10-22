#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so the lab stays broken for the student.
# Taken from solution.md - if one changes, change the other.
#
# `astrona test` has no port-forward to Gitea, so the corrected files in
# solution/repo/ are written to Git through the Gitea API from the tester pod.
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOLUTION_REPO="$SCRIPT_DIR/repo"

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

put_file() {
  # put_file REPO_PATH LOCAL_FILE MESSAGE: creates or updates one file on main
  # through the Gitea API, called from the tester pod.
  local path="$1" file="$2" message="$3" content sha body method
  content="$(base64 < "$file" | tr -d '\n')"
  sha="$(kubectl -n gitea exec deploy/tester -- sh -c \
    "curl -fsS -u '$GIT_USER:$GIT_PASSWORD' http://gitea-http.gitea:3000/api/v1/repos/$GIT_USER/$REPO/contents/$path 2>/dev/null | jq -r '.sha // empty'" || true)"
  if [ -n "$sha" ]; then
    body="{\"content\":\"$content\",\"message\":\"$message\",\"branch\":\"main\",\"sha\":\"$sha\"}"
    method=PUT
  else
    body="{\"content\":\"$content\",\"message\":\"$message\",\"branch\":\"main\"}"
    method=POST
  fi
  printf '%s' "$body" | kubectl -n gitea exec -i deploy/tester -- \
    curl -fsS -u "$GIT_USER:$GIT_PASSWORD" -X "$method" -H 'Content-Type: application/json' \
    --data-binary @- "http://gitea-http.gitea:3000/api/v1/repos/$GIT_USER/$REPO/contents/$path" >/dev/null
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

put_file apps/podinfo/kustomization.yaml "$SOLUTION_REPO/apps/podinfo/kustomization.yaml" "Mark the podinfo tag for image automation"
put_file clusters/kind/image-automation.yaml "$SOLUTION_REPO/clusters/kind/image-automation.yaml" "Automate podinfo releases"
flux reconcile kustomization fleet --with-source
kubectl -n flux-system wait imageupdateautomation/podinfo --for=condition=Ready --timeout=120s || true

#!/usr/bin/env bash
# PASS when: confirms the Canary podinfo comes from Git with the requested analysis.
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

flux reconcile kustomization podinfo --with-source >/dev/null 2>&1 || true
INVENTORY="$(kubectl -n flux-system get kustomization podinfo \
  -o jsonpath='{range .status.inventory.entries[*]}{.id}{"\n"}{end}' 2>/dev/null)"
if ! printf '%s\n' "$INVENTORY" | grep -qx 'podinfo_podinfo_flagger.app_Canary'; then
  echo "FAIL: the Canary podinfo is not applied by the Flux Kustomization podinfo. Add it to Git under apps/podinfo and list it in kustomization.yaml."
  exit 1
fi
field() { kubectl -n podinfo get canary podinfo -o jsonpath="$1" 2>/dev/null; }
check() {
  # check LABEL ACTUAL EXPECTED
  if [ "$2" != "$3" ]; then
    echo "FAIL: the Canary has $1 '${2:-unset}'; the task asks for '$3'."
    exit 1
  fi
}
check "provider" "$(field '{.spec.provider}')" "nginx"
check "analysis.interval" "$(field '{.spec.analysis.interval}')" "15s"
check "analysis.threshold" "$(field '{.spec.analysis.threshold}')" "5"
check "analysis.maxWeight" "$(field '{.spec.analysis.maxWeight}')" "50"
check "analysis.stepWeight" "$(field '{.spec.analysis.stepWeight}')" "25"
check "request-success-rate minimum" "$(field '{.spec.analysis.metrics[?(@.name=="request-success-rate")].thresholdRange.min}')" "99"
if [ "$(field '{.spec.skipAnalysis}')" = "true" ]; then
  echo "FAIL: skipAnalysis is true, so Flagger promotes without checking anything."
  exit 1
fi
LOAD_URL="$(field '{.spec.analysis.webhooks[?(@.name=="load-test")].url}')"
case "$LOAD_URL" in
  http://flagger-loadtester.podinfo/*|http://flagger-loadtester.podinfo) ;;
  *) echo "FAIL: the load-test webhook calls '${LOAD_URL:-nothing}', not the load tester at http://flagger-loadtester.podinfo/."; exit 1 ;;
esac
echo "PASS: the Canary podinfo comes from Git with the requested analysis and load test."
exit 0

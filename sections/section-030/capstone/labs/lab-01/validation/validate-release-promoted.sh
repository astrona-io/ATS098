#!/usr/bin/env bash
# PASS when: adds podinfo 6.15.0 and follows it to a commit and a promotion by Flagger.
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

# The release under test: 6.15.0. The grader adds it to the lab registry and
# follows it through the policy, a commit by the automation, and Flagger.
push_podinfo_tag 6.15.0 >/dev/null 2>&1 || {
  echo "FAIL: could not copy podinfo 6.15.0 into the lab registry."
  exit 1
}
flux reconcile image repository podinfo -n flux-system >/dev/null 2>&1 || true
CHOSEN=""
for _ in $(seq 1 30); do
  CHOSEN="$(kubectl -n flux-system get imagepolicy podinfo -o jsonpath='{.status.latestRef.tag}' 2>/dev/null)"
  [ "$CHOSEN" = "6.15.0" ] && break
  sleep 3
done
if [ "$CHOSEN" != "6.15.0" ]; then
  echo "FAIL: the ImagePolicy podinfo chose '${CHOSEN:-nothing}' instead of 6.15.0. Check its semver range."
  exit 1
fi
flux reconcile image update podinfo -n flux-system >/dev/null 2>&1 || true
TAG_IN_GIT=""
for _ in $(seq 1 40); do
  TAG_IN_GIT="$(git_raw apps/podinfo/kustomization.yaml | awk '/newTag:/{print $2}')"
  [ "$TAG_IN_GIT" = "6.15.0" ] && break
  sleep 3
done
if [ "$TAG_IN_GIT" != "6.15.0" ]; then
  echo "FAIL: Git still says newTag ${TAG_IN_GIT:-nothing}; the automation did not write 6.15.0."
  exit 1
fi
AUTHOR="$(last_change_email apps/podinfo/kustomization.yaml)"
if [ "$AUTHOR" != "fluxcdbot@example.com" ]; then
  echo "FAIL: the last change to apps/podinfo/kustomization.yaml is by '$AUTHOR', not by the automation (fluxcdbot@example.com)."
  exit 1
fi
flux reconcile kustomization fleet --with-source >/dev/null 2>&1 || true

flux reconcile kustomization podinfo --with-source >/dev/null 2>&1 || true
PHASE=""
PRIMARY=""
# The analysis takes a few minutes: interval 15s, two weight steps, then promotion.
for _ in $(seq 1 168); do
  PHASE="$(kubectl -n podinfo get canary podinfo -o jsonpath='{.status.phase}' 2>/dev/null)"
  PRIMARY="$(kubectl -n podinfo get deployment podinfo-primary -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)"
  [ "$PHASE" = "Succeeded" ] && [ "$PRIMARY" = "ghcr.io/stefanprodan/podinfo:6.15.0" ] && break
  [ "$PHASE" = "Failed" ] && break
  sleep 5
done
if [ "$PHASE" != "Succeeded" ] || [ "$PRIMARY" != "ghcr.io/stefanprodan/podinfo:6.15.0" ]; then
  echo "FAIL: the Canary is '${PHASE:-unknown}' and podinfo-primary runs '${PRIMARY:-nothing}'. Flagger must promote 6.15.0. Read kubectl -n podinfo describe canary podinfo."
  exit 1
fi
if ! kubectl -n podinfo rollout status deployment/podinfo-primary --timeout=180s >/dev/null 2>&1; then
  echo "FAIL: podinfo-primary did not finish rolling out 6.15.0."
  exit 1
fi
echo "PASS: Flagger analysed 6.15.0, promoted it, and podinfo-primary runs it."
exit 0

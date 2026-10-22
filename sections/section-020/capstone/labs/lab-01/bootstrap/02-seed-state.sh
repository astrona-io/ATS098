#!/usr/bin/env bash
# Creates the starting state for ats-098-capstone-020.
#
# Seeds a release loop in Git with four faults between the registry and the commit.
# The starting files in Git are in manifests/repo/. The faults are on purpose:
# finding and fixing them is the task. Never fix them here.
set -euo pipefail

GIT_USER="gitops"
GIT_PASSWORD="gitops-password"
REPO="fleet"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS="$SCRIPT_DIR/../manifests"
BIN_DIR="/usr/local/bin"
[ -w "$BIN_DIR" ] || BIN_DIR="$HOME/.local/bin"
export PATH="$BIN_DIR:$PATH"

copy_image() {
  # copy_image FROM TO: copies one image reference to another with regctl.
  kubectl -n registry exec deploy/registry-tools -- regctl image copy "$1" "$2"
}

echo "[lab] Adding image tags to the lab registry..."
copy_image "ghcr.io/stefanprodan/podinfo:6.14.0" "registry.localtest.me:5000/podinfo:6.14.0"

echo "[lab] Connecting Flux to the repository gitops/fleet..."
flux create secret git fleet-auth \
  --url=http://gitea.localtest.me:3000/gitops/fleet.git \
  --username="$GIT_USER" --password="$GIT_PASSWORD"
kubectl apply -f "$MANIFESTS/flux-sync.yaml"
flux reconcile source git fleet
kubectl -n flux-system wait kustomization/fleet --for=condition=Ready --timeout=300s

kubectl -n flux-system wait kustomization/podinfo --for=condition=Ready --timeout=600s

echo "[lab] Starting state ready."

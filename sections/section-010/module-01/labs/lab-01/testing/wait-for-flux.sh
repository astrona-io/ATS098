#!/usr/bin/env bash
# Runs before the reference solution is applied.
#
# `astrona test` bootstraps and applies in one go. Wait until Gitea, the lab
# registry and every Flux controller answer, so the reference solution never
# races a component that is still starting.
set -eu

kubectl -n gitea rollout status deployment/gitea --timeout=300s
kubectl -n registry rollout status deployment/registry --timeout=300s
kubectl -n registry rollout status deployment/registry-tools --timeout=300s
for deployment in $(kubectl -n flux-system get deployment -o name); do
  kubectl -n flux-system rollout status "$deployment" --timeout=300s
done

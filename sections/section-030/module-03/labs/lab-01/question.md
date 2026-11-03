# Question

Solve this question on: `terminal`

**Time:** about 30 minutes, plus a few minutes for the environment to start · **Topic:** Progressive delivery

## Scenario

podinfo `6.14.0` runs in the namespace `podinfo` behind the Ingress `podinfo` for the host `app.example.com`. Flagger manages it with a `Canary` named `podinfo`. Today the analysis only checks the share of requests that succeed. The team also wants a release to fail when the slowest 1% of requests to the canary take longer than half a second.

The repository is `gitops/fleet` at `http://gitea.localtest.me:3000/gitops/fleet.git` (lab-only user `gitops`, password `gitops-password`). Start `kubectl -n gitea port-forward svc/gitea-http 3000:3000` in a second terminal before you use `git`. Flagger's Prometheus answers at `http://flagger-prometheus.ingress-nginx:9090`.

## Your task

1. Add a `MetricTemplate` named `latency` in the namespace `podinfo` to Git, in `apps/podinfo/`, and list it in `apps/podinfo/kustomization.yaml`. It must:
   - use the provider type `prometheus` with the address above;
   - return the 99th percentile of the metric `nginx_ingress_controller_request_duration_seconds_bucket` for the canary Ingress, over the `{{ interval }}` Flagger gives it, with `{{ namespace }}` and `{{ ingress }}` placeholders for the Ingress labels (the canary Ingress is named `{{ ingress }}-canary`).
2. Add a check named `latency` to the `Canary` `podinfo` that uses this template, with a maximum of `0.5` and an `interval` of `1m`. Keep the `request-success-rate` check.
3. Release `6.14.1` by changing the tag in `apps/podinfo/kustomization.yaml`, and let Flagger promote it.

## Constraints

- Do not set `skipAnalysis`, and do not change Deployments, Services or the `Canary` with `kubectl`.
- Apply the template and the `Canary` change in Git before you release `6.14.1`, so the release is judged by both checks.

## Done when

- The `MetricTemplate` `latency` and the `latency` check come from Git as described.
- Git asks for `6.14.1`.
- The `Canary` is `Succeeded`, and `podinfo-primary` runs `ghcr.io/stefanprodan/podinfo:6.14.1`.

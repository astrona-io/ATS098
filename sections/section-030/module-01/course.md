# Roll Out Releases Gradually With Flagger

When Git says podinfo `6.14.1` instead of `6.14.0`, the Deployment replaces every pod, and every user gets `6.14.1` a few seconds later. If `6.14.1` answers half its requests with an error, every user sees that too. A rolling update only waits for the readiness probe, and a pod can be ready and still broken.

Flagger changes the order. It is a progressive delivery operator from the Flux project: a controller that runs a new version next to the last good one and moves traffic over in steps. After each step it reads metrics from Prometheus, a time series database that stores the request counts of the router. Good numbers mean the next step; bad numbers count as a failed check, and too many failed checks mean a rollback. Keep one sentence in mind: **Flagger promotes a version only after the traffic it served proves it works.**

The module has three parts. **Flagger And The Canary Resource** writes the `Canary` for podinfo and shows the objects Flagger creates. **Canary Analysis, Promotion And Rollback** releases a new version, follows the analysis to a promotion, and then causes a rollback on purpose. A graded lab follows it. **A/B Testing, Blue/Green And Custom Metrics** routes only some users to the new version, compares the other deployment strategies, and adds a custom Prometheus query.

## Learning objectives

After this module you can:

- Explain what Flagger does, and name the objects it creates: the primary Deployment and the `-primary` and `-canary` Services and Ingress.
- Write a `Canary` with a target, an Ingress, a Service port and an analysis.
- Explain `interval`, `stepWeight`, `maxWeight` and `threshold`, and predict how long an analysis takes.
- Follow a promotion with `kubectl describe canary`, and cause and read a rollback.
- Give the canary traffic with a load-test webhook and gate it with an acceptance test.
- Switch a `Canary` to A/B testing with a header match, and describe blue/green.
- Write a `MetricTemplate` with a Prometheus query.

## Before you start

You need to know Flux: a `GitRepository`, a Flux `Kustomization` object, and how a commit becomes a change in the cluster. You need Git from the terminal. You need Kubernetes Deployments, Services and Ingresses: an Ingress is a set of HTTP routing rules that an ingress controller, here ingress-nginx, carries out.

Your playground is a single-node `kind` cluster with **Flux 2.9.6** and the `flux` command-line tool on your PATH. Gitea, a Git server inside the cluster, holds the repository `gitops/fleet`. Flux installed the rest from Helm charts listed in `infrastructure/` in that repository:

| Component | Namespace | What it is |
| --- | --- | --- |
| ingress-nginx | `ingress-nginx` | The router; its Service `ingress-nginx-controller` has no external address on `kind` |
| Flagger 1.45.0 | `ingress-nginx` | Configured for nginx, with its own Prometheus, `flagger-prometheus` |
| `flagger-loadtester` | `podinfo` | Runs load tests and checks when Flagger asks |
| podinfo `6.14.0` | `podinfo` | The Deployment `podinfo` and the Ingress `podinfo` for the host `app.example.com`, from `apps/podinfo` in Git |

The Ingress points at a Service `podinfo` that does not exist yet: Flagger creates it. The Deployment has no `replicas` field in Git, because Flagger sets the replicas of the Deployment it manages, and Flux must not set them back.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

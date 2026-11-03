# Judge Releases With Metrics, Webhooks And Alerts

A canary analysis is only as good as the questions it asks. The built-in check "did at least 99% of the requests succeed?" lets a slow release through, because a slow answer is still a success. A release can also pass every number and still be wrong for a reason only your team can test. Flagger gives you three tools to ask better questions: a `MetricTemplate` for any number Prometheus can compute, webhooks for any check an HTTP call can make, and alerts for telling people what happened.

Flagger is a progressive delivery operator from the Flux project: a controller that runs a new version next to the last good one, moves traffic in steps, and reads metrics after each step. Prometheus is the time series database that stores the request counts of the router. This module teaches how to read the numbers, write your own, stop a release at a gate that a person or a system opens, send alerts, and find out why a release stops. Keep one sentence in mind: **a release is promoted only when every metric is inside its range and every webhook answers with a success status.**

The module has five parts. **Built-In Metrics And MetricTemplates** writes a `Canary` with the built-in checks and a first template. **Writing And Testing Prometheus Queries** runs a query by hand before Flagger does. A graded lab follows it. **Webhooks And Gates** adds a gate that holds a release until you open it. **Alerts And Alert Providers** tells a receiver about promotions and rollbacks. **Troubleshooting A Failing Release** reads the symptoms of the most common failures.

## Learning objectives

After this module you can:

- Use the built-in `request-success-rate` and `request-duration` metrics with the right limit and unit.
- Write a `MetricTemplate` with a Prometheus query and the Flagger placeholders.
- Run a query by hand against Prometheus and say why an empty result fails a check.
- Name the webhook types and when each one runs, and gate a release with `confirm-rollout`.
- Configure an `AlertProvider` and attach it to a `Canary` with a severity.
- Match the symptoms of a stuck or failing release to their cause.

## Before you start

You need to know Flux: a `GitRepository`, a Flux `Kustomization` object, and how a commit becomes a change in the cluster. You need Git from the terminal. You need to know what a weighted canary release is: Flagger raises the share of traffic that a new version gets, step by step, and rolls back when too many checks fail.

Your playground is a single-node `kind` cluster with **Flux 2.9.6** and the `flux` command-line tool on your PATH. Gitea, a Git server inside the cluster, holds the repository `gitops/fleet`. Flux installed the rest from Helm charts listed in `infrastructure/` in that repository:

| Component | Namespace | What it is |
| --- | --- | --- |
| ingress-nginx | `ingress-nginx` | The router; its Service `ingress-nginx-controller` has no external address on `kind` |
| Flagger 1.45.0 | `ingress-nginx` | Configured for nginx, with its own Prometheus, `flagger-prometheus` |
| `flagger-loadtester` | `podinfo` | Runs load tests and checks when Flagger asks |
| podinfo `6.14.0` | `podinfo` | The Deployment `podinfo` and the Ingress `podinfo` for the host `app.example.com`, from `apps/podinfo` in Git |

The Deployment has no `replicas` field in Git, because Flagger sets the replicas of the Deployment it manages, and Flux must not set them back. No `Canary` exists yet.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

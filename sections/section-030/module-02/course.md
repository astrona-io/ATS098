# Choose A Deployment Strategy In Flagger

A new version of podinfo can reach users in four different ways, and each way fits a different risk. A weighted canary release gives the new version a growing share of random users. An A/B test gives it only the users who send a header or a cookie. Blue/green keeps users away from it until tests pass, then switches everybody at once. Traffic mirroring copies real requests to it without answering any user from it. Flagger runs all four, and one object, the `Canary`, decides which one.

Flagger is a progressive delivery operator from the Flux project: a controller that runs a new version next to the last good one and moves traffic in steps while it reads metrics. Which strategies it can run depends on the **provider**, the router or service mesh that Flagger tells how to split traffic. This module teaches the providers, then each strategy in order. Keep one sentence in mind: **the fields in `analysis` choose the strategy, and the provider decides which strategies work.**

The module has five parts. **Flagger Providers And Installation** installs Flagger with Helm and shows which providers exist. **Canary Release Steps And Autoscaling** writes a weighted `Canary` with explicit step weights and an autoscaler. **A/B Testing With Headers And Cookies** sends only matching requests to the canary. A graded lab follows it. **Blue/Green And Traffic Mirroring** tests a new version with no user traffic. **Reading The Canary Status** reads the phase, the weight and the conditions of a release.

## Learning objectives

After this module you can:

- Name the Flagger providers and say which strategies each one supports.
- Install Flagger with Helm or a Flux `HelmRelease` and choose the provider with `meshProvider`.
- Write a weighted `Canary` with `stepWeight`, `stepWeights`, `maxWeight` and `threshold`, and predict how long it takes.
- Attach a `HorizontalPodAutoscaler` to a `Canary` with `autoscalerRef`.
- Write an A/B test that matches a header or a cookie and explain how ingress-nginx carries it out.
- Run a blue/green release with the `kubernetes` provider and explain what traffic mirroring needs.
- Read `.status.phase`, `.status.canaryWeight` and `.status.failedChecks` of a `Canary`.

## Before you start

You need to know Flux: a `GitRepository`, a Flux `Kustomization` object, and how a commit becomes a change in the cluster. You need Git from the terminal. You need Kubernetes Deployments, Services and Ingresses: an Ingress is a set of HTTP routing rules that an ingress controller, here ingress-nginx, carries out.

Your playground is a single-node `kind` cluster with **Flux 2.9.6** and the `flux` command-line tool on your PATH. Gitea, a Git server inside the cluster, holds the repository `gitops/fleet`. Flux installed the rest from Helm charts listed in `infrastructure/` in that repository:

| Component | Namespace | What it is |
| --- | --- | --- |
| ingress-nginx | `ingress-nginx` | The router; its Service `ingress-nginx-controller` has no external address on `kind` |
| Flagger 1.45.0 | `ingress-nginx` | Configured for nginx, with its own Prometheus, `flagger-prometheus` |
| `flagger-loadtester` | `podinfo` | Runs load tests and checks when Flagger asks |
| podinfo `6.14.0` | `podinfo` | The Deployment `podinfo` and the Ingress `podinfo` for the host `app.example.com`, from `apps/podinfo` in Git |
| probe `6.14.0` | `podinfo` | A second Deployment, `probe`, from `apps/probe` in Git, with no Ingress |

Neither Deployment has a `replicas` field in Git, because Flagger sets the replicas of the Deployment it manages, and Flux must not set them back. No `Canary` exists yet.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

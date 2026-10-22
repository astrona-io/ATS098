# Flagger And The Canary Resource

Before Flagger can protect a release, it has to take charge of the Deployment, and that changes which objects serve your users. This part writes the `Canary` for podinfo, commits it, and walks through what Flagger builds from it. Knowing those objects by name is what lets you read a rollout later.

## The router and the metrics

Flagger does not move traffic itself. It tells a router how to split requests, and here the router is ingress-nginx. ingress-nginx can send a percentage of the requests for one host to a second Ingress, the canary Ingress, and Flagger changes that percentage step by step. The ingress-nginx project stopped publishing new releases in March 2026; Flagger supports other routers, for example any implementation of the Kubernetes Gateway API, and the `Canary` works the same way with them.

Flagger also needs numbers. ingress-nginx counts every request with its status code, and Prometheus collects those counts. Flagger's Helm chart installed its own Prometheus, `flagger-prometheus`, so Flagger can ask how many requests to the canary succeeded in the last minute.

Check that Flux installed all of it before you go on:

<!-- astrona:playground:renew -->

```sh
flux get helmreleases
kubectl -n ingress-nginx get deployments
kubectl -n podinfo get deployments,services,ingresses
```

The three HelmReleases `ingress-nginx`, `flagger` and `flagger-loadtester` are `Ready`. In `ingress-nginx` run the controller, `flagger` and `flagger-prometheus`. In `podinfo` run the Deployment `podinfo` and `flagger-loadtester`, and there is the Ingress `podinfo`, but no Service `podinfo` yet.

## The Canary resource

A `Canary` names the Deployment to protect and the Ingress that serves it, and says how to judge a new version. Clone the repository; the port-forward to Gitea must run in a second terminal (`kubectl -n gitea port-forward svc/gitea-http 3000:3000`), and the user `gitops` with the password `gitops-password` exists only in this lab. If `gitea.localtest.me` does not resolve, add `127.0.0.1 gitea.localtest.me` to `/etc/hosts`.

```sh
git clone http://gitops:gitops-password@gitea.localtest.me:3000/gitops/fleet.git
cd fleet
```

Save this as `apps/podinfo/canary.yaml` in your clone:

```yaml
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: podinfo
  namespace: podinfo
spec:
  provider: nginx
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: podinfo
  ingressRef:
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    name: podinfo
  progressDeadlineSeconds: 300
  service:
    port: 9898
    targetPort: 9898
  analysis:
    interval: 15s
    threshold: 5
    maxWeight: 50
    stepWeight: 25
    metrics:
      - name: request-success-rate
        thresholdRange:
          min: 99
        interval: 1m
    webhooks:
      - name: acceptance-test
        type: pre-rollout
        url: http://flagger-loadtester.podinfo/
        timeout: 30s
        metadata:
          type: bash
          cmd: "curl -sd 'test' http://podinfo-canary.podinfo:9898/token | grep token"
      - name: load-test
        url: http://flagger-loadtester.podinfo/
        timeout: 5s
        metadata:
          cmd: "hey -z 1m -q 10 -c 2 -host app.example.com http://ingress-nginx-controller.ingress-nginx/"
```

The fields fall into three groups:

| Fields | What they say |
| --- | --- |
| `provider`, `targetRef`, `ingressRef` | Use nginx to shift the traffic of the Ingress `podinfo` for the Deployment `podinfo` |
| `service`, `progressDeadlineSeconds` | Create Services on port `9898`; give a new version 300 seconds to become ready before it counts as failed |
| `analysis` | How to judge a new version; the next part explains every field |

The two webhooks call `flagger-loadtester`. The `pre-rollout` webhook runs once before any traffic moves: it asks the new version for a token, a quick check that it answers at all. The `load-test` webhook runs at every step and sends requests through ingress-nginx with the host `app.example.com`, because nobody else uses this lab application and an analysis without traffic has nothing to measure.

## Commit it and watch Flagger take over

The Kustomize file `kustomization.yaml` in `apps/podinfo` lists the files Flux applies, so add the `Canary` to it. Change its `resources` so they read:

```yaml
resources:
  - namespace.yaml
  - deployment.yaml
  - ingress.yaml
  - canary.yaml
```

Commit, push, and apply:

```sh
git add apps/podinfo/canary.yaml apps/podinfo/kustomization.yaml
git commit -m "Add the podinfo canary"
git push
flux reconcile kustomization podinfo --with-source
kubectl -n podinfo get canary podinfo --watch
```

The `STATUS` column moves to `Initialized` within a minute or two. Stop the watch with Ctrl+C. Flagger did not analyse anything: the version that runs when the `Canary` appears is trusted as the first good version.

## What Flagger built

List the namespace again:

```sh
kubectl -n podinfo get deployments,services,ingresses
```

Flagger created these objects:

| Object | What it is |
| --- | --- |
| Deployment `podinfo-primary` | A copy of `podinfo`; it serves all traffic now |
| Service `podinfo-primary` | Points at the primary pods |
| Service `podinfo-canary` | Points at the pods of the Deployment `podinfo` |
| Service `podinfo` | Points at the primary pods; the Ingress `podinfo` now has a backend |
| Ingress `podinfo-canary` | The second Ingress that ingress-nginx sends the canary share to; its weight is 0 |

The Deployment `podinfo` itself is scaled to zero. From now on it is only a template: when its pod template changes, Flagger starts a new canary from it. That is why Git holds no `replicas` field for it, so Flux never undoes Flagger's scaling.

```mermaid
flowchart TB
    I["Ingress: podinfo"] -->|"100%"| SP["Service: podinfo-primary"]
    IC["Ingress: podinfo-canary"] -->|"0%"| SC["Service: podinfo-canary"]
    SP -->|"pods"| P["podinfo-primary"]
    SC -->|"pods"| C["podinfo (0 replicas)"]
```

The diagram shows the steady state: all traffic on the primary, and the canary path ready but unused.

Send one request the way users do, through ingress-nginx with the host `app.example.com`. The load tester has `curl`, so it sends it:

```sh
kubectl -n podinfo exec deploy/flagger-loadtester -- \
  curl -s -H 'Host: app.example.com' http://ingress-nginx-controller.ingress-nginx/
```

podinfo answers with a small JSON document; its `version` field says `6.14.0`, served by a `podinfo-primary` pod.

You now know what a `Canary` describes and which objects Flagger creates for it. Nothing has been tested yet, because nothing new has been released. The next question is what Flagger does when the Deployment changes.

## Common pitfalls

> [!WARNING]
> - **A `podinfo` Service in Git.** Flagger creates and owns that Service; a second owner in Git fights it.
> - **A `replicas` field on the target Deployment in Git.** Flux sets it back after Flagger scales the Deployment to zero.
> - **Expecting an analysis on the first version.** The first version is only initialized; analysis starts at the next change.
> - **A load test that sends to the wrong address.** Without traffic through the canary Ingress, the success rate has no data, and the analysis fails.
> - **Forgetting the file in `kustomization.yaml`.** A file that is not listed in `resources` is never applied.

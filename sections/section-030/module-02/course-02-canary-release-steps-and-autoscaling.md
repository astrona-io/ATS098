# Canary Release Steps And Autoscaling

A fixed step of 25% is a good default for a lab and a poor fit for a busy service. A team often wants to start with 1% of the users, because a crash that reaches 25% of a million users is already an incident. This part writes a `Canary` with its own list of step weights, predicts how long the release takes before it runs, and attaches an autoscaler, because the number of pods of the target changes while Flagger works.

## Steps you choose

A weighted canary release raises the share of traffic that the canary gets in steps. `stepWeight` sets one fixed step, for example 25, and `maxWeight` sets the share at which Flagger promotes. `stepWeights` sets the steps one by one as a list, for example `[10, 30, 60]`. When `stepWeights` is set, Flagger ignores `stepWeight` and `maxWeight`, and the last number of the list is the highest weight the canary gets.

Flagger waits one `interval` after each step and checks the metrics. A release with three steps and `interval: 15s` therefore needs three checks, about 45 seconds, plus the time to scale the canary up and to promote. If a check fails, Flagger counts it. After `threshold` failed checks in total, it rolls back.

The `Canary` also has fields that change what happens around the steps:

| Field | What it does |
| --- | --- |
| `progressDeadlineSeconds` | Seconds Flagger waits for the new pods to become ready before it counts the release as failed |
| `skipAnalysis` | When `true`, Flagger promotes a new version without any step or check |
| `revertOnDeletion` | When `true`, deleting the `Canary` puts the target Deployment back to what it was before Flagger took it over |
| `autoscalerRef` | Names the `HorizontalPodAutoscaler` of the target; Flagger copies it for the primary |

`skipAnalysis` is for an emergency release, and it removes the protection the `Canary` gives. Use it for a few minutes at most, in Git, with a commit message that says why.

## Write the Canary

Clone `gitops/fleet` with the port-forward to Gitea running in a second terminal. The command needs the playground to be running:

<!-- astrona:playground:renew -->

```sh
kubectl -n gitea port-forward svc/gitea-http 3000:3000
```

In the first terminal, clone the repository. The user `gitops` with the password `gitops-password` exists only in this lab. If `gitea.localtest.me` does not resolve, add `127.0.0.1 gitea.localtest.me` to `/etc/hosts`.

```sh
git clone http://gitops:gitops-password@gitea.localtest.me:3000/gitops/fleet.git
cd fleet
```

Save this as `apps/podinfo/canary.yaml`:

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
    threshold: 3
    stepWeights: [10, 30, 60]
    metrics:
      - name: request-success-rate
        thresholdRange:
          min: 99
        interval: 1m
    webhooks:
      - name: load-test
        url: http://flagger-loadtester.podinfo/
        timeout: 5s
        metadata:
          cmd: "hey -z 1m -q 10 -c 2 -host app.example.com http://ingress-nginx-controller.ingress-nginx/"
```

The `webhooks` entry sends test traffic through ingress-nginx at every step. Without traffic, `request-success-rate` has no data and a good release fails.

## Add an autoscaler

Many Deployments run under a `HorizontalPodAutoscaler` (HPA), a Kubernetes object that changes the number of replicas from CPU use. Flagger cannot keep a second copy of the Deployment for the primary and leave the HPA pointed at the original. With `autoscalerRef`, Flagger creates a second HPA for `podinfo-primary` and keeps the original for the canary. Save this as `apps/podinfo/hpa.yaml`:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: podinfo
  namespace: podinfo
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: podinfo
  minReplicas: 1
  maxReplicas: 2
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 99
```

Then add these lines under `spec` in `canary.yaml`, next to `targetRef`:

```yaml
  autoscalerRef:
    apiVersion: autoscaling/v2
    kind: HorizontalPodAutoscaler
    name: podinfo
```

## Commit and release

List both files in `resources` of `apps/podinfo/kustomization.yaml`, after `ingress.yaml`: `canary.yaml` and `hpa.yaml`. Commit, push and apply:

```sh
git add apps/podinfo
git commit -m "Add the podinfo canary with step weights and an autoscaler"
git push
flux reconcile kustomization podinfo --with-source
kubectl -n podinfo get canary podinfo --watch
```

The status moves to `Initialized`. Stop the watch with Ctrl+C and list the autoscalers:

```sh
kubectl -n podinfo get hpa
```

The list holds the HPA `podinfo` from Git and the HPA `podinfo-primary` that Flagger created. The one in Git now belongs to the canary side, and the new one scales the pods that serve users. Metrics may show as unknown until the cluster has a metrics server; the objects exist either way.

Now release `6.14.1` and read the weights:

```sh
sed -i.bak 's/newTag: 6.14.0/newTag: 6.14.1/' apps/podinfo/kustomization.yaml && rm apps/podinfo/kustomization.yaml.bak
git commit -am "Release podinfo 6.14.1"
git push
flux reconcile kustomization podinfo --with-source
kubectl -n podinfo describe canary podinfo | sed -n '/^Events:/,$p'
```

Run the last command again every 20 seconds or so. The events show the canary weight advance to 10, 30 and 60, one interval apart, and then the promotion. That matches the three steps in the list.

You can now choose the steps of a weighted release, predict its length, and keep an autoscaler working with it. A weighted release still gives the new version to random users. The next part picks the users instead.

## Common pitfalls

> [!WARNING]
> - **Keeping `stepWeight` next to `stepWeights`.** Flagger ignores `stepWeight` and `maxWeight`, and the next reader believes they apply.
> - **A `replicas` field on the target Deployment.** Flux sets it back after Flagger scales the Deployment to zero.
> - **An HPA that targets `podinfo-primary` in Git.** Flagger owns that HPA; two owners fight over it.
> - **Leaving `skipAnalysis: true` in Git after an emergency release.** Every later release skips its checks.
> - **A very short `progressDeadlineSeconds`.** Slow image pulls count as a failed release.

# Reading The Canary Status

A release that takes three minutes and fails at minute two leaves one question: what exactly did Flagger see? Flagger writes its decisions to the `Canary` itself, to the Kubernetes events and to its own log. This part reads all three on a release that Flagger rolls back, because the failure case shows more than the success case.

## The phases of a release

Every `Canary` has a `.status.phase`. The phase names where the release is:

| Phase | Meaning |
| --- | --- |
| `Initializing` and `Initialized` | Flagger created the primary and the Services; no analysis has run |
| `Waiting` | A `confirm-rollout` webhook has not yet approved the start |
| `Progressing` | The analysis runs: weights, iterations and checks |
| `WaitingPromotion` | A `confirm-promotion` webhook has not yet approved the promotion |
| `Promoting` and `Finalising` | Flagger copies the template to the primary and sends all traffic back to it |
| `Succeeded` | The release was promoted |
| `Failed` | The release was rolled back |

The fields next to the phase tell the numbers: `.status.canaryWeight` is the share of traffic the canary has now, `.status.iterations` counts finished iterations of an A/B test or blue/green release, and `.status.failedChecks` counts the checks that failed in this release. `.status.lastAppliedSpec` is a hash of the pod template Flagger last analysed, and `.status.lastPromotedSpec` is a hash of the one it promoted. A new analysis starts when the hash of the target differs from `lastAppliedSpec`.

## Cause a failure and read it

This part needs a weighted `Canary` named `podinfo`, as written earlier, with `request-success-rate` and the load-test webhook, and your clone of `gitops/fleet` with the port-forward to Gitea running in a second terminal. Release `6.15.0`:

<!-- astrona:playground:renew -->

```sh
sed -i.bak 's/newTag: 6.14.1/newTag: 6.15.0/' apps/podinfo/kustomization.yaml && rm apps/podinfo/kustomization.yaml.bak
git commit -am "Release podinfo 6.15.0"
git push
flux reconcile kustomization podinfo --with-source
```

When `kubectl -n podinfo get canary podinfo` shows `Progressing` with a weight above 0, send requests that fail. podinfo answers `/status/500` with the status code 500 on purpose, and part of the traffic reaches the canary:

```sh
kubectl -n podinfo exec deploy/flagger-loadtester -- \
  hey -z 2m -q 10 -c 2 -host app.example.com http://ingress-nginx-controller.ingress-nginx/status/500
```

While `hey` runs, read the fields of the status in a second terminal. Run the command a few times:

```sh
kubectl -n podinfo get canary podinfo \
  -o jsonpath='{.status.phase}{" weight="}{.status.canaryWeight}{" failedChecks="}{.status.failedChecks}{"\n"}'
```

`failedChecks` grows by one at each interval. When it reaches the `threshold` of the `Canary`, the phase becomes `Failed` and the weight goes back to 0.

## Read the events and the log

The events give the reason for each decision, in order:

```sh
kubectl -n podinfo describe canary podinfo | sed -n '/^Events:/,$p'
```

The warning events say that a metric check failed, with the metric name and the value against its limit, that the advance of the weight halted, and finally that the failed checks reached the threshold and the canary is scaled down. The Flagger controller writes the same decisions to its log, as one JSON object per line, which also holds the errors that never reach the events, such as a webhook that returned an error or a Prometheus query that failed:

```sh
kubectl -n ingress-nginx logs deploy/flagger --tail=30
```

Read the log from the bottom up. The newest line tells what Flagger waits for now, and the lines above show how it got there.

You can now say where a release is from the phase, how close it is to a rollback from `failedChecks`, and why a check failed from the events and the log. The module has now covered how Flagger shifts traffic, and how to read what it did.

## Common pitfalls

> [!WARNING]
> - **Reading `Succeeded` as "the new version runs".** Check the image of `podinfo-primary`.
> - **Reading only the status and not the events.** The status says what happened; the events say why.
> - **Looking at the log of the wrong controller.** The Flagger log is in the namespace where the chart installed Flagger, here `ingress-nginx`.
> - **Waiting on `Initialized`.** An initialized `Canary` has not analysed anything; the next change to the Deployment starts the analysis.
> - **Sending failing requests after the analysis ended.** The release must be in `Progressing` for the failures to count.

# Troubleshooting A Failing Release

A release that does not finish has four possible causes: the new pods never become ready, no traffic reaches the canary, a metric is outside its range, or a webhook fails. Each one leaves a different trace in the `Canary`. This part breaks a release on purpose in the most common way, reads the trace, and lists the others, so that the next stuck release takes minutes to explain.

## Four causes and where they show

| Symptom | Cause | Where to look | Fix |
| --- | --- | --- | --- |
| Phase `Failed` soon after `Progressing`, with a message about readiness | The new pods did not become ready within `progressDeadlineSeconds` | Events; `kubectl -n podinfo get pods` | Fix the image, the probe or the deadline |
| A metric check fails at every step, and the events say no values were found | No traffic reaches the canary | Events; the load-test `cmd` | Fix the host or the address of the load test |
| A metric check fails with a value outside its range | The new version is worse, or the limit is wrong | Events, with the value and the limit | Fix the release or the `thresholdRange` |
| The release waits in `Waiting` or `WaitingPromotion` | A `confirm-*` webhook answers with a failure status | Events; the gate state | Open the gate or fix the receiver |
| Phase `Failed` at the start, with a webhook error | A `pre-rollout` webhook failed | Events; the Flagger log | Run its command by hand |

The order of the table is the order of the release: pods, traffic, metrics, gates. Check them in that order.

## Break the release on purpose

This part needs the `Canary` `podinfo` with the load-test webhook, your clone of `gitops/fleet`, and the port-forward to Gitea in a second terminal. A load test without the `-host` option sends requests that ingress-nginx cannot match to the Ingress `podinfo`, so none of them reaches the canary. Change the command in `apps/podinfo/canary.yaml`:

<!-- astrona:playground:renew -->

```sh
sed -i.bak 's/ -host app.example.com//' apps/podinfo/canary.yaml && rm apps/podinfo/canary.yaml.bak
git commit -am "Break the load test"
git push
```

Release a new version, so that an analysis starts. If `6.14.1` is already running, release `6.15.0`:

```sh
sed -i.bak 's/newTag: 6.14.1/newTag: 6.15.0/' apps/podinfo/kustomization.yaml && rm apps/podinfo/kustomization.yaml.bak
git commit -am "Release podinfo 6.15.0"
git push
flux reconcile kustomization podinfo --with-source
kubectl -n podinfo get canary podinfo --watch
```

The release stays at weight 25 or 50 and does not advance. After five failed checks, the status is `Failed`. Stop the watch and read why:

```sh
kubectl -n podinfo describe canary podinfo | sed -n '/^Events:/,$p'
kubectl -n ingress-nginx logs deploy/flagger --tail=20
```

The events show the halted advance of the weight at every step. The reason is a metric check that found no values, and the message adds that the target is probably not receiving traffic. The pods were ready, so the cause is the third column of the table: no traffic. The load-test command in the `Canary` is the only place that sends traffic, so that is where the fix goes.

## Fix it and run again

Put the host back, release again, and watch the same release pass. Because the failed release left `6.15.0` in Git, change the tag to `6.15.1` if you have it, or restore `6.14.1` and release `6.15.0` again:

```sh
git revert --no-edit HEAD~1
git push
flux reconcile kustomization podinfo --with-source
```

That reverts the broken load test. The `Canary` returns to a working analysis, and the next change to the Deployment starts a release that passes.

For a deeper look, raise the log level of Flagger. The chart has a `logLevel` value; set it to `debug` in the `HelmRelease` values, commit, and Flux restarts the controller. Debug lines name each query that Flagger sends and the value it received, which settles any argument about what a check saw.

You can now follow a stuck release from its symptom to its cause and fix, in the order of the release. Together with metrics, webhooks and alerts, that completes the toolset for judging a release.

## Common pitfalls

> [!WARNING]
> - **Reading the last event only.** The first failed check usually holds the cause; the later ones repeat it.
> - **Fixing the release when the load test is broken.** A good version fails the same way as a bad one when no traffic reaches it.
> - **Raising `threshold` to make a release pass.** It hides the cause and weakens the protection.
> - **Deleting the `Canary` to restart.** Flagger reinitializes it and may scale the target; fix the cause in Git instead.
> - **Forgetting that a revert is a new commit.** Flux applies the new commit, so the broken one still exists in history.

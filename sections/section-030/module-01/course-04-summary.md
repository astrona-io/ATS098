# Summary

A rolling update only waits for the readiness probe, so a broken release reaches every user. Flagger, the progressive delivery operator of the Flux project, puts a test between Git and the users: it runs the new version next to the last good one, gives it traffic, reads metrics, and promotes or rolls back.

## What you learned

A `Canary` names the target Deployment, the router (`provider: nginx` with an `ingressRef`), the Service port and the analysis. When it appears, Flagger initializes it without analysis: it creates the Deployment `podinfo-primary`, the Services `podinfo`, `podinfo-primary` and `podinfo-canary`, and the Ingress `podinfo-canary`, and scales the target to zero. So Git must not hold a `podinfo` Service or a `replicas` field on the target. ingress-nginx sends the canary's share of the traffic through the canary Ingress, and Flagger's Prometheus counts the results.

An analysis starts when the target's pod template changes. Flagger waits for the new pods (`progressDeadlineSeconds`), runs the `pre-rollout` webhooks, then checks the metrics every `interval`. Each good check raises the weight by `stepWeight` until `maxWeight`, then Flagger copies the template to the primary and promotes. Each bad check counts, and `threshold` bad checks roll back. `request-success-rate` with `min: 99` needs at least 99% of the canary's requests without a 5xx status, so the load-test webhook must send traffic. A rollback never changes Git; `kubectl describe canary` tells the story in its events, and the image of `podinfo-primary` shows what users get.

The `analysis` fields choose the strategy. `stepWeight` and `maxWeight` make a weighted canary release. `iterations` with `match` make an A/B test that only sends matching requests, such as a header `x-canary: insider`, to the canary. `iterations` alone make blue/green, where only the test traffic reaches the new version before one switch. A `MetricTemplate` adds any Prometheus query as a check, with placeholders such as `{{ namespace }}`, `{{ ingress }}` and `{{ interval }}`. The key facts to remember are these:

- The first version is only initialized; analysis starts with the next change to the target Deployment.
- No traffic means no data, and no data means failed checks.
- `Succeeded` means promoted; the primary's image is what users run.
- Change the `Canary`, the release and the metrics in Git, like everything else.

<!-- astrona:playground:destroy -->

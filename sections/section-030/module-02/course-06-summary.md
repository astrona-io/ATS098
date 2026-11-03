# Summary

Flagger chooses between four ways to give users a new version, and the `Canary` holds the choice in its `analysis` fields. The provider, the router or service mesh that Flagger changes, decides which of the four work. The `nginx` provider carries out weighted canary releases and A/B tests by creating a canary Ingress with ingress-nginx annotations. The `kubernetes` provider needs no router and carries out blue/green only. Istio and the Gateway API providers also carry out traffic mirroring. The chart value `meshProvider` sets the default provider, and `prometheus.install` starts the Prometheus that Flagger reads.

A weighted canary release raises the share of traffic in steps: `stepWeight` and `maxWeight` for equal steps, or `stepWeights` for a list. Each step waits one `interval` and runs the checks, and `threshold` failed checks roll the release back. The time of a release follows from the number of steps and the interval. `autoscalerRef` lets a `HorizontalPodAutoscaler` work with it, because Flagger creates a second autoscaler for the primary. `skipAnalysis` removes all checks and belongs only in an emergency.

An A/B test uses `iterations` and `match`. With the nginx provider, a header match or a cookie match becomes an annotation on the canary Ingress, and only requests with the header or the cookie `always` reach the canary. The load test must send the same header or cookie, or the canary gets no traffic. Blue/green uses `iterations` alone: only test traffic reaches the new version, and all users switch at once. Mirroring copies real requests to the new version and needs a router that can mirror.

The `Canary` reports its work. `.status.phase` names the stage, `canaryWeight` and `failedChecks` give the numbers, the events give the reasons, and the Flagger log shows errors that never reach the events. The key facts to remember are these:

- The fields in `analysis` choose the strategy; the provider decides what is possible.
- A change to the `Canary` does not start an analysis; a change to the target's pod template does.
- No test traffic means no data, and no data means failed checks.
- `Succeeded` means promoted; the image of the primary is what users run.

<!-- astrona:playground:destroy -->

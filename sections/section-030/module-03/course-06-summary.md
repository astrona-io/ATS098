# Summary

Flagger promotes a release only when every metric stays inside its range and every webhook answers with a success status. With ingress-nginx, two metrics are built in: `request-success-rate`, the percentage of canary requests without a 5xx status, which needs a `min`, and `request-duration`, the 99th percentile in milliseconds, which needs a `max`. Anything else comes from a `MetricTemplate`, an object that holds a Prometheus address and one query. Flagger replaces placeholders such as `{{ namespace }}`, `{{ ingress }}` and `{{ interval }}` in the query, and a metric can offer its own through `templateVariables`.

A query must return at least one sample. An empty answer cannot be judged, so the check fails, and the events say that no values were found and the target is probably not receiving traffic. The canary Ingress gets traffic only during an analysis, so a correct canary query returns nothing outside one. Testing a query by hand with the Prometheus HTTP API, with the placeholders filled in, shows the number Flagger will see.

Webhooks call any HTTP address at defined points. The type decides when: `confirm-rollout` before the analysis, `pre-rollout` once before traffic moves, `rollout` at each interval, `confirm-traffic-increase` before each weight step, `confirm-promotion` before the promotion, `post-rollout` after the result, `rollback` to force a rollback, and `event` for every event. Any 2xx answer passes. The load tester provides gates at `/gate/check`, `/gate/open` and `/gate/close` that hold a release in `Waiting` until they open. An `AlertProvider` describes a receiver. The `alerts` list in the `Canary` attaches it with a severity of `info`, `warn` or `error`, and a delivery failure never changes the result of a release.

A stuck or failing release has four causes in release order: pods that are not ready, no traffic to the canary, a metric outside its range, and a webhook or gate that fails. The events name the cause, and the Flagger log adds the errors that never become events. The key facts to remember are these:

- Success rate needs a minimum, and duration needs a maximum.
- An empty query result is a failed check.
- A `confirm-*` webhook holds the release until it answers with a success status.
- Fix the cause in Git; raising `threshold` only hides it.

<!-- astrona:playground:destroy -->

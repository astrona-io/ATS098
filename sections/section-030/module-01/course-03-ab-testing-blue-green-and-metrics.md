# A/B Testing, Blue/Green And Custom Metrics

A weighted canary sends a random share of all users to the new version. That is fine for a stateless API, and wrong for an application where a user must stay on one version for a whole session, or where only testers should see a new feature first. This part changes how Flagger chooses who gets the canary, compares the deployment strategies Flagger offers, and adds a check of your own to the analysis.

## A/B testing: choose the users

In an A/B test, Flagger does not raise a weight. It sends only the requests that match a condition, such as an HTTP header or a cookie, to the canary, and everyone else stays on the primary. The analysis runs a fixed number of `iterations`, one per `interval`, and checks the metrics each time. If every iteration passes, Flagger promotes.

The commands below need the `Canary` `podinfo` from your clone of `gitops/fleet`, and the port-forward to Gitea running in your second terminal.

<!-- astrona:playground:renew -->

Change the `analysis` in `apps/podinfo/canary.yaml` so it reads:

```yaml
  analysis:
    interval: 15s
    threshold: 5
    iterations: 10
    match:
      - headers:
          x-canary:
            exact: "insider"
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
          cmd: "hey -z 1m -q 10 -c 2 -H 'X-Canary: insider' -host app.example.com http://ingress-nginx-controller.ingress-nginx/"
```

`stepWeight` and `maxWeight` are gone, and `iterations` and `match` replace them. The load test now sends the header too, otherwise no load test traffic would reach the canary. The acceptance test is left out to keep the example short.

A change to the `Canary` alone does not start an analysis; a change to the Deployment does. Change the message podinfo shows, so there is a visible difference. Then commit both files and apply:

```sh
sed -i.bak 's/value: "released by Flux"/value: "insider preview"/' apps/podinfo/deployment.yaml && rm apps/podinfo/deployment.yaml.bak
git commit -am "Test the insider message with an A/B canary"
git push
flux reconcile kustomization podinfo --with-source
```

While `kubectl -n podinfo get canary podinfo` shows `Progressing`, compare a request with the header and one without:

```sh
kubectl -n podinfo exec deploy/flagger-loadtester -- \
  curl -s -H 'Host: app.example.com' -H 'X-Canary: insider' http://ingress-nginx-controller.ingress-nginx/
kubectl -n podinfo exec deploy/flagger-loadtester -- \
  curl -s -H 'Host: app.example.com' http://ingress-nginx-controller.ingress-nginx/
```

The request with the header gets the canary: its `message` is `insider preview`. The request without it gets the primary and the old message. After ten good iterations, about two and a half minutes, Flagger promotes, and both requests get the new message.

## Blue/green and the other strategies

Flagger supports four ways to move users, and the `analysis` fields decide which one a `Canary` uses:

| Strategy | `analysis` fields | Who gets the new version during the test |
| --- | --- | --- |
| Canary release | `stepWeight`, `maxWeight` | A growing random share of all users |
| A/B testing | `iterations`, `match` | Only requests that match a header or cookie |
| Blue/green | `iterations`, no `match` | Nobody: only the test webhooks send traffic, then all users switch at once |
| Blue/green with mirroring | `iterations`, `mirror: true` | Nobody, but a copy of real traffic goes to the new version; needs a router that mirrors, such as Istio |

In blue/green, "blue" is the running version and "green" the new one. Green gets no user traffic while the webhooks and metrics test it, and the promotion switches every user in one step. Which strategies a router supports differs; the Flagger documentation lists them per provider.

## Custom metrics with a MetricTemplate

The built-in metrics cover success rate and request duration. For anything else, write a `MetricTemplate`: a Prometheus query that returns one number. Flagger fills in placeholders before it runs the query, such as `{{ namespace }}`, `{{ ingress }}` and `{{ interval }}`. Prometheus Query Language (PromQL) is the query language of Prometheus; the query below computes the 99th percentile of request duration on the canary Ingress, from ingress-nginx's own histogram.

Save this as `apps/podinfo/metrictemplate-latency.yaml`:

```yaml
apiVersion: flagger.app/v1beta1
kind: MetricTemplate
metadata:
  name: latency
  namespace: podinfo
spec:
  provider:
    type: prometheus
    address: http://flagger-prometheus.ingress-nginx:9090
  query: |
    histogram_quantile(0.99,
      sum(
        rate(
          nginx_ingress_controller_request_duration_seconds_bucket{
            namespace="{{ namespace }}",
            ingress="{{ ingress }}-canary"
          }[{{ interval }}]
        )
      ) by (le)
    )
```

Then add it to the `metrics` list of the `Canary`, with a maximum of half a second:

```yaml
      - name: latency
        templateRef:
          name: latency
        thresholdRange:
          max: 0.5
        interval: 1m
```

List `metrictemplate-latency.yaml` in `resources` of `apps/podinfo/kustomization.yaml`, commit and push. From the next analysis on, a canary whose slowest 1% of requests take longer than 0.5 seconds fails a check, just like one with too many errors. podinfo's `/delay/2` endpoint answers after two seconds, so a load test against it shows the check failing.

You can now choose who sees a new version, name the strategy a `Canary` uses from its fields, and judge a release by any number Prometheus can compute. Each of these is a change to one object in Git.

## Common pitfalls

> [!WARNING]
> - **A/B match without the header in the load test.** No load test traffic reaches the canary, and the success rate has no data.
> - **Changing only the `Canary`.** An analysis starts when the target Deployment changes, not when the `Canary` does.
> - **Keeping `stepWeight` next to `iterations` and `match`.** Use one strategy's fields per `Canary`.
> - **A query that returns no data.** Flagger cannot judge a check without a number. Run the query in Prometheus first, with the placeholders filled in by hand.
> - **`max` and `min` mixed up.** Success rate needs a minimum, latency needs a maximum.

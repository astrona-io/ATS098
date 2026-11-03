# Built-In Metrics And MetricTemplates

Flagger can only promote a release it can measure. With ingress-nginx, Flagger already knows two measurements, and for everything else it needs a query you write. This part writes the `Canary` with the two built-in checks, reads what each one measures and in which unit, and then writes the first `MetricTemplate`.

## The two built-in metrics

A metric in a `Canary` is a name, a range the value must stay inside, and the time window the value covers. Flagger reads the value from Prometheus, a time series database, with a built-in query for the provider.

| Metric | Value | Range field |
| --- | --- | --- |
| `request-success-rate` | The percentage of requests to the canary that did not end with a 5xx status code | `min`, for example `99` |
| `request-duration` | The 99th percentile of the request duration, in milliseconds | `max`, for example `500` |

The 99th percentile (p99) is the duration that 99% of the requests stay below. A p99 of 500 means that the slowest 1% of requests took 500 milliseconds or more. A success rate needs a minimum, because a low value is bad. A duration needs a maximum, because a high value is bad.

## Write the Canary with both checks

Start the port-forward to Gitea in a second terminal and leave it running. The commands need the playground to be running.

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
    threshold: 5
    maxWeight: 50
    stepWeight: 25
    metrics:
      - name: request-success-rate
        thresholdRange:
          min: 99
        interval: 1m
      - name: request-duration
        thresholdRange:
          max: 500
        interval: 1m
    webhooks:
      - name: load-test
        url: http://flagger-loadtester.podinfo/
        timeout: 5s
        metadata:
          cmd: "hey -z 1m -q 10 -c 2 -host app.example.com http://ingress-nginx-controller.ingress-nginx/"
```

Add `canary.yaml` to `resources` in `apps/podinfo/kustomization.yaml` after `ingress.yaml`. Then commit, push and apply:

```sh
git add apps/podinfo
git commit -m "Add the podinfo canary with two built-in metrics"
git push
flux reconcile kustomization podinfo --with-source
kubectl -n podinfo get canary podinfo --watch
```

The status becomes `Initialized`. Stop the watch with Ctrl+C. The first version is trusted without an analysis, so the metrics run at the next release.

## Write a MetricTemplate

The built-in metrics cover two questions. Suppose the team wants the share of failed requests, as a number that must stay below 1. It is the same information as the success rate, turned around, and it shows that a template is just a Prometheus query with a name. A `MetricTemplate` is a Flagger object that holds the address of a metrics provider and one query. Before it runs the query, Flagger replaces placeholders in double braces with values from the `Canary`:

| Placeholder | Value |
| --- | --- |
| `{{ namespace }}` | The namespace of the `Canary` |
| `{{ target }}` | The name of the target Deployment |
| `{{ ingress }}` | The name of the Ingress in `ingressRef` |
| `{{ service }}` | The name of the Service Flagger created |
| `{{ interval }}` | The `interval` of the metric in the `Canary` |

Save this as `apps/podinfo/metrictemplate-error-rate.yaml`:

```yaml
apiVersion: flagger.app/v1beta1
kind: MetricTemplate
metadata:
  name: error-rate
  namespace: podinfo
spec:
  provider:
    type: prometheus
    address: http://flagger-prometheus.ingress-nginx:9090
  query: |
    100 - sum(
      rate(
        nginx_ingress_controller_requests{
          namespace="{{ namespace }}",
          ingress="{{ ingress }}-canary",
          status!~"5.*"
        }[{{ interval }}]
      )
    )
    /
    sum(
      rate(
        nginx_ingress_controller_requests{
          namespace="{{ namespace }}",
          ingress="{{ ingress }}-canary"
        }[{{ interval }}]
      )
    ) * 100
```

The query counts requests with `rate()`, which turns a counter into requests per second over the window. It divides the requests without a 5xx status by all requests and subtracts the result from 100. The label `ingress` ends in `-canary` because ingress-nginx counts the traffic of the canary Ingress that Flagger creates, and that is the traffic you want to judge.

Add the check to the `metrics` list of the `Canary`, list the new file in `resources`, then commit and push:

```yaml
      - name: error-rate
        templateRef:
          name: error-rate
          namespace: podinfo
        thresholdRange:
          max: 1
        interval: 1m
```

```sh
git add apps/podinfo
git commit -m "Check the 5xx error rate"
git push
flux reconcile kustomization podinfo --with-source
kubectl -n podinfo get metrictemplate
```

The list shows the template `error-rate`. A `Canary` check that uses it runs at the next release.

You now know the two built-in metrics, their units and limits, and what a template adds. The template is only as good as its query, and a query that returns no number fails every release. The next part tests the query before Flagger does.

## Common pitfalls

> [!WARNING]
> - **`min` on a duration or `max` on a success rate.** The check fails for the good releases and passes for the bad ones.
> - **Mixing units.** The built-in `request-duration` is in milliseconds; a template on the nginx histogram returns seconds.
> - **A template that is not in `resources`.** Flux never applies it, and the `Canary` points at an object that does not exist.
> - **Using `{{ ingress }}` without `-canary`.** The query reads the primary Ingress, which has no data during an analysis.
> - **Expecting the first release to run the checks.** The first version is only initialized.

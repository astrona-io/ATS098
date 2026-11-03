# Writing And Testing Prometheus Queries

When a check fails, the first suspect is the release. The second suspect, and often the real cause, is the query. A query with a wrong label returns nothing, and Flagger reads "nothing" as a failed check. This part runs the same query that Flagger will run, by hand, so you see the number before it decides a release.

## What Flagger needs from a query

Prometheus Query Language (PromQL) is the language that Prometheus uses to compute values from stored time series. A query returns a vector: a list of samples, each with labels and one value. Flagger needs the vector to hold at least one sample, and it uses the value of the first one. If the vector is empty, Flagger cannot judge the check. Its events then say that no values were found and that the target is probably not receiving traffic, and the check counts as failed.

A query for a canary has a built-in trap. The canary Ingress receives traffic only while an analysis runs and only when the router sends traffic to it. Outside an analysis, the same query returns an empty vector, even when it is correct. So test a query in two steps: first with real traffic, then in an analysis.

Two more facts help. The placeholders only exist in Flagger, so you replace them by hand when you test. And a metric can take its own values through `templateVariables`, a map in the `Canary` that Flagger offers to the query as `{{ variables.name }}`. That lets one template serve several Canaries with different thresholds in the query.

## Run a query by hand

This part needs the `Canary` and the `error-rate` template from the part before, and the load tester. Prometheus answers on its HTTP API inside the cluster, and the load tester has `curl`. Check first that ingress-nginx metrics reached Prometheus. Send some traffic to the primary Ingress, then ask which series exist:

<!-- astrona:playground:renew -->

```sh
kubectl -n podinfo exec deploy/flagger-loadtester -- \
  hey -z 20s -q 10 -c 2 -host app.example.com http://ingress-nginx-controller.ingress-nginx/
kubectl -n podinfo exec deploy/flagger-loadtester -- \
  curl -s http://flagger-prometheus.ingress-nginx:9090/api/v1/label/__name__/values | tr ',' '\n' | grep nginx_ingress_controller_requests
```

The second command lists the names that start with `nginx_ingress_controller_requests`. If it prints nothing, Prometheus has not scraped the router yet; wait a minute and repeat. Now run a query with the placeholders replaced by hand. This one counts requests per second to the primary Ingress over one minute:

```sh
kubectl -n podinfo exec deploy/flagger-loadtester -- \
  curl -s -G http://flagger-prometheus.ingress-nginx:9090/api/v1/query \
  --data-urlencode 'query=sum(rate(nginx_ingress_controller_requests{namespace="podinfo",ingress="podinfo"}[1m]))'
```

The answer is JSON. Its `status` is `success`, and `data.result` holds one sample whose `value` is a pair of a timestamp and the number as text. Now ask for the canary Ingress, the one Flagger will query:

```sh
kubectl -n podinfo exec deploy/flagger-loadtester -- \
  curl -s -G http://flagger-prometheus.ingress-nginx:9090/api/v1/query \
  --data-urlencode 'query=sum(rate(nginx_ingress_controller_requests{namespace="podinfo",ingress="podinfo-canary"}[1m]))'
```

The `status` is still `success`, but `data.result` is an empty list: no traffic has reached the canary Ingress. That is the empty vector that fails a check. During an analysis, with the load-test webhook, the same query returns a sample.

## Release and compare

Release `6.14.1` and run the canary query again while the status is `Progressing` with a weight above 0:

```sh
sed -i.bak 's/newTag: 6.14.0/newTag: 6.14.1/' apps/podinfo/kustomization.yaml && rm apps/podinfo/kustomization.yaml.bak
git commit -am "Release podinfo 6.14.1"
git push
flux reconcile kustomization podinfo --with-source
kubectl -n podinfo describe canary podinfo | sed -n '/^Events:/,$p'
```

The events show each metric check of each step, with the metric name. The result of the manual query during `Progressing` is close to the value Flagger read for `request-success-rate` or your template, because both read the same series.

You can now test a query before it decides a release, and you know that an empty answer is a failed check, not a passed one. Metrics judge numbers. The next part adds checks that call any system over HTTP, and gates that a person controls.

## Common pitfalls

> [!WARNING]
> - **Testing the canary query outside an analysis.** It returns nothing then, and a correct query looks broken.
> - **Leaving a placeholder in the query you run by hand.** Prometheus answers with a parse error, not with a number.
> - **A query that returns several samples.** Flagger uses the first one; add `sum(...)` to make it one.
> - **Using `rate()` with a window shorter than the scrape interval.** There are not enough points, and the result is empty.
> - **Quoting the query wrongly in the shell.** Use single quotes around the whole `query=` argument, and double quotes for label values inside it.

## Your mission: Gate A Release On A Custom Latency Metric

You can now write a `MetricTemplate`, test its query and attach it to a `Canary`. The graded lab starts with a `Canary` that only checks the success rate. It asks you to add a template for the 99th percentile latency of the canary, in Git, to gate the `Canary` on it, and to release `6.14.1` through it.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-098-playground-030-03
```

Then start the lab:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS098.git -c sections/section-030/module-03/labs/lab-01
```

The task is on the next page. Solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-030/module-03/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-098-lab-030-03
astrona start ats-098-playground-030-03
```

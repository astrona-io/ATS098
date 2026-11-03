# Solution: Gate A Release On A Custom Latency Metric

Work the task yourself first. Running `astrona submit -c sections/section-030/module-03/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks three things: the `MetricTemplate` and the `latency` check come from Git, Git asks for `6.14.1`, and Flagger promoted `6.14.1` to `podinfo-primary`.

## Step 1: Check the starting state

```sh
kubectl -n podinfo get canary podinfo
kubectl -n podinfo get canary podinfo -o jsonpath='{.spec.analysis.metrics}'
```

The `Canary` is `Initialized` and has one metric, `request-success-rate`.

## Step 2: Write the MetricTemplate

Start the port-forward in a second terminal, then clone:

```sh
git clone http://gitops:gitops-password@gitea.localtest.me:3000/gitops/fleet.git
cd fleet
```

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

## Step 3: Use it in the Canary

In `apps/podinfo/canary.yaml`, add a second metric under `metrics`:

```yaml
      - name: latency
        templateRef:
          name: latency
          namespace: podinfo
        thresholdRange:
          max: 0.5
        interval: 1m
```

List the template in `apps/podinfo/kustomization.yaml`:

```yaml
resources:
  - namespace.yaml
  - deployment.yaml
  - ingress.yaml
  - canary.yaml
  - metrictemplate-latency.yaml
```

## Step 4: Commit and wait for Flux

```sh
git add apps/podinfo/metrictemplate-latency.yaml
git commit -am "Check latency in the podinfo canary"
git push
flux reconcile kustomization podinfo --with-source
kubectl -n podinfo get metrictemplate latency
```

The template exists. A change to the `Canary` alone does not start an analysis.

## Step 5: Release 6.14.1

```sh
sed -i.bak 's/newTag: 6.14.0/newTag: 6.14.1/' apps/podinfo/kustomization.yaml && rm apps/podinfo/kustomization.yaml.bak
git commit -am "Release podinfo 6.14.1"
git push
flux reconcile kustomization podinfo --with-source
kubectl -n podinfo get canary podinfo --watch
```

The status moves through `Progressing` to `Succeeded`.

## Step 6: Check the result

```sh
kubectl -n podinfo describe canary podinfo | sed -n '/^Events:/,$p'
kubectl -n podinfo get deployment podinfo-primary -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

The primary runs `ghcr.io/stefanprodan/podinfo:6.14.1`.

## Step 7: Submit

```sh
astrona submit -c sections/section-030/module-03/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| `min: 0.5` instead of `max: 0.5` | A fast canary fails the check, because latency needs a maximum |
| `ingress="{{ ingress }}"` without `-canary` | The query reads the primary Ingress, which has no data during the analysis |
| A template file that `kustomization.yaml` does not list | Flux never applies it, and the `Canary` refers to a template that does not exist |
| `skipAnalysis: true` | Promotes without checks; the grader rejects it |

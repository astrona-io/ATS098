# Solution: Switch A Release To A/B Testing With A Header

Work the task yourself first. Running `astrona submit -c sections/section-030/module-02/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks three things: the `Canary` comes from Git as an A/B test with the header `x-canary: insider`, Git asks for `6.14.1`, and Flagger promoted `6.14.1` to `podinfo-primary`.

## Step 1: Check the starting state

```sh
kubectl -n podinfo get canary podinfo
kubectl -n podinfo get canary podinfo -o jsonpath='{.spec.analysis}'
```

The `Canary` is `Initialized` and its analysis has `stepWeight: 25` and `maxWeight: 50`. That is a weighted canary release: it sends a random share of all users to the new version.

## Step 2: Change the analysis

Start the port-forward in a second terminal, then clone:

```sh
git clone http://gitops:gitops-password@gitea.localtest.me:3000/gitops/fleet.git
cd fleet
```

In `apps/podinfo/canary.yaml`, replace `maxWeight` and `stepWeight` with `iterations` and `match`, and add the header to the load test. The `analysis` reads:

```yaml
  analysis:
    interval: 15s
    threshold: 5
    iterations: 6
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

## Step 3: Commit and wait for Flux

```sh
git commit -am "Test podinfo with an A/B canary"
git push
flux reconcile kustomization podinfo --with-source
kubectl -n podinfo get canary podinfo -o jsonpath='{.spec.analysis.iterations}{"\n"}'
```

The last command prints `6`. The change to the `Canary` does not start an analysis.

## Step 4: Release 6.14.1

```sh
sed -i.bak 's/newTag: 6.14.0/newTag: 6.14.1/' apps/podinfo/kustomization.yaml && rm apps/podinfo/kustomization.yaml.bak
git commit -am "Release podinfo 6.14.1"
git push
flux reconcile kustomization podinfo --with-source
kubectl -n podinfo get canary podinfo --watch
```

The status moves to `Progressing`, and the `WEIGHT` column stays `0` during the test, because an A/B test does not raise a weight. After six good iterations, the status is `Succeeded`.

## Step 5: Check the result

```sh
kubectl -n podinfo describe canary podinfo | sed -n '/^Events:/,$p'
kubectl -n podinfo get deployment podinfo-primary -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

The primary runs `ghcr.io/stefanprodan/podinfo:6.14.1`.

## Step 6: Submit

```sh
astrona submit -c sections/section-030/module-02/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Keeping `stepWeight` and `maxWeight` next to `iterations` | The `Canary` mixes two strategies; the grader rejects it |
| A load test without the header | No test traffic reaches the canary, the success rate has no data, and the analysis fails |
| Changing the `Canary` and the tag in one commit | Works in Flagger, but you cannot tell which change did what; make the strategy change first |
| `skipAnalysis: true` | Promotes without checks; the grader rejects it |
| `kubectl edit canary podinfo` | The change is not in Git, and Flux sets the old spec back |

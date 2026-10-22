# Solution: Promote A New Version Through A Canary

Work the task yourself first. Running `astrona submit -c sections/section-030/module-01/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks three things: the `Canary` comes from Git with the requested analysis, Git asks for `6.14.1`, and Flagger promoted `6.14.1` to `podinfo-primary`.

## Step 1: Check the starting state

```sh
flux get helmreleases
kubectl -n podinfo get deployments,services,ingresses
```

The three HelmReleases are `Ready`. The namespace `podinfo` holds the Deployments `podinfo` and `flagger-loadtester` and the Ingress `podinfo`, and no `podinfo` Service yet.

## Step 2: Write the Canary

Start the port-forward in a second terminal, then clone:

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
    webhooks:
      - name: load-test
        url: http://flagger-loadtester.podinfo/
        timeout: 5s
        metadata:
          cmd: "hey -z 1m -q 10 -c 2 -host app.example.com http://ingress-nginx-controller.ingress-nginx/"
```

An acceptance test webhook is allowed but not required.

## Step 3: List it and commit

Change the `resources` in `apps/podinfo/kustomization.yaml` so they read:

```yaml
resources:
  - namespace.yaml
  - deployment.yaml
  - ingress.yaml
  - canary.yaml
```

Commit, push and apply, then wait for the initialization:

```sh
git add apps/podinfo/canary.yaml apps/podinfo/kustomization.yaml
git commit -m "Add the podinfo canary"
git push
flux reconcile kustomization podinfo --with-source
kubectl -n podinfo get canary podinfo --watch
```

Stop the watch with Ctrl+C when the status is `Initialized`. `podinfo-primary` now runs `6.14.0`, and the Deployment `podinfo` is scaled to zero.

## Step 4: Release 6.14.1

```sh
sed -i.bak 's/newTag: 6.14.0/newTag: 6.14.1/' apps/podinfo/kustomization.yaml && rm apps/podinfo/kustomization.yaml.bak
git commit -am "Release podinfo 6.14.1"
git push
flux reconcile kustomization podinfo --with-source
kubectl -n podinfo get canary podinfo --watch
```

The status moves through `Progressing` with weights `25` and `50` to `Succeeded`. It takes a few minutes.

## Step 5: Check the promotion

```sh
kubectl -n podinfo describe canary podinfo | sed -n '/^Events:/,$p'
kubectl -n podinfo get deployment podinfo-primary -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

The events end with the promotion, and the primary runs `ghcr.io/stefanprodan/podinfo:6.14.1`.

## Step 6: Submit

```sh
astrona submit -c sections/section-030/module-01/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Add the `Canary` and the new tag in one commit | Flagger initializes `6.14.1` without analysis; the status is `Initialized`, never `Succeeded` |
| `skipAnalysis: true` | Promotes without checks; the grader rejects it |
| A load test without `-host app.example.com` | ingress-nginx has no rule for the request, the canary gets no traffic, and the analysis fails |
| A `podinfo` Service in Git | Flux and Flagger both own it and fight over it |
| `kubectl apply -f canary.yaml` | The `Canary` is not in Git, and the grader checks the Flux inventory |

# Solution: Ship A Release From Registry To Primary

Work the task yourself first. Running `astrona submit -c sections/section-030/capstone/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks three things: the policy and the automation come from Git and the automation updates `apps/podinfo`, the `Canary` load test calls the load tester in `podinfo`, and a release of `6.15.0` goes all the way to `podinfo-primary` through a commit by `fluxcdbot@example.com` and a `Succeeded` analysis.

Follow one release in pipeline order: policy, automation, Flux, Flagger. Each stop hides the next one.

## Step 1: Start a release and read the policy

```sh
kubectl -n registry exec deploy/registry-tools -- \
  regctl image copy ghcr.io/stefanprodan/podinfo:6.14.1 registry.localtest.me:5000/podinfo:6.14.1
flux reconcile image repository podinfo
flux get image policy podinfo
```

The scan is fine, and the policy chooses `6.14.1`. It looks right, but read the range:

```sh
kubectl -n flux-system get imagepolicy podinfo -o jsonpath='{.spec.policy.semver.range}{"\n"}'
```

The range is `6.14.x` (fault one). It follows patch releases of 6.14 only, so `6.15.0` would never be chosen. The task asks for every stable `6.x` release.

## Step 2: Read the automation

```sh
flux reconcile image update podinfo
flux get image update podinfo
kubectl -n flux-system get imageupdateautomation podinfo -o jsonpath='{.spec.update.path}{"\n"}'
```

The automation reports no push, although the policy chose `6.14.1` and the marker in Git still says `6.14.0`. Its `update.path` is `./apps/podinfo-old` (fault two), a folder that does not exist, so it finds no marker.

## Step 3: Read the canary

```sh
kubectl -n podinfo get canary podinfo -o jsonpath='{.spec.analysis.webhooks[?(@.name=="load-test")].url}{"\n"}'
kubectl -n podinfo get service flagger-loadtester
```

The load-test webhook calls `http://flagger-loadtester.test/` (fault three), but the load tester runs in the namespace `podinfo`. During an analysis the webhook call fails and no traffic reaches the canary, so every check fails and Flagger rolls back. This fault only shows once a release reaches Flagger, which is why it is the last one you find.

## Step 4: Fix all three in Git

Clone the repository; the port-forward must run in your second terminal:

```sh
git clone http://gitops:gitops-password@gitea.localtest.me:3000/gitops/fleet.git
cd fleet
```

In `clusters/kind/image-podinfo.yaml`, change the range so the policy reads:

```yaml
  policy:
    semver:
      range: '6.x'
```

In `clusters/kind/image-automation.yaml`, change the update part so it reads:

```yaml
  update:
    path: ./apps/podinfo
    strategy: Setters
```

In `apps/podinfo/canary.yaml`, change the URL of the `load-test` webhook so it reads:

```yaml
      - name: load-test
        url: http://flagger-loadtester.podinfo/
```

Commit, push and apply everything:

```sh
git commit -am "Follow 6.x, update apps/podinfo, load test in podinfo"
git push
flux reconcile kustomization fleet --with-source
flux reconcile kustomization podinfo --with-source
```

## Step 5: Ship 6.14.1

Run the pipeline now instead of waiting:

```sh
flux reconcile image update podinfo
flux reconcile kustomization podinfo --with-source
kubectl -n podinfo get canary podinfo --watch
```

The automation commits `6.14.1`, Flux changes the Deployment `podinfo`, and Flagger moves through `Progressing` to `Succeeded`. Stop the watch with Ctrl+C, then confirm:

```sh
git pull
git log -1 --format='%ae %s' -- apps/podinfo/kustomization.yaml
kubectl -n podinfo get deployment podinfo-primary -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

The last change is by `fluxcdbot@example.com`, and the primary runs `ghcr.io/stefanprodan/podinfo:6.14.1`.

## Step 6: Submit

```sh
astrona submit -c sections/section-030/capstone/labs/lab-01
```

The grader copies `6.15.0` into the registry and follows it through the same pipeline. Its analysis takes a few minutes.

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| `skipAnalysis: true` | Promotes without checks; the grader rejects it |
| Remove the load-test webhook | No traffic during the analysis, so the success rate has no data and the release rolls back |
| Set `newTag` by hand | The last change is not by `fluxcdbot`, and the next release stops again |
| Lower the success rate minimum | The task keeps it at 99, and the real fault is the missing traffic |

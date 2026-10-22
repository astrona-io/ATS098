# Solution: Repair A Release Loop That Never Commits

Work the task yourself first. Running `astrona submit -c sections/section-020/capstone/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks four things: the scan is `Ready`, the marker is right, the automation pushes to `main` under the right path, and a real release of `6.15.0` reaches the Deployment through a commit by `fluxcdbot@example.com`.

The method is to follow one release through the loop, in the order the controllers handle it: scan, policy, automation, commit, sync. Each step either works or shows the next fault.

## Step 1: Start a release and look at the whole loop

Copy `6.14.1` into the registry and ask every image object for its state:

```sh
kubectl -n registry exec deploy/registry-tools -- \
  regctl image copy ghcr.io/stefanprodan/podinfo:6.14.1 registry.localtest.me:5000/podinfo:6.14.1
flux reconcile image repository podinfo
flux get image all
```

The `ImageRepository` `podinfo` is not `Ready`, and its message names a failed request to `registry.localtest.me:5000`. The policy has no new tag to choose. That is the first stop.

## Step 2: Fix the scan

```sh
kubectl -n flux-system get imagerepository podinfo -o jsonpath='{.spec}{"\n"}'
```

There is no `insecure: true`, and the lab registry only speaks plain HTTP (fault one). Clone the repository; the port-forward must run in your second terminal:

```sh
git clone http://gitops:gitops-password@gitea.localtest.me:3000/gitops/fleet.git
cd fleet
```

Change the `ImageRepository` in `clusters/kind/image-podinfo.yaml` so its `spec` reads:

```yaml
spec:
  image: registry.localtest.me:5000/podinfo
  interval: 1m
  # The lab registry has no TLS. A real registry uses HTTPS.
  insecure: true
```

Commit, push, apply and check:

```sh
git commit -am "Scan the lab registry over HTTP"
git push
flux reconcile kustomization fleet --with-source
flux reconcile image repository podinfo
flux get image policy podinfo
```

The scan is `Ready`, and the policy chooses `6.14.1`.

## Step 3: Read the automation

```sh
flux reconcile image update podinfo
flux get image update podinfo
kubectl -n flux-system get imageupdateautomation podinfo -o jsonpath='{.spec.update}{"\n"}{.spec.git.push}{"\n"}'
```

The automation reports no push. Its `update.path` is `./app/podinfo`, a folder that does not exist (fault two), so it finds no markers. Its push branch is `release` (fault three): even a working commit would land on a branch Flux does not apply. Now read the marker:

```sh
grep newTag apps/podinfo/kustomization.yaml
```

The marker names the policy `flux-system:podinfo-release` (fault four). That policy does not exist, so even with the right path the line would never change.

## Step 4: Fix the automation and the marker

Change the end of `clusters/kind/image-automation.yaml` so it reads:

```yaml
    push:
      branch: main
  update:
    path: ./apps/podinfo
    strategy: Setters
```

Change the `newTag` line in `apps/podinfo/kustomization.yaml` so it reads:

```yaml
    newTag: 6.14.0 # {"$imagepolicy": "flux-system:podinfo:tag"}
```

Commit, push, and run the loop:

```sh
git commit -am "Update apps/podinfo, push to main, mark the podinfo policy"
git push
flux reconcile kustomization fleet --with-source
flux reconcile image update podinfo
flux reconcile kustomization podinfo --with-source
```

## Step 5: Check the release

```sh
git pull
git log -1 --format='%ae %s' -- apps/podinfo/kustomization.yaml
kubectl -n podinfo get deployment podinfo -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

The last change is by `fluxcdbot@example.com`, and podinfo runs `ghcr.io/stefanprodan/podinfo:6.14.1`.

## Step 6: Submit

```sh
astrona submit -c sections/section-020/capstone/labs/lab-01
```

The grader repeats the loop with `6.15.0`.

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Rename the policy to `podinfo-release` | The marker matches, but the task keeps the names, and the marker check fails |
| Merge the `release` branch by hand | A person merges every release, which the task rules out |
| `update.path: ./` without fixing the marker | The automation finds the file, but the marker still names a policy that does not exist |
| Set `newTag: 6.15.0` by hand | The commit is not by `fluxcdbot`, and the next release stops again |

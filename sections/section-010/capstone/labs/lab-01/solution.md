# Solution: Track The Newest Main Build

Work the task yourself first. Running `astrona submit -c sections/section-010/capstone/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks two things: the `ImageRepository` `podinfo-builds` comes from Git, is `Ready` and keeps `main-` tags; and the `ImagePolicy` `podinfo-main` comes from Git and follows a newer `main` build while it ignores a newer pull request build.

There are three faults, and they hide each other. The scan fails first, so you only see the second fault once the first is fixed.

## Step 1: Read the scan

```sh
flux get image repository podinfo-builds
flux get image policy podinfo-main
```

The repository is not `Ready`, and its message names a failed request to `registry.localtest.me:5000`. Without `insecure: true` the controller talks HTTPS, and the lab registry only speaks plain HTTP. The policy has nothing to choose from. Read the object:

```sh
kubectl -n flux-system get imagerepository podinfo-builds -o yaml | grep -A6 '^spec:'
```

There is no `insecure: true` (fault one), and the `exclusionList` holds `^main-.*` (fault two). Once the scan works, that expression throws away every tag the policy needs.

## Step 2: Read the policy

```sh
kubectl -n flux-system get imagepolicy podinfo-main -o jsonpath='{.spec}{"\n"}'
```

The pattern keeps `main-` tags, which is right. The rule is `numerical`, but nothing is extracted, so the rule gets the whole tag, and `main-0c1d2e3-1760007200` is not a number (fault three). The rule needs the timestamp alone: a named group in the pattern and `extract`.

## Step 3: Fix all three in Git

Clone the repository; the port-forward must run in your second terminal:

```sh
git clone http://gitops:gitops-password@gitea.localtest.me:3000/gitops/fleet.git
cd fleet
```

Change `clusters/kind/image-builds.yaml` so the whole file reads:

```yaml
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImageRepository
metadata:
  name: podinfo-builds
  namespace: flux-system
spec:
  image: registry.localtest.me:5000/podinfo-builds
  interval: 1m
  # The lab registry has no TLS. A real registry uses HTTPS.
  insecure: true
---
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImagePolicy
metadata:
  name: podinfo-main
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: podinfo-builds
  filterTags:
    pattern: '^main-[a-f0-9]+-(?P<ts>[0-9]+)$'
    extract: '$ts'
  policy:
    numerical:
      order: asc
```

Removing `exclusionList` brings back the default, `^.*\.sig$`. Commit, push and apply:

```sh
git commit -am "Scan main builds and sort them by timestamp"
git push
flux reconcile kustomization fleet --with-source
flux reconcile image repository podinfo-builds
```

## Step 4: Check the choice

```sh
flux get image repository podinfo-builds
flux get image policy podinfo-main
```

The repository is `Ready`, and the policy chooses `main-0c1d2e3-1760007200`. The pull request build `pr-41-5e6f7a8-1760009000` has a higher timestamp, and the pattern keeps it out.

## Step 5: Prove it follows the next build

```sh
kubectl -n registry exec deploy/registry-tools -- \
  regctl image copy registry.localtest.me:5000/podinfo-builds:main-0c1d2e3-1760007200 \
  registry.localtest.me:5000/podinfo-builds:main-aaaaaaa-1760010800
flux reconcile image repository podinfo-builds
flux get image policy podinfo-main
```

The policy moves to `main-aaaaaaa-1760010800`. The task asks you not to add tags yourself, but this tag is the one the grader adds, so adding it does no harm.

## Step 6: Submit

```sh
astrona submit -c sections/section-010/capstone/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| `alphabetical` on the whole `main-` tag | Sorts by the commit hash and chooses `main-9f8e7d6-1760003600` |
| A pattern `^.*-(?P<ts>[0-9]+)$` | Also keeps pull request builds, so `pr-42-...` wins |
| Removing only `^main-.*` from `exclusionList` | The scan still fails without `insecure: true` |
| `kubectl edit` on either object | The grader makes Flux apply Git first |

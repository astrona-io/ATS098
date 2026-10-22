# Solution: Pick The Newest Stable Release

Work the task yourself first. Running `astrona submit -c sections/section-010/module-01/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks two things: the `ImagePolicy` `podinfo` comes from Git and uses a SemVer range, and after it adds `6.15.1`, `6.16.0-rc.2` and `7.0.0` to the registry, the policy chooses `6.15.1`.

## Step 1: Read the current choice

List the scan and the policy:

```sh
flux get image repository podinfo
flux get image policy podinfo
```

The scan is `Ready` and found nine tags. The policy chooses `latest`. Read the rule:

```sh
kubectl -n flux-system get imagepolicy podinfo -o jsonpath='{.spec.policy}{"\n"}'
```

The rule is `alphabetical` with `order: asc`: sort the tags as text and take the last one. As text, `latest` sorts after every tag that starts with a digit, and without it `7.0.0-rc.1` would win. Alphabetical order knows nothing about versions.

## Step 2: Choose the rule

The task is "the newest stable release with major version 6". That is a SemVer rule with the range `6.x`:

- `6.x` matches every version with major version 6, so `7.0.0` does not count.
- A range without a pre-release part never matches a pre-release, so `6.16.0-rc.1` does not count.
- `latest` is not a version, so a SemVer rule ignores it.

An open range such as `>=6.0.0` would pass today and fail when `7.0.0` arrives.

## Step 3: Change the policy in Git

Start the port-forward in a second terminal if it is not running, then clone the repository:

```sh
git clone http://gitops:gitops-password@gitea.localtest.me:3000/gitops/fleet.git
cd fleet
```

Change `clusters/kind/image-podinfo.yaml` so the whole file reads:

```yaml
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImageRepository
metadata:
  name: podinfo
  namespace: flux-system
spec:
  image: registry.localtest.me:5000/podinfo
  interval: 1m
  # The lab registry has no TLS. A real registry uses HTTPS.
  insecure: true
---
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImagePolicy
metadata:
  name: podinfo
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: podinfo
  policy:
    semver:
      range: '6.x'
```

Commit and push it:

```sh
git commit -am "Choose the newest stable 6.x release"
git push
```

## Step 4: Make Flux apply it and check

```sh
flux reconcile kustomization fleet --with-source
flux get image policy podinfo
```

The policy now chooses `6.15.0`.

## Step 5: Prove it follows the next release

Add the tags the grader will add, and scan again:

```sh
for new_tag in 6.15.1 6.16.0-rc.2 7.0.0; do
  kubectl -n registry exec deploy/registry-tools -- \
    regctl image copy registry.localtest.me:5000/podinfo:6.15.0 "registry.localtest.me:5000/podinfo:$new_tag"
done
flux reconcile image repository podinfo
flux get image policy podinfo
```

The policy moves to `6.15.1` and ignores the release candidate and `7.0.0`.

## Step 6: Submit

```sh
astrona submit -c sections/section-010/module-01/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| `kubectl edit imagepolicy podinfo` | The grader makes Flux apply Git first, and Git still says `alphabetical` |
| The range `>=6.0.0` or `*` | Passes today; chooses `7.0.0` when it arrives |
| `alphabetical` with `order: desc` | Chooses the first tag as text, `6.12.0`, not the newest |
| Leaving out `latest` with `exclusionList` only | The alphabetical rule then chooses `7.0.0-rc.1` |

## Practice on your own

- Change the range so the policy also follows 6.16 release candidates, and check that it chooses `6.16.0-rc.2`.
- Add `6.9.0` to the registry and explain why the alphabetical rule would put it above `6.15.0`.

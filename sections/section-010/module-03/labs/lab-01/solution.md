# Solution: Follow Release Candidates And Reflect Digests

Work the task yourself first. Running `astrona submit -c sections/section-010/module-03/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks two things: the `ImagePolicy` `podinfo` comes from Git, has `digestReflectionPolicy: Always` with an `interval`, chooses `6.16.0-rc.2` and shows a digest; and after it adds `6.16.0` and `7.0.0` to the registry, the policy chooses `6.16.0`.

## Step 1: Read the current choice

```sh
flux get image policy podinfo
kubectl -n flux-system get imagepolicy podinfo -o jsonpath='{.spec.policy}{"\n"}'
```

The policy chooses `6.15.0`. Its rule is the SemVer range `6.x`. A range without a pre-release part never matches a pre-release, so `6.16.0-rc.1` and `6.16.0-rc.2` do not count.

## Step 2: Choose the range

A range that includes pre-releases needs a pre-release part in every comparison of the range. The part `-0` is the lowest possible pre-release, so `>=6.0.0-0` accepts every pre-release and release from 6.0.0 up, and `<7.0.0-0` stops before every version of 7, `7.0.0-rc.1` included. If the upper bound were `<7.0.0`, the release candidate `6.16.0-rc.2` would not match it, because that comparison has no pre-release part.

## Step 3: Choose the digest setting

`digestReflectionPolicy: Always` makes the controller read the digest of the image on every reconciliation of the policy, so a tag that moves changes the digest in the status. The setting needs `spec.interval`, which sets how often the policy is checked.

## Step 4: Change the policy in Git

Start the port-forward in a second terminal if it is not running, then clone the repository:

```sh
git clone http://gitops:gitops-password@gitea.localtest.me:3000/gitops/fleet.git
cd fleet
```

Change the `ImagePolicy` in `clusters/kind/image-podinfo.yaml` so it reads:

```yaml
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImagePolicy
metadata:
  name: podinfo
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: podinfo
  interval: 1m
  digestReflectionPolicy: Always
  policy:
    semver:
      range: '>=6.0.0-0 <7.0.0-0'
```

Leave the `ImageRepository` as it is. Commit and push:

```sh
git commit -am "Follow 6.x release candidates and reflect the digest"
git push
```

## Step 5: Make Flux apply it and check

```sh
flux reconcile kustomization fleet --with-source
flux get image policy podinfo
kubectl -n flux-system get imagepolicy podinfo -o jsonpath='{.status.latestRef}{"\n"}'
```

The policy chooses `6.16.0-rc.2`, and the status holds a `digest` that starts with `sha256:`. The identifier `rc.2` is higher than `rc.1`, and the policy ignores `7.0.0-rc.1`.

## Step 6: Prove it follows the stable release

Add the tags the grader will add, and scan again:

```sh
for new_tag in 6.16.0 7.0.0; do
  kubectl -n registry exec deploy/registry-tools -- \
    regctl image copy registry.localtest.me:5000/podinfo:6.15.0 "registry.localtest.me:5000/podinfo:$new_tag"
done
flux reconcile image repository podinfo
flux get image policy podinfo
```

The policy moves to `6.16.0`: a release is higher than its own release candidates. It ignores `7.0.0`.

## Step 7: Submit

```sh
astrona submit -c sections/section-010/module-03/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| `kubectl edit imagepolicy podinfo` | The grader makes Flux apply Git first, and Git still says `6.x` |
| The range `>=6.0.0-0 <7.0.0` | The upper comparison has no pre-release part, so release candidates do not match it |
| The range `>=6.0.0-0` | Follows `7.0.0-rc.1` and then `7.0.0` |
| `digestReflectionPolicy: Always` without `interval` | The policy is not accepted, because the setting needs an interval |
| `alphabetical` order | Chooses `7.0.0-rc.1`, and `6.16.0-rc.10` would sort below `6.16.0-rc.2` |

## Practice on your own

- Add the tag `6.16.0-rc.10` and check that it is chosen before `6.16.0-rc.2`.
- Move the tag `6.16.0-rc.2` to another image with `regctl image copy` and watch the digest change after the next policy interval.
- Change `digestReflectionPolicy` to `IfNotPresent` and repeat the previous step.

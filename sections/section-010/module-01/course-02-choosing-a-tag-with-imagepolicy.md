# Choosing A Tag With ImagePolicy

The scan of `podinfo` keeps eight tags: five releases, `6.16.0-rc.1` and `7.0.0-rc.1`. Flux needs exactly one of them, and the right one is `6.15.0`: the newest stable release in the major version you run. This part writes the rule that gives that answer. It compares three rules on the same tags, because the wrong ones look right until a new tag arrives.

## What an ImagePolicy does

An `ImagePolicy` points at one `ImageRepository` and holds one rule for choosing a tag. The image reflector controller applies the rule to the tags of the scan and writes the winner into the policy's status, in `.status.latestRef`, as an image name and a tag. Each time the scan changes, the controller applies the rule again.

There are three kinds of rule, and each one orders the tags differently:

| Rule | How it orders the tags | Chooses |
| --- | --- | --- |
| `semver` with a `range` | As semantic versions; only tags that are versions and fit the range count | The highest version in the range |
| `numerical` with an `order` | As numbers; every tag must be a number | The last tag (`order: asc`, the default) |
| `alphabetical` with an `order` | As text, character by character | The last tag (`order: asc`, the default) |

A semantic version (SemVer) is a tag of the form `MAJOR.MINOR.PATCH`, such as `6.15.0`, with an optional pre-release part after a hyphen, such as `-rc.1`. A pre-release is a version before the release: `6.16.0-rc.1` comes before `6.16.0`.

## Compare three policies on the same tags

The quickest way to see the difference is to run three policies side by side. Each one gets its own name, and all three point at the same `ImageRepository`. The commands below need the `ImageRepository` `podinfo` from your clone of `gitops/fleet`, with `latest` left out of the scan.

<!-- astrona:playground:renew -->

Save this as `clusters/kind/image-policies-compare.yaml` in your clone:

```yaml
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImagePolicy
metadata:
  name: podinfo-alphabetical
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: podinfo
  policy:
    alphabetical:
      order: asc
---
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImagePolicy
metadata:
  name: podinfo-any-version
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: podinfo
  policy:
    semver:
      range: '>=6.0.0'
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

Commit and push it, then make Flux apply it and list the choices:

```sh
git add clusters/kind/image-policies-compare.yaml
git commit -m "Compare three image policies"
git push
flux reconcile kustomization fleet --with-source
flux get image policy
```

The alphabetical policy chooses `7.0.0-rc.1`. As text, `7` comes after `6`, and the policy knows nothing about versions or pre-releases. Both SemVer policies choose `6.15.0`. The range `6.x` means "any version with major version 6", and `>=6.0.0` means "version 6.0.0 or higher". Neither range names a pre-release, and a SemVer range without a pre-release part never matches one. So `6.16.0-rc.1` and `7.0.0-rc.1` do not count, even though they are higher.

## Make the policies disagree

Today the two SemVer policies agree. They stop agreeing when the next major version is released. Add the tag `7.0.0` to the lab registry; the helper copies the image that `6.15.0` points at under the new name, because only the tag matters here:

```sh
retag_podinfo() {
  # retag_podinfo FROM TO: adds tag TO to the image that tag FROM points at, in the lab registry.
  kubectl -n registry exec deploy/registry-tools -- \
    regctl image copy "registry.localtest.me:5000/podinfo:$1" "registry.localtest.me:5000/podinfo:$2"
}
retag_podinfo 6.15.0 7.0.0
```

Then scan again and compare:

```sh
flux reconcile image repository podinfo
flux get image policy
```

Now `podinfo-any-version` chooses `7.0.0`, and `podinfo` stays on `6.15.0`. A new major version usually breaks something, so most teams only follow minor and patch releases automatically. That rule is the range `6.x`, or written out, `>=6.0.0 <7.0.0`. The alphabetical policy also chose `7.0.0`, for the wrong reason.

The numerical rule is not in the comparison, because it needs tags that are plain numbers, such as a build number `1834` or a timestamp. A tag such as `6.15.0` is not a number, so a numerical policy on these tags reports an error instead of a choice.

## Keep only the policy you need

The comparison policies were for learning. Remove the file from Git; Flux prunes the two extra policies, and the `podinfo` policy stays, because it now needs a home of its own. Save this at the end of `clusters/kind/image-podinfo.yaml`, after the `ImageRepository`:

```yaml
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

Commit both changes in one commit, so the `podinfo` policy is never missing:

```sh
git rm clusters/kind/image-policies-compare.yaml
git commit -am "Keep the 6.x policy for podinfo"
git push
flux reconcile kustomization fleet --with-source
flux get image policy
```

Only `podinfo` is left, and it chooses `6.15.0`.

You can now predict what a policy chooses from its rule and the tags, and you have seen why the obvious rules fail: alphabetical order ignores what a version means, and an open range follows the next major version. The tags so far were tidy version numbers. Build pipelines often push tags that are not versions at all, and those need a filter before any rule can sort them.

## Common pitfalls

> [!WARNING]
> - **Using `alphabetical` for version tags.** It sorts text, so `7.0.0-rc.1` beats `6.15.0` and `6.9.0` beats `6.15.0`.
> - **An open range such as `>=6.0.0` or `*`.** It follows the next major version the day it is released.
> - **Expecting a release candidate to be chosen.** A range without a pre-release part never matches `-rc` tags. Write the pre-release part into the range only if you want them.
> - **A numerical policy on tags that are not numbers.** The policy reports an error and chooses nothing.
> - **Reading the choice from `latestTags`.** The choice is in the policy's `.status.latestRef.tag`, shown by `flux get image policy`.

## Your mission: Pick The Newest Stable Release

You can now write an `ImagePolicy` that follows stable releases inside one major version and ignores pre-releases. The graded lab gives you a policy in Git that chooses the wrong tag, and asks you to fix it in Git so it chooses the newest stable 6.x release, also after new tags arrive.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-098-playground-010-01
```

Then start the lab:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS098.git -c sections/section-010/module-01/labs/lab-01
```

The task is on the next page. Solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-010/module-01/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-098-lab-010-01
astrona start ats-098-playground-010-01
```

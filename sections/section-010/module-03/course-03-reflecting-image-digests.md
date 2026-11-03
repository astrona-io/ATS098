# Reflecting Image Digests

A tag is a name, and the owner of the registry can move a name. Pushing `6.15.0` again with a rebuilt image gives the same tag and a different image. A policy that only reads tags sees no change, and nothing rolls out. This part introduces the digest, the identifier that cannot move, and the policy setting that records it.

## Tag and digest

An image in a registry is described by a manifest, a small JSON document that lists the layers of the image. The digest is the SHA-256 hash of that manifest, written as `sha256:` followed by 64 hexadecimal characters. Two images with the same digest are identical. A tag points at one digest at a time, and the registry owner can change which one.

A pull by digest, written `image@sha256:...`, always returns the same image. A pull by tag returns whatever the tag points at now. Production setups that need to prove what they run pin the digest, and the tag only tells people what the digest is.

The `regctl` tool shows both sides. Run it in the pod `registry-tools`:

<!-- astrona:playground:renew -->

```sh
kubectl -n registry exec deploy/registry-tools -- \
  regctl image digest registry.localtest.me:5000/podinfo:6.15.0
```

The output is one `sha256:` line, the digest that `6.15.0` points at now.

## The three settings

The `ImagePolicy` field `digestReflectionPolicy` says when the controller reads the digest of the chosen tag and stores it in `.status.latestRef.digest`:

| Value | What the controller does |
| --- | --- |
| `Never` | Does not read the digest. This is the default. |
| `IfNotPresent` | Reads the digest once for each chosen tag and keeps it while the choice stays the same |
| `Always` | Reads the digest again at every interval of the policy, so a tag that moves changes the digest |

The setting `Always` needs `spec.interval` on the policy, because the controller must know how often to look. The setting `IfNotPresent` needs no interval. It records the digest at the moment of the choice, and a later change of the tag on the registry is not noticed until the choice changes.

## Record a digest

Save this as `clusters/kind/image-policy-digest.yaml` in your clone of `gitops/fleet`. It needs the `ImageRepository` `podinfo` that scans the lab registry with `insecure: true`:

```yaml
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImagePolicy
metadata:
  name: pinned-always
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: podinfo
  interval: 30s
  digestReflectionPolicy: Always
  policy:
    semver:
      range: '6.x'
---
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImagePolicy
metadata:
  name: pinned-once
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: podinfo
  digestReflectionPolicy: IfNotPresent
  policy:
    semver:
      range: '6.x'
```

Commit, push and read the status of both:

```sh
git add clusters/kind/image-policy-digest.yaml
git commit -m "Reflect digests of the chosen tag"
git push
flux reconcile kustomization fleet --with-source
kubectl -n flux-system get imagepolicy pinned-always -o jsonpath='{.status.latestRef}{"\n"}'
kubectl -n flux-system get imagepolicy pinned-once -o jsonpath='{.status.latestRef}{"\n"}'
```

Both policies choose `6.15.0`, and the status holds three fields: `name` (the image without a tag), `tag` and `digest`. The digest is the same as the one `regctl` printed.

## Move a tag

Make `6.15.0` point at another image. This overwrites the tag in the lab registry and changes nothing else:

```sh
kubectl -n registry exec deploy/registry-tools -- \
  regctl image copy registry.localtest.me:5000/podinfo:6.14.1 registry.localtest.me:5000/podinfo:6.15.0
```

Wait for the policy interval of 30 seconds, and read both statuses again:

```sh
kubectl -n flux-system get imagepolicy pinned-always -o jsonpath='{.status.latestRef.digest}{"\n"}'
kubectl -n flux-system get imagepolicy pinned-once -o jsonpath='{.status.latestRef.digest}{"\n"}'
```

The digest of `pinned-always` is now the digest of the image that `6.14.1` points at, while the tag in its status is still `6.15.0`. The digest of `pinned-once` is the old one, because that policy has not chosen a new tag. The `Always` setting noticed that the tag moved; the other setting did not.

Two things follow. First, the `Always` setting is the one that lets a rebuilt tag reach the cluster, because the digest in the status is the value that changes. Second, it costs a registry request for every policy at every interval, so choose the interval with the number of policies and the registry limits in mind. A registry that is slow or limits requests is a reason to use `IfNotPresent`.

You can now record the digest of a chosen tag and detect a tag that moves. The remaining pieces are when the controller looks: the scan interval, the policy interval and a manual reconcile each set a different clock.

## Common pitfalls

> [!WARNING]
> - **`digestReflectionPolicy: Always` without `interval`.** The setting needs an interval, and the policy is not accepted without it.
> - **Expecting `IfNotPresent` to notice a moved tag.** It records the digest once for each chosen tag.
> - **Reading the digest from the `ImageRepository`.** The scan stores tags. The digest is in the status of the `ImagePolicy`.
> - **Treating a tag as proof of content.** A tag can move. When the exact image matters, compare digests.

## Your mission: Follow Release Candidates And Reflect Digests

You can now record the digest of a chosen tag, and you know how to write a range that follows release candidates. The graded lab gives you a policy in Git that never chooses a release candidate, and asks you to change it so staging follows them, and so the policy also records the digest of the image behind the chosen tag.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-098-playground-010-03
```

Then start the lab:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS098.git -c sections/section-010/module-03/labs/lab-01
```

The task is on the next page. Solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-010/module-03/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-098-lab-010-03
astrona start ats-098-playground-010-03
```

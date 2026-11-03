# Reading Status And Troubleshooting Policies

A policy that chooses nothing, or chooses a surprising tag, is the most common image automation problem. The status of the objects shows where the chain breaks, and four commands read it. This part walks along the chain from the registry to the policy, breaks it on purpose in three ways, and shows what each break looks like in the output.

## The chain and the commands

The chain has three links: the registry has the tags, the `ImageRepository` has scanned them, and the `ImagePolicy` has applied its rule. A policy depends on its `ImageRepository`, so a policy cannot be healthy while its repository is not. Start at the beginning of the chain and move forward.

| Link | Command |
| --- | --- |
| The registry | `regctl tag ls <image>` from a pod |
| The scan | `flux get image repository` and `kubectl describe imagerepository` |
| The policy | `flux get image policy` and `kubectl describe imagepolicy` |
| All of it | `flux get image all`, `flux events --for <Kind>/<name>` |

Read the whole chain at once:

<!-- astrona:playground:renew -->

```sh
flux get image all
```

The output lists every `ImageRepository` and `ImagePolicy` with the `READY` column, the message and the latest image. Anything with `READY` `False` is a place to start. The commands below need an `ImagePolicy` named `range-x` with the range `6.x` and a policy named `range-caret` with the range `^6.14.0`. Compare the three views of one policy. The first line is what the registry holds, the second is what the scan stored, the third is the choice:

```sh
kubectl -n registry exec deploy/registry-tools -- regctl tag ls registry.localtest.me:5000/podinfo
kubectl -n flux-system get imagerepository podinfo -o jsonpath='{.status.lastScanResult.tagCount}{"\n"}'
kubectl -n flux-system get imagepolicy range-x -o jsonpath='{.status.latestRef}{"\n"}'
```

If the registry has a tag that the scan count does not include, check `exclusionList` and the time of the last scan. If the scan has the tag and the policy ignores it, the rule is the reason.

## Fault one: no tag fits

Save this as `clusters/kind/image-policy-broken.yaml` in your clone of `gitops/fleet`:

```yaml
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImagePolicy
metadata:
  name: nothing-fits
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: podinfo
  policy:
    semver:
      range: '>=9.0.0'
---
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImagePolicy
metadata:
  name: bad-range
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: podinfo
  policy:
    semver:
      range: '>=6.14.0 and below 7'
---
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImagePolicy
metadata:
  name: not-numbers
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: podinfo
  policy:
    numerical:
      order: asc
```

Commit it, push it, and read the three policies:

```sh
git add clusters/kind/image-policy-broken.yaml
git commit -m "Add three broken policies"
git push
flux reconcile kustomization fleet --with-source
flux get image policy
```

All three are `READY` `False`. The policy `nothing-fits` says that no image matches the policy: the range is valid, but no tag is `9.0.0` or higher. The fix is a range that fits a tag, or a tag in the registry. The policy `bad-range` says that the range cannot be parsed: the words `and below` are not SemVer syntax, and the fix is to write `>=6.14.0 <7.0.0`. The policy `not-numbers` is not ready either: the numerical rule ignores tags that are not numbers, such as `6.15.0`, so no tag is left to choose.

## Fault two: the scan is not ready

When the `ImageRepository` is not `Ready`, the policy says so too. Change the `image` of the `ImageRepository` `podinfo` in `clusters/kind/image-podinfo.yaml` to `registry.localtest.me:5000/podinfo-typo`, push, and look:

```sh
git commit -am "Point the scan at an image that does not exist"
git push
flux reconcile kustomization fleet --with-source
flux reconcile image repository podinfo
flux get image all
```

The `ImageRepository` reports that the repository was not found, and the policies that depend on it stop reporting a choice they can trust. Read the events of the object to see the failures in time order:

```sh
flux events --for ImageRepository/podinfo
```

The events show the scan error each time the controller tried. Put the correct `image` back, push and reconcile. The policies recover on the next evaluation. Fix the link that is first in the chain, and check the later ones only afterwards.

## Fault three: the right rule, a surprising tag

Not every problem is red in the output. Add a tag that the team did not expect and compare the answer with the rule:

```sh
kubectl -n registry exec deploy/registry-tools -- \
  regctl image copy registry.localtest.me:5000/podinfo:6.15.0 registry.localtest.me:5000/podinfo:6.99.0
flux reconcile image repository podinfo
flux get image policy
```

Both `range-x` and `range-caret` move to `6.99.0`, and both are `Ready`. The rule says "any version 6", and `6.99.0` is a version 6. Nothing is broken; the policy does what it says, and the range needs to be tighter if the team wants otherwise. Compare `~6.14.0`, which stays on `6.14.1`. When a choice surprises you, first prove which tags exist and which rule applies, before you suspect a fault.

## A short checklist

When a policy is wrong, check these in order:

1. `flux get image all`: which object is `False`?
2. `kubectl describe` of that object: what does the message say?
3. `regctl tag ls`: is the tag in the registry at all?
4. The scan time and the interval: has the scan run since the push?
5. `exclusionList` and `filterTags`: is the tag left out before the rule sees it?
6. The rule and its range: does the tag fit?

Each step rules one link in or out, so the first step with a wrong answer is where the problem is. You can now follow a tag from the registry to the policy, and you know the messages for the faults you will meet most often.

## Common pitfalls

> [!WARNING]
> - **Debugging the policy when the scan is the problem.** If the `ImageRepository` is not `Ready`, fix it first.
> - **Fixing an object with `kubectl edit`.** Objects that come from Git go back to Git's version at the next sync. Fix the file in Git.
> - **Reading an old message.** A condition shows the last evaluation. Check `observedGeneration` and the scan time.
> - **Expecting a red message for a surprising choice.** A policy that follows its rule is healthy, even when the rule is too wide.
> - **Leaving the practice policies in Git.** Delete the broken policies and the extra tags' policies when you finish.

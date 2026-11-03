# Semantic Version Ranges

A `semver` policy chooses the highest version that fits a range. Everything depends on how the range is written, and the notation has more operators than `6.x`. This part runs the common ones on the same stable tags and shows what each one chooses. The goal is that you can read a range and name the winner before Flux does.

## What a range is

A semantic version has three numbers: major, minor and patch. A range is a set of comparisons. A version fits the range when it passes every comparison. The controller keeps the tags that parse as versions, drops the ones that do not fit, sorts the rest and chooses the highest.

Comparisons separated by a space are joined with AND, and a `||` between groups means OR:

| Range | Meaning | Fits |
| --- | --- | --- |
| `6.14.0` or `=6.14.0` | Exactly this version | `6.14.0` |
| `>=6.14.0` | This version or higher | `6.14.0` and everything above |
| `<6.14.0` | Lower than this version | `6.12.0`, `6.13.0` |
| `6.x` or `6.*` | Any minor and patch of major 6 | `6.0.0` up to `6.99.99` |
| `~6.14.0` | Patch updates only | `>=6.14.0 <6.15.0` |
| `^6.14.0` | No change of the major version | `>=6.14.0 <7.0.0` |
| `6.13.0 - 6.14.1` | An inclusive hyphen range | `>=6.13.0 <=6.14.1` |
| `6.12.x \|\| 6.13.x` | Either group | Versions of `6.12` or `6.13` |

The operators `~` and `^` are shortcuts. The tilde `~` allows changes of the last number you wrote, so `~6.14.0` accepts `6.14.9` and rejects `6.15.0`. The caret `^` allows everything that does not change the first non-zero number, so `^6.14.0` accepts `6.15.0` and rejects `7.0.0`.

## Run six policies side by side

Git work happens on your machine. Start the port-forward to Gitea in a second terminal and leave it running:

<!-- astrona:playground:renew -->

```sh
kubectl -n gitea port-forward svc/gitea-http 3000:3000
```

Back in your first terminal, clone the repository. The user `gitops` with the password `gitops-password` exists only in this lab. If `gitea.localtest.me` does not resolve, add `127.0.0.1 gitea.localtest.me` to `/etc/hosts` and try again.

```sh
git clone http://gitops:gitops-password@gitea.localtest.me:3000/gitops/fleet.git
cd fleet
```

Save this as `clusters/kind/image-podinfo.yaml`. The `ImageRepository` leaves out `latest`, because it is not a version and the policies would skip it anyway:

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
```

Save this as `clusters/kind/image-policies-ranges.yaml`. Each policy has its own name, so you can compare them:

```yaml
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImagePolicy
metadata:
  name: range-x
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: podinfo
  policy:
    semver:
      range: '6.x'
---
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImagePolicy
metadata:
  name: range-tilde
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: podinfo
  policy:
    semver:
      range: '~6.14.0'
---
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImagePolicy
metadata:
  name: range-caret
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: podinfo
  policy:
    semver:
      range: '^6.14.0'
---
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImagePolicy
metadata:
  name: range-hyphen
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: podinfo
  policy:
    semver:
      range: '6.13.0 - 6.14.1'
---
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImagePolicy
metadata:
  name: range-or
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: podinfo
  policy:
    semver:
      range: '6.12.x || 6.13.x'
---
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImagePolicy
metadata:
  name: range-below
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: podinfo
  policy:
    semver:
      range: '<6.14.0'
```

Before you apply it, write down your prediction for each policy. Then commit, push, make Flux apply it and read the choices:

```sh
git add clusters/kind
git commit -m "Compare six semver ranges"
git push
flux reconcile kustomization fleet --with-source
flux get image policy
```

The tags that count are `6.12.0`, `6.13.0`, `6.14.0`, `6.14.1` and `6.15.0`, because no range names a pre-release. The choices are `6.15.0` for `range-x` and `range-caret`, `6.14.1` for `range-tilde` and `range-hyphen`, `6.13.0` for `range-or` and `range-below`. Each range picks the highest version it allows, not the highest version in the registry.

## Write a range from a rule

Most real requests are a sentence, and the skill is to turn it into a range:

- "Production follows patch releases of the version we run": `~6.14.0`. It accepts `6.14.1` and ignores `6.15.0`.
- "Production follows minor and patch releases of version 6": `^6.14.0` or `6.x`. Both stop before `7.0.0`.
- "Stay on 6.13 or 6.14 while the team migrates": `>=6.13.0 <6.15.0`.
- "Pin one version for an audit": `6.14.0`. The policy never moves.

The CLI can print the same objects, which is quicker than typing YAML. It prints without creating anything because of `--export`:

```sh
flux create image policy range-tilde --image-ref=podinfo --select-semver='~6.14.0' --export
```

The output is the `ImagePolicy` for `range-tilde`, the same as the YAML above. Always commit the exported file to Git, as with every Flux object.

You can now turn a rule of the team into a range and predict its choice. All the ranges so far skipped `6.16.0-rc.1`, `6.16.0-rc.2` and `7.0.0-rc.1`. Staging often needs exactly those, and the notation for it has one more rule.

## Common pitfalls

> [!WARNING]
> - **Reading `~` and `^` as the same.** The tilde stays in one minor version when you write three numbers. The caret stays in one major version.
> - **A range with a comma or a missing space.** `>=6.14.0<6.15.0` does not parse. Separate comparisons with a space.
> - **Expecting `6.x` to choose the newest tag in the registry.** It chooses the newest tag of major version 6.
> - **Forgetting `||` for two groups.** `6.12.x 6.13.x` means both at once, which no version satisfies.
> - **Leaving the comparison policies in Git.** Remove them when you finish, or they keep scanning and clutter `flux get image policy`.

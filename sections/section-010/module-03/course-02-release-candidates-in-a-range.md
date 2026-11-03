# Release Candidates In A Range

Staging environments test a release before it is released. The tags they need, such as `6.16.0-rc.2`, are pre-releases, and a range without a pre-release part never matches them. This part explains the rule, writes a range that includes pre-releases, and shows the order in which Flux ranks them, because `rc.10` and `rc.2` do not sort the way most people expect.

## The rule for pre-releases

A pre-release is the part after the hyphen in a version, such as `-rc.2` in `6.16.0-rc.2`. A pre-release is lower than the release it belongs to: `6.16.0-rc.2` comes before `6.16.0`. A pre-release is also unstable, so the range rules keep it away from users who did not ask for it.

The rule is this: a pre-release version fits a comparison only if the comparison itself has a pre-release part. The range `6.x` has none, so no pre-release fits it. The range `>=6.15.0-0` has one, so pre-releases fit it. In a range with several comparisons, **every** comparison needs a pre-release part, or the pre-release fails that comparison.

The pre-release part `-0` is the lowest possible one. Writing `-0` on a bound says "include pre-releases here". That gives the range for staging:

```text
>=6.15.0-0 <7.0.0-0
```

The lower bound `>=6.15.0-0` accepts `6.15.0`, every release candidate of later versions and every later release. The upper bound `<7.0.0-0` stops before everything of version 7, including `7.0.0-rc.1`, because `7.0.0-0` is lower than `7.0.0-rc.1`. If you wrote `<7.0.0` instead, the comparison would have no pre-release part and `6.16.0-rc.2` would fail it.

## The order of pre-releases

SemVer compares the pre-release parts piece by piece, with the pieces split at the dots. Two rules decide each piece. A piece that is only digits is compared as a number. A piece with letters is compared as text. A number is always lower than text.

The playground registry holds four pre-releases of `6.16.0`. In order from lowest to highest they are:

1. `6.16.0-beta.1`: the text `beta` is lower than `rc`.
2. `6.16.0-rc.1`
3. `6.16.0-rc.2`
4. `6.16.0-rc.10`: the piece `10` is a number, and 10 is higher than 2.

The release `6.16.0` is higher than all four. Compare this with sorting as text, where `rc.2` would come after `rc.10`, because the character `2` is higher than `1`.

## Run it

Each file below goes in your clone of `gitops/fleet`. The `ImageRepository` `podinfo` must exist; if it does not, save it as `clusters/kind/image-podinfo.yaml` with `insecure: true` and the image `registry.localtest.me:5000/podinfo`. Save this as `clusters/kind/image-policies-prerelease.yaml`:

<!-- astrona:playground:renew -->

```yaml
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImagePolicy
metadata:
  name: stable-only
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: podinfo
  policy:
    semver:
      range: '>=6.15.0 <7.0.0'
---
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImagePolicy
metadata:
  name: with-candidates
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: podinfo
  policy:
    semver:
      range: '>=6.15.0-0 <7.0.0-0'
---
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImagePolicy
metadata:
  name: half-written
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: podinfo
  policy:
    semver:
      range: '>=6.15.0-0 <7.0.0'
---
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImagePolicy
metadata:
  name: text-order
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: podinfo
  policy:
    alphabetical:
      order: asc
```

Commit, push and read the choices:

```sh
git add clusters/kind/image-policies-prerelease.yaml
git commit -m "Compare policies with pre-releases"
git push
flux reconcile kustomization fleet --with-source
flux reconcile image repository podinfo
flux get image policy
```

The policy `stable-only` chooses `6.15.0`, the highest stable version, because its range has no pre-release part. The policy `with-candidates` chooses `6.16.0-rc.10`. It skips `7.0.0-rc.1`, and it ranks `rc.10` above `rc.2` because the piece is a number. The policy `half-written` chooses `6.15.0`, even though its lower bound has a pre-release part: the upper bound `<7.0.0` has none, so every pre-release fails it. The policy `text-order` chooses `latest`, because as text it comes after every tag that starts with a digit.

Now release `6.16.0`. The helper copies the image under the new tag, because only the tag matters here:

```sh
kubectl -n registry exec deploy/registry-tools -- \
  regctl image copy registry.localtest.me:5000/podinfo:6.15.0 registry.localtest.me:5000/podinfo:6.16.0
flux reconcile image repository podinfo
flux get image policy
```

The policy `with-candidates` moves to `6.16.0`: a release is higher than its own release candidates, so staging moves on to the release without a change to the policy. The policy `stable-only` moves to `6.16.0` as well, because its range accepts it.

You can now write a range that follows release candidates, keep it below the next major version and predict the order of `rc` tags. One more thing about a chosen tag remains: the tag is only a name, and a name can point at a different image tomorrow.

## Common pitfalls

> [!WARNING]
> - **Writing `-0` on only one bound.** Every comparison of the range needs a pre-release part. `>=6.15.0-0 <7.0.0` skips every pre-release.
> - **Expecting `7.0.0-rc.1` to be excluded by `<7.0.0`.** It is excluded by `<7.0.0-0` in a range that includes pre-releases, and by having no pre-release part in a stable range.
> - **Sorting pre-releases as text.** `rc.10` is higher than `rc.2` in SemVer and lower as text. Use a `semver` policy.
> - **Following pre-releases in production.** A range with `-0` is for staging. Keep production on a range with no pre-release part.

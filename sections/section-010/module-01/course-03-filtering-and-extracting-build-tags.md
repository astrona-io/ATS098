# Filtering And Extracting Build Tags

Many teams do not wait for a release number. Their build pipeline pushes an image for every commit on `main`, tagged with the branch, the short commit hash and the time of the build, such as `main-0c1d2e3-1760007200`. A test environment should run the newest of those builds. None of the rules you know can sort such tags: they are not versions, they are not numbers, and as text they sort by the commit hash. This part adds the missing step: keep only the right tags, then sort them by the part that means "newer".

## Push some build tags

The commands below add three `main` builds and one pull request build to the lab registry. The last number in each tag is a Unix timestamp: the number of seconds since 1 January 1970, so a bigger number is a later build. The helper `retag_podinfo` adds a tag to the image that another tag points at:

<!-- astrona:playground:renew -->

```sh
retag_podinfo() {
  # retag_podinfo FROM TO: adds tag TO to the image that tag FROM points at, in the lab registry.
  kubectl -n registry exec deploy/registry-tools -- \
    regctl image copy "registry.localtest.me:5000/podinfo:$1" "registry.localtest.me:5000/podinfo:$2"
}
retag_podinfo 6.15.0 main-1a2b3c4-1760000000
retag_podinfo 6.15.0 main-9f8e7d6-1760003600
retag_podinfo 6.15.0 main-0c1d2e3-1760007200
retag_podinfo 6.15.0 pr-41-5e6f7a8-1760009000
```

The newest `main` build is `main-0c1d2e3-1760007200`. The pull request build is newer still, but it comes from code nobody merged, so it must never be chosen. The `ImagePolicy` `podinfo` with the range `6.x` keeps choosing `6.15.0`, because none of the new tags is a semantic version.

## Filter first, then sort

The `filterTags` field of an `ImagePolicy` runs before the rule. Its `pattern` is a regular expression, and only tags that match it reach the rule. A first try keeps the `main-` tags and sorts them alphabetically. Save this as `clusters/kind/image-policy-main.yaml` in your clone of `gitops/fleet`:

```yaml
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImagePolicy
metadata:
  name: podinfo-main
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: podinfo
  filterTags:
    pattern: '^main-[a-f0-9]+-[0-9]+$'
  policy:
    alphabetical:
      order: asc
```

Commit and push it, and check the choice. The port-forward to Gitea must still run in your second terminal:

```sh
git add clusters/kind/image-policy-main.yaml
git commit -m "Follow main builds"
git push
flux reconcile kustomization fleet --with-source
flux reconcile image repository podinfo
flux get image policy podinfo-main
```

The pull request build is gone, so the filter works. The choice is still wrong: the policy chooses `main-9f8e7d6-1760003600`. As text, the tags differ first at the commit hash, and `9f8e7d6` sorts after `1a2b3c4` and `0c1d2e3`. The timestamp never gets a say.

## Extract the part that means newer

The `extract` field fixes that. The pattern marks a part of the tag with a named group, written `(?P<name>...)`, and `extract` says which group the rule sorts on, written `$name`. Here the group is the timestamp, and because a timestamp is a number, the rule is `numerical`. Change the `spec` in `clusters/kind/image-policy-main.yaml` so it reads:

```yaml
spec:
  imageRepositoryRef:
    name: podinfo
  filterTags:
    pattern: '^main-[a-f0-9]+-(?P<ts>[0-9]+)$'
    extract: '$ts'
  policy:
    numerical:
      order: asc
```

Commit, push and check again:

```sh
git commit -am "Sort main builds by their timestamp"
git push
flux reconcile kustomization fleet --with-source
flux get image policy podinfo-main
```

Now the policy chooses `main-0c1d2e3-1760007200`. The controller kept the four `main` tags, took the timestamp out of each, sorted the timestamps as numbers, and reported the whole tag of the winner. The extracted value is only used for sorting; `.status.latestRef.tag` always holds the full tag.

## Prove it follows the next build

A policy is only right if it moves when a new build arrives. Add a newer `main` build and a newer pull request build, and scan:

```sh
retag_podinfo 6.15.0 main-aaaaaaa-1760010800
retag_podinfo 6.15.0 pr-42-bbbbbbb-1760099999
flux reconcile image repository podinfo
flux get image policy podinfo-main
```

The policy moves to `main-aaaaaaa-1760010800` and ignores the pull request build, even though its timestamp is much higher. The filter decides which tags may win, and the extracted part decides which of them wins.

You can now handle any tag scheme that carries an order somewhere inside it: keep the right tags with a pattern, take out the part that grows with each build, and sort on it. The same two fields work for a date such as `RELEASE.2025-09-07T16-13-09Z`, with `alphabetical` order on the extracted date. What you still cannot do is use the chosen tag: so far it only lives in the status of a policy.

## Common pitfalls

> [!WARNING]
> - **Sorting build tags without `extract`.** Alphabetical order then sorts by the commit hash, which says nothing about age.
> - **`numerical` on the whole tag.** `main-0c1d2e3-1760007200` is not a number, so the policy reports an error. Extract the number first.
> - **A pattern without anchors.** Without `^` and `$`, `main-` also matches `pr-12-main-...` and other tags you did not mean.
> - **A named group that `extract` does not use.** `extract: '$ts'` needs a group called `ts` in the pattern; a different name extracts nothing.
> - **Expecting the extracted value in the status.** `.status.latestRef.tag` holds the full tag, not the timestamp.

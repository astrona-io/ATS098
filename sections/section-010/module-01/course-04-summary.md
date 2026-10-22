# Summary

Flux finds new container images in two steps, and one controller does both. The image reflector controller, an optional Flux controller, reads `ImageRepository` and `ImagePolicy` objects. The repository finds tags, and the policy chooses one.

## What you learned

An `ImageRepository` names one image without a scheme or a tag, such as `registry.localtest.me:5000/podinfo`, and an `interval` for scanning it. A registry that uses plain HTTP needs `insecure: true`; a real registry uses HTTPS. The scan result is in the status: `tagCount` is the number of tags kept, and `latestTags` is a sample of recent ones, not a choice. The `exclusionList` leaves tags out with regular expressions. When you set it, it replaces the default `^.*\.sig$`, so list that expression again if you want signature tags left out.

An `ImagePolicy` points at one `ImageRepository` and holds one rule. A `semver` rule chooses the highest semantic version inside a `range`. A range without a pre-release part, such as `6.x`, never matches release candidates, and it does not follow the next major version, which an open range such as `>=6.0.0` does. An `alphabetical` rule sorts text, so it puts `7.0.0-rc.1` above `6.15.0` and `6.9.0` above `6.15.0`. A `numerical` rule needs tags that are numbers. The choice is in `.status.latestRef.tag`, and `flux get image policy` shows it.

Build tags that carry a commit and a timestamp need a filter before any rule. `filterTags.pattern` keeps only the tags that match it, and a named group such as `(?P<ts>[0-9]+)` together with `extract: '$ts'` gives the rule the part to sort on. The status still holds the full tag. The key facts to remember are these:

- The repository finds tags and the policy chooses one; read the choice from the policy, not from the scan.
- `6.x` follows stable minor and patch releases of version 6 and skips pre-releases.
- Filter build tags first, then sort on the extracted timestamp with `numerical`.
- A policy is only proven when it moves to a new tag and ignores the tags it should ignore.

<!-- astrona:playground:destroy -->

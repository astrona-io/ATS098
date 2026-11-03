# Summary

An `ImagePolicy` is a rule applied to the tags that an `ImageRepository` has scanned. The same rule gives a new answer whenever the tags change, so the skill is to predict the answer from the rule and the tags, and to read the status when the answer is different.

## What you learned

A `semver` range is a set of comparisons. Spaces join comparisons with AND and `||` joins groups with OR. The tilde `~` stays inside one minor version, the caret `^` stays inside one major version, `x` is a wildcard and a hyphen range includes both ends. The policy chooses the highest version that fits, which is not always the highest tag in the registry.

A pre-release such as `6.16.0-rc.2` fits a comparison only if that comparison has a pre-release part. The part `-0` is the lowest one, so `>=6.15.0-0 <7.0.0-0` follows release candidates and releases of version 6 and stops before version 7, `7.0.0-rc.1` included. Every comparison needs it: `<7.0.0` by itself rejects every pre-release. Pre-releases rank piece by piece: a number is lower than text, numbers compare as numbers and text compares as text. So `beta.1` is lower than `rc.1`, and `rc.10` is higher than `rc.2`. The release is higher than all of its candidates.

A tag is a name and a digest is the hash of the image manifest. The `digestReflectionPolicy` field has three values. `Never` reads no digest. `IfNotPresent` reads it once for each chosen tag. `Always` reads it at every `interval` of the policy, requires that `interval`, and is the only value that notices a tag that moved. The digest is in `.status.latestRef.digest` of the policy.

The delay from a push to a choice is the time until the next scan. The `interval` of the `ImageRepository` sets that scan, a manual reconcile or `flux reconcile image repository` starts one now, and `suspend` stops it. The policy `interval` only sets how often a digest is read. Short intervals speed up releases and add requests to the registry, and a public registry limits them.

When a policy is wrong, follow the chain from the registry to the scan to the policy. `flux get image all` shows which object is not `Ready`, `kubectl describe` and `flux events` show the message, and `regctl tag ls` shows what the registry has. A rule that matches no tag and a range that does not parse give different messages, and a numerical rule on tags that are not numbers leaves no tag to choose. A policy that follows its rule to a surprising tag is healthy and needs a tighter rule. The key facts to remember are these:

- Include pre-releases with `-0` on every comparison of the range, and keep an upper bound below the next major version.
- Use `digestReflectionPolicy: Always` with an `interval` to detect a tag that moved.
- The scan `interval` sets the delay from a push to a choice.
- Check the chain in order, and fix the first broken link.

<!-- astrona:playground:destroy -->

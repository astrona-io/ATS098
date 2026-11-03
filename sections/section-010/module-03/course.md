# Choose Tags With Ranges And Digests

A policy that chooses `6.15.0` today must choose the right tag tomorrow, when `6.15.1`, `6.16.0-rc.1` and `7.0.0` exist. The first module of this section showed that `6.x` follows stable releases and skips release candidates. Teams soon need more: a staging cluster that tests release candidates, a production cluster that follows patch releases only, and a way to notice that a tag was pushed again with different content.

This module goes deeper into the rules that decide the choice and into how Flux watches the registry. The image reflector controller, the optional Flux controller that reads registries, applies each `ImagePolicy` to the tags of an `ImageRepository`. Keep one sentence in mind: **a policy is a rule plus the tags that exist, and the same rule gives a different answer after every push.**

The module has five parts. **Semantic Version Ranges** compares the range operators on the same tags. **Release Candidates In A Range** explains the pre-release part of a range and the order of pre-releases; a graded lab follows it. **Reflecting Image Digests** records the digest of the chosen tag with `digestReflectionPolicy`. **Scan And Reflection Timing** covers the intervals and the order of events. **Reading Status And Troubleshooting Policies** uses `flux get image`, conditions and events to find out why a policy chooses nothing or the wrong tag.

## Learning objectives

After this module you can:

- Write a SemVer range with the operators `=`, `>`, `>=`, `<`, `<=`, `~`, `^`, `x`, a hyphen range and `||`, and predict the chosen tag.
- Explain why a range with no pre-release part skips release candidates, and write a range that includes them.
- Order pre-release tags such as `-beta.1`, `-rc.2` and `-rc.10` by the SemVer rules.
- Set `digestReflectionPolicy` to `Never`, `IfNotPresent` or `Always`, and read `.status.latestRef.digest`.
- Explain what the scan `interval`, the policy `interval` and a manual reconcile each change.
- Use `flux get image`, `flux events`, `kubectl describe` and `regctl` to find why a policy is not `Ready` or chooses the wrong tag.

## Before you start

You need to know what an `ImageRepository` and an `ImagePolicy` do, how to commit a Flux object to the repository `gitops/fleet`, and how to read a semantic version: `MAJOR.MINOR.PATCH`, such as `6.15.0`, with an optional pre-release part after a hyphen, such as `-rc.1`.

Your playground is a single-node `kind` cluster with **Flux 2.9.6**, including the two image controllers, and the `flux` command-line tool on your PATH. Gitea, a Git server inside the cluster, holds the repository `gitops/fleet`, and the Flux `Kustomization` named `fleet` applies every file under `clusters/kind` in it.

A lab registry runs inside the cluster, at `registry.localtest.me:5000`, with plain HTTP. It holds podinfo `6.12.0`, `6.13.0`, `6.14.0`, `6.14.1` and `6.15.0`, the pre-releases `6.16.0-beta.1`, `6.16.0-rc.1`, `6.16.0-rc.2`, `6.16.0-rc.10` and `7.0.0-rc.1`, and the moving tag `latest`. The tags stay only while the playground runs.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

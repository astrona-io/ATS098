# Scan A Registry And Choose A Tag

The lab registry in your playground holds nine podinfo tags: five releases from `6.12.0` to `6.15.0`, the release candidates `6.16.0-rc.1` and `7.0.0-rc.1`, and `latest`. Ask a person which one to run in production, and they answer `6.15.0` without thinking. Flux has to get the same answer from rules you write down, and the obvious rules give the wrong one.

Flux splits the job into two objects, and the image reflector controller handles both. The image reflector controller is an optional Flux controller that reads container registries. An **`ImageRepository`** tells it which image to scan and how often; the result is the list of tags. An **`ImagePolicy`** tells it how to choose one tag from that list; the result is in `.status.latestRef.tag`. Keep one sentence in mind: **the repository finds tags, and the policy chooses one.**

The module has three parts. **Scanning A Registry With ImageRepository** writes the first object, reads the scan result and leaves tags out with `exclusionList`. **Choosing A Tag With ImagePolicy** compares the three kinds of policy on the same tags and shows why a SemVer range skips release candidates. A graded lab follows it. **Filtering And Extracting Build Tags** handles tags that carry a commit and a timestamp, such as `main-0c1d2e3-1760007200`, with `filterTags`.

## Learning objectives

After this module you can:

- Name the controller that scans registries and the two objects it reads.
- Write an `ImageRepository` with an interval, and with `insecure: true` for a plain HTTP registry.
- Read the scan result: `.status.lastScanResult.tagCount` and `.status.lastScanResult.latestTags`.
- Leave tags out of the scan with `exclusionList`.
- Choose a tag with a SemVer, numerical or alphabetical `ImagePolicy`, and predict the result.
- Explain why the SemVer range `6.x` does not choose `6.16.0-rc.1`.
- Keep only some tags with `filterTags.pattern` and sort them by a part taken out with `filterTags.extract`.

## Before you start

You need to know Flux: what a `GitRepository` and a Flux `Kustomization` object do, and how a commit becomes a change in the cluster. You need Git from the terminal: clone, commit and push. You also need to read a semantic version, such as `6.15.0` (major, minor and patch numbers) or `6.16.0-rc.1` (a pre-release).

Your playground is a single-node `kind` cluster with **Flux 2.9.6**, including the two image controllers, and the `flux` command-line tool on your PATH. Gitea, a Git server inside the cluster, holds the repository `gitops/fleet`, and the Flux `Kustomization` named `fleet` applies every file under `clusters/kind` in it. The repository deploys podinfo `6.14.0`, a small web server, into the namespace `podinfo`.

A lab registry also runs inside the cluster, at `registry.localtest.me:5000`, with the nine tags above. It uses plain HTTP and keeps the tags only while the playground runs. The cluster pulls podinfo itself from `ghcr.io/stefanprodan/podinfo`, so the lab registry only decides which tag counts as new.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

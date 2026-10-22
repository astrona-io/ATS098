# Write New Image Tags Back To Git

In your playground, the `ImagePolicy` `podinfo` follows every stable `6.x` release in the lab registry. Copy podinfo `6.14.1` into the registry, and the policy chooses it within a minute. The Deployment still runs `6.14.0`, because the file `apps/podinfo/kustomization.yaml` in Git still says `6.14.0`. Flux applies Git, and nothing has changed Git.

The image automation controller closes that gap. It is the second optional Flux controller for images, and it reads `ImageUpdateAutomation` objects. Each one names a Git repository, a branch and a path. At each interval, the controller clones the branch, looks for **setter markers** under the path, writes the tag each marker's policy chose, and commits and pushes if anything changed. Keep one sentence in mind: **the controller only changes lines that carry a marker, and it only changes them in Git.**

The module has three parts. **Marking Fields With Setter Markers** explains the marker, its four forms, and where it goes in the Kustomize file `kustomization.yaml`. **ImageUpdateAutomation And The Release Loop** writes the automation, follows one tag from the registry to the running Deployment, and shows how to speed up each step. A graded lab follows it. **Commit Messages, Authors And Branches** shapes the commits the automation leaves behind, and pushes them to a separate branch for review.

## Learning objectives

After this module you can:

- Write a setter marker that names a policy, and choose between the full, `:name`, `:tag` and `:digest` forms.
- Explain why a marker on its own changes nothing.
- Write an `ImageUpdateAutomation` with a source, a checkout branch, a path, an author and a push branch.
- Follow a new tag through the policy, a commit, the Flux sync and the rollout, and speed up each step with `flux reconcile`.
- Read `flux get image update` and `.status.lastPushCommit`.
- Write a commit message template, and push releases to a branch that a person merges.

## Before you start

You need to know Flux: a `GitRepository`, a Flux `Kustomization` object, and how a commit becomes a change in the cluster. You need Git from the terminal: clone, commit, push and pull. You need to know what an `ImagePolicy` does: it chooses one tag from the tags an `ImageRepository` found, and the choice is in `.status.latestRef.tag`.

Your playground is a single-node `kind` cluster with **Flux 2.9.6**, including both image controllers, and the `flux` command-line tool on your PATH. Gitea, a Git server inside the cluster, holds the repository `gitops/fleet`. In it:

| Path | What it holds |
| --- | --- |
| `apps/podinfo/` | The podinfo Namespace, Deployment and Service, and the Kustomize file `kustomization.yaml` that sets the image tag with `images[].newTag: 6.14.0` |
| `clusters/kind/podinfo.yaml` | The Flux `Kustomization` `podinfo`, which applies `apps/podinfo` |
| `clusters/kind/image-podinfo.yaml` | The `ImageRepository` `podinfo` for `registry.localtest.me:5000/podinfo` and the `ImagePolicy` `podinfo` with the range `6.x` |

The lab registry holds only `6.14.0`. The cluster pulls podinfo from `ghcr.io/stefanprodan/podinfo`, so the lab registry only decides which tag counts as new; every tag you add there also exists upstream.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

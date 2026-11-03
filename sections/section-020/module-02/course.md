# Release Commits And Helm Values

In your playground, the release loop already works. podinfo `6.14.0` runs, the tag line in `apps/podinfo/kustomization.yaml` carries a setter marker, and the `ImageUpdateAutomation` `podinfo` commits to `main` as `fluxcdbot`. That is the simplest case: one image, one Kustomize field, one fixed commit message. Real repositories are not that tidy. Images appear in Helm values and in `HelmRelease` objects, a release is sometimes pinned by digest, one repository holds many applications, and the history must say what each commit changed and who made it.

This module takes the working loop and extends every part of it that a real team changes. The image automation controller, the optional Flux controller that writes tags to Git, stays the same. What changes is what you mark, where it looks, and what it writes in the commit. Keep one sentence in mind: **a setter marker names the policy and the part of the image reference, and the automation decides only where it looks and how it commits.**

The module has five parts. **Setter Markers In Helm Values** puts the markers on the fields that a `HelmRelease` and a values file use. **Pinning Images By Digest** adds a digest to the policy and writes it with the `:digest` marker. **Update Paths And The Setters Strategy** controls which files the controller reads. **Commit Message Templates** lists the changed values in the commit, and a graded lab follows it. **Signing Commits And Push Options** signs the commits and changes how they are pushed.

## Learning objectives

After this module you can:

- Put a setter marker on a Helm values field and on a `HelmRelease` `spec.values` field, and choose the `:name`, `:tag` or full form.
- Explain what the full marker writes and why it needs a policy that scans the same registry the cluster pulls from.
- Set `digestReflectionPolicy` on an `ImagePolicy` and write the digest with the `:digest` marker.
- Explain what `update.path` and `update.strategy: Setters` do, and which files the controller reads.
- Generate an `ImageUpdateAutomation` with `flux create image update --export`.
- Write a commit message template with `.Changed.Changes`, `.Changed.Objects` and `.Values`.
- Sign automation commits with a GPG key and change the push with `push.refspec` and `push.options`.

## Before you start

You need to know the release loop: an `ImageRepository` scans a registry, an `ImagePolicy` chooses one tag, and an `ImageUpdateAutomation` writes it to Git where a setter marker asks for it. You need Git from the terminal and basic YAML.

Your playground is a single-node `kind` cluster with **Flux 2.9.6**, including both image controllers, and the `flux` command-line tool on your PATH. Gitea, a Git server inside the cluster, holds the repository `gitops/fleet`. In it:

| Path | What it holds |
| --- | --- |
| `apps/podinfo/` | The podinfo Namespace, Deployment and Service, and the Kustomize file `kustomization.yaml` with `images[].newTag` and its setter marker |
| `clusters/kind/podinfo.yaml` | The Flux `Kustomization` `podinfo`, which applies `apps/podinfo` |
| `clusters/kind/image-podinfo.yaml` | The `ImageRepository` `podinfo` for `registry.localtest.me:5000/podinfo` and the `ImagePolicy` `podinfo` with the range `6.x` |
| `clusters/kind/image-automation.yaml` | The `ImageUpdateAutomation` `podinfo` |

The lab registry holds only podinfo `6.14.0`. The cluster pulls podinfo from `ghcr.io/stefanprodan/podinfo`, so the lab registry only decides which tag counts as new.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

# Operate And Debug Image Automation

In your playground, the release loop works until it does not. A tag arrives in the registry, and a day later the cluster still runs the old release. No object is red, no pod is failing, and nobody has an error message to read. The loop has four owners in a row: the `ImageRepository`, the `ImagePolicy`, the `ImageUpdateAutomation` and the Flux sync of the commit. A stop at any one of them looks the same from the outside, a release that never arrives.

This module teaches the operating side of the image controllers: how to read the state of every object in one command, how to follow a release from the Deployment back to its commit, how to pause the loop safely, how to send its events to people, and which faults produce which symptoms. Keep one sentence in mind: **find the last object that did its job, and the cause is in the next one.**

The module has five parts. **Reading The State Of The Image Objects** uses `flux get image` and the conditions. **Tracing A Release** follows a Deployment back to its source with `flux trace`. **Suspending And Resuming Automation** pauses the loop, and shows why a pause must be in Git. **Alerts And Providers For Image Events** sends events out, and a graded lab follows it. **Common Failure Causes** lists the faults and the evidence that identifies each.

## Learning objectives

After this module you can:

- Read all image objects with `flux get image all` and explain `READY`, `SUSPENDED` and the message.
- Read an object's `.status.conditions` and `.status.lastScanResult` or `.status.lastPushCommit`.
- Run `flux trace` on a Deployment and name each link in the answer.
- Suspend and resume an object with the command line and with `spec.suspend` in Git, and explain which one lasts.
- Create a `Provider` and an `Alert` for the image objects and read events with `flux events`.
- Read the controller log with `flux logs`.
- Match a symptom to its cause: authentication, path, marker, push permission, branch, template.

## Before you start

You need to know the release loop: an `ImageRepository` scans a registry, an `ImagePolicy` chooses one tag, an `ImageUpdateAutomation` writes it to Git where a setter marker asks for it, and the Flux `Kustomization` applies the commit. You need Git from the terminal and `kubectl`.

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

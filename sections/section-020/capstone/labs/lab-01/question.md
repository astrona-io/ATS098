# Question

Solve this question on: `terminal`

**Time:** about 35 minutes · **Topic:** Automated Git write-backs

## Scenario

A team set up image automation for podinfo in the repository `gitops/fleet`, and announced that releases are now automatic. A week later podinfo still runs `6.14.0`, although the release team has copied newer releases into the lab registry `registry.localtest.me:5000/podinfo` more than once. Nobody has seen a single commit from the automation.

Everything is in Git:

| File | What it holds |
| --- | --- |
| `clusters/kind/image-podinfo.yaml` | The `ImageRepository` `podinfo` and the `ImagePolicy` `podinfo` (range `6.x`) |
| `clusters/kind/image-automation.yaml` | The `ImageUpdateAutomation` `podinfo`, author `fluxcdbot <fluxcdbot@example.com>` |
| `apps/podinfo/kustomization.yaml` | The podinfo tag in `images[].newTag`, with a setter marker |

The repository is at `http://gitea.localtest.me:3000/gitops/fleet.git` (lab-only user `gitops`, password `gitops-password`). Start `kubectl -n gitea port-forward svc/gitea-http 3000:3000` in a second terminal before you use `git`. To copy a release into the registry, run:

```sh
kubectl -n registry exec deploy/registry-tools -- \
  regctl image copy ghcr.io/stefanprodan/podinfo:6.14.1 registry.localtest.me:5000/podinfo:6.14.1
```

## Your task

Make the release loop work, so that a new stable `6.x` release in the registry reaches the running Deployment through a commit by the automation on `main`. A release stops at more than one place between the registry and `main`. Follow a release through the loop and fix every stop.

## Constraints

- Releases must land on `main` without a person merging anything.
- Keep the names of the three objects and the author `fluxcdbot <fluxcdbot@example.com>`.
- Do not set the tag by hand, and do not change the image name `ghcr.io/stefanprodan/podinfo`.
- Fix everything in Git. The grader makes Flux apply Git before it checks.

## Done when

- The `ImageRepository` `podinfo` is `Ready`.
- The setter marker on `newTag` names the policy `flux-system:podinfo` and writes only the tag.
- The automation pushes to `main` and updates the folder that holds `apps/podinfo/kustomization.yaml`.
- When the grader copies podinfo `6.15.0` into the registry, a commit by `fluxcdbot@example.com` sets `6.15.0` on `main`, and the Deployment `podinfo` runs `ghcr.io/stefanprodan/podinfo:6.15.0`.

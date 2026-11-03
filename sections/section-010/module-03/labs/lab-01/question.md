# Question

Solve this question on: `terminal`

**Time:** about 25 minutes · **Topic:** Pre-release ranges and digest reflection

## Scenario

The staging environment must test every build of the next minor version of podinfo before it is released. The lab registry `registry.localtest.me:5000/podinfo` holds the releases `6.12.0` to `6.15.0`, the release candidates `6.16.0-rc.1` and `6.16.0-rc.2`, and the release candidate `7.0.0-rc.1`. A colleague committed an `ImagePolicy` named `podinfo` to `clusters/kind/image-podinfo.yaml` in the repository `gitops/fleet`. It chooses `6.15.0`, so staging never tests a release candidate.

The repository is at `http://gitea.localtest.me:3000/gitops/fleet.git` (lab-only user `gitops`, password `gitops-password`). Start `kubectl -n gitea port-forward svc/gitea-http 3000:3000` in a second terminal before you use `git`.

## Your task

1. Change the policy **in Git** so it follows release candidates and releases of major version **6**, and never chooses anything of version 7.
2. Make the policy store the digest of the image behind the chosen tag, and keep that digest up to date when the tag is pushed again.
3. Check that the policy now chooses `6.16.0-rc.2` and shows a digest.

## Constraints

- Keep the names: the `ImageRepository` `podinfo` and the `ImagePolicy` `podinfo` in `flux-system`, in `clusters/kind/image-podinfo.yaml`.
- Keep a `semver` policy. Do not use `alphabetical`, and do not use `filterTags`.
- Change the policy in Git. A change made with `kubectl` is undone when Flux applies Git again, and the grader makes Flux apply Git before it checks.
- Do not delete tags from the registry.

## Done when

- `flux get image policy podinfo` shows `6.16.0-rc.2`, and `.status.latestRef.digest` starts with `sha256:`.
- The policy has `digestReflectionPolicy: Always` and an `interval`.
- After the tags `6.16.0` and `7.0.0` are added to the registry, the policy chooses `6.16.0`. The grader adds these tags itself.

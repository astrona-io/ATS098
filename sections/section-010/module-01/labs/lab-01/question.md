# Question

Solve this question on: `terminal`

**Time:** about 20 minutes · **Topic:** Choosing tags with ImagePolicy

## Scenario

The team scans podinfo in the lab registry `registry.localtest.me:5000/podinfo` and wants Flux to follow its releases. The registry holds the releases `6.12.0` to `6.15.0`, the release candidates `6.16.0-rc.1` and `7.0.0-rc.1`, and the tag `latest`. A colleague committed an `ImagePolicy` named `podinfo` to `clusters/kind/image-podinfo.yaml` in the repository `gitops/fleet`. It chooses a tag nobody wants to run.

The repository is at `http://gitea.localtest.me:3000/gitops/fleet.git` (lab-only user `gitops`, password `gitops-password`). Start `kubectl -n gitea port-forward svc/gitea-http 3000:3000` in a second terminal before you use `git`.

## Your task

1. Find which tag the `ImagePolicy` `podinfo` in `flux-system` chooses now, and why.
2. Change the policy **in Git** so it chooses the newest **stable** release with major version **6**.
3. Make sure it keeps doing that when new tags arrive: a newer stable 6.x release must be chosen, and a new release candidate or a 7.x release must not.

## Constraints

- Keep the names: the `ImageRepository` `podinfo` and the `ImagePolicy` `podinfo` in `flux-system`, in `clusters/kind/image-podinfo.yaml`.
- Change the policy in Git. A change made with `kubectl` is undone when Flux applies Git again, and the grader makes Flux apply Git before it checks.
- Do not delete tags from the registry.

## Done when

- `flux get image policy podinfo` shows `6.15.0`.
- After the tags `6.15.1`, `6.16.0-rc.2` and `7.0.0` are added to the registry, the policy chooses `6.15.1`. The grader adds these tags itself.

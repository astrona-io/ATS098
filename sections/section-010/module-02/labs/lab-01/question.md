# Question

Solve this question on: `terminal`

**Time:** about 20 minutes · **Topic:** Authenticating to a private registry

## Scenario

The team keeps its podinfo images in a private registry inside the cluster, at `registry-private.registry.svc.cluster.local:5000/podinfo`. The registry uses plain HTTP and answers every request without credentials with `401 Unauthorized`. The registry user is `scanner` and the password is `scanner-password`. It holds the tags `6.13.0`, `6.14.0` and `6.15.0`.

A colleague committed an `ImageRepository` named `podinfo` and an `ImagePolicy` named `podinfo` to `clusters/kind/image-podinfo.yaml` in the repository `gitops/fleet`. The scan does not work.

The repository is at `http://gitea.localtest.me:3000/gitops/fleet.git` (lab-only user `gitops`, password `gitops-password`). Start `kubectl -n gitea port-forward svc/gitea-http 3000:3000` in a second terminal before you use `git`.

## Your task

1. Find out why the `ImageRepository` `podinfo` in `flux-system` is not `Ready`. There is more than one cause.
2. Give the scan the credentials it needs, without writing the password into Git.
3. Fix the `ImageRepository` in Git so the scan finds the three tags and the `ImagePolicy` chooses `6.15.0`.

## Constraints

- Keep the names: the `ImageRepository` `podinfo` and the `ImagePolicy` `podinfo` in `flux-system`, in `clusters/kind/image-podinfo.yaml`.
- Change the `ImageRepository` in Git. A change made with `kubectl` is undone when Flux applies Git again, and the grader makes Flux apply Git before it checks.
- The password must live in a Secret in the cluster, not in a file in Git.
- Do not change the `ImagePolicy` rule and do not delete tags from the registry.

## Done when

- `flux get image repository podinfo` is `Ready` and shows three tags.
- `flux get image policy podinfo` shows `6.15.0`.
- After the grader adds the tag `6.15.1` to the private registry, the policy chooses `6.15.1`.

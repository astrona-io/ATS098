# Question

Solve this question on: `terminal`

**Time:** about 25 minutes · **Topic:** Automated Git write-backs

## Scenario

podinfo runs `6.14.0`. The `ImageRepository` `podinfo` scans the lab registry `registry.localtest.me:5000/podinfo`, and the `ImagePolicy` `podinfo` in `flux-system` follows every stable `6.x` release. Both are in Git, in `clusters/kind/image-podinfo.yaml`. Every release is still rolled out by a person who edits `apps/podinfo/kustomization.yaml`. The team wants Flux to do it.

The repository is `gitops/fleet` at `http://gitea.localtest.me:3000/gitops/fleet.git` (lab-only user `gitops`, password `gitops-password`, with write access). Start `kubectl -n gitea port-forward svc/gitea-http 3000:3000` in a second terminal before you use `git`.

## Your task

1. Mark the podinfo tag in `apps/podinfo/kustomization.yaml` so Flux may change it. The cluster pulls podinfo from `ghcr.io/stefanprodan/podinfo`, so only the tag may change.
2. Commit an `ImageUpdateAutomation` named `podinfo` in `flux-system` to `clusters/kind/image-automation.yaml`. It must:
   - commit as the author `fluxcdbot` with the email `fluxcdbot@example.com`;
   - push to `main`;
   - update the folder that holds the podinfo files.
3. Test it: copy podinfo `6.14.1` into the lab registry and check that it reaches the running Deployment through a commit by `fluxcdbot`.

To copy a release into the lab registry, run:

```sh
kubectl -n registry exec deploy/registry-tools -- \
  regctl image copy ghcr.io/stefanprodan/podinfo:6.14.1 registry.localtest.me:5000/podinfo:6.14.1
```

## Constraints

- Do not change the image name `ghcr.io/stefanprodan/podinfo` and do not change the `ImagePolicy`.
- Do not edit the tag by hand to make the test pass.
- Every Flux object you add lives in Git. The grader makes Flux apply Git before it checks.

## Done when

- The `newTag` line carries a setter marker for the policy `flux-system:podinfo` that writes only the tag.
- The `ImageUpdateAutomation` `podinfo` comes from Git, commits as `fluxcdbot@example.com` and pushes to `main`.
- When the grader copies podinfo `6.15.0` into the registry, the last change to `apps/podinfo/kustomization.yaml` is a commit by `fluxcdbot@example.com` that sets `6.15.0`, and the Deployment `podinfo` runs `ghcr.io/stefanprodan/podinfo:6.15.0`.

# Question

Solve this question on: `terminal`

**Time:** about 20 minutes · **Topic:** Commit messages from image automation

## Scenario

podinfo runs `6.14.0`. The `ImageRepository` and the `ImagePolicy` `podinfo` are in Git, the tag line in `apps/podinfo/kustomization.yaml` carries its setter marker, and the `ImageUpdateAutomation` `podinfo` in `clusters/kind/image-automation.yaml` already commits releases to `main`. The team reads the history of the repository to audit releases, and every release commit says only "Automated image update". It does not say which tag replaced which. It is also signed as `fluxcdbot`, and the team now uses the author `release-bot`.

The repository is `gitops/fleet` at `http://gitea.localtest.me:3000/gitops/fleet.git` (lab-only user `gitops`, password `gitops-password`, with write access). Start `kubectl -n gitea port-forward svc/gitea-http 3000:3000` in a second terminal before you use `git`.

## Your task

1. Change the author of the `ImageUpdateAutomation` `podinfo` to the name `release-bot` and the email `release-bot@example.com`.
2. Change its commit message template so that each release commit lists every changed value with the old value and the new value, using the field `.Changed.Changes`.
3. Test it: copy podinfo `6.14.1` into the lab registry and read the commit the automation makes.

To copy a release into the lab registry, run:

```sh
kubectl -n registry exec deploy/registry-tools -- \
  regctl image copy ghcr.io/stefanprodan/podinfo:6.14.1 registry.localtest.me:5000/podinfo:6.14.1
```

## Constraints

- Do not change the setter marker, the `ImagePolicy` or the push branch `main`.
- Do not edit the tag by hand.
- Every change lives in Git. The grader makes Flux apply Git before it checks.

## Done when

- The `ImageUpdateAutomation` `podinfo` comes from Git, commits as `release-bot@example.com`, pushes to `main` and has a message template that uses `.Changed.Changes`.
- When the grader copies podinfo `6.15.0` into the registry, the last change to `apps/podinfo/kustomization.yaml` is a commit by `release-bot@example.com` whose message contains the old tag `6.14.0` and the new tag `6.15.0`.

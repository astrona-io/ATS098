# Question

Solve this question on: `terminal`

**Time:** about 20 minutes · **Topic:** Operating image automation

## Scenario

podinfo runs `6.14.0`. The `ImageRepository` and the `ImagePolicy` `podinfo` are in Git and healthy, and the tag line in `apps/podinfo/kustomization.yaml` carries its setter marker. Releases still never reach Git. The team also never hears about image events, because nothing sends them out.

The repository is `gitops/fleet` at `http://gitea.localtest.me:3000/gitops/fleet.git` (lab-only user `gitops`, password `gitops-password`, with write access). Start `kubectl -n gitea port-forward svc/gitea-http 3000:3000` in a second terminal before you use `git`.

## Your task

1. Find out why the `ImageUpdateAutomation` `podinfo` does not commit, and fix the cause in Git.
2. Commit a `Provider` named `image-events` of type `generic` and an `Alert` named `image-updates` in `flux-system` to `clusters/kind/image-alerts.yaml`. The Alert must send the events of the `ImageRepository` `podinfo`, the `ImagePolicy` `podinfo` and the `ImageUpdateAutomation` `podinfo` to that Provider. Use `http://event-sink.flux-system.svc.cluster.local:8080/` as the address; nothing has to listen there.
3. Test it: copy podinfo `6.14.1` into the lab registry and check that the automation commits it.

To copy a release into the lab registry, run:

```sh
kubectl -n registry exec deploy/registry-tools -- \
  regctl image copy ghcr.io/stefanprodan/podinfo:6.14.1 registry.localtest.me:5000/podinfo:6.14.1
```

## Constraints

- Do not change the setter marker, the `ImagePolicy`, the author or the push branch.
- Do not edit the tag by hand.
- Every Flux object lives in Git. The grader makes Flux apply Git before it checks.

## Done when

- The `ImageUpdateAutomation` `podinfo` is not suspended, and nothing in the cluster changes that without a commit to Git.
- The `Provider` `image-events` and the `Alert` `image-updates` come from Git, and the Alert watches the three objects.
- When the grader copies podinfo `6.15.0` into the registry, the last change to `apps/podinfo/kustomization.yaml` is a commit by `fluxcdbot@example.com` that sets `6.15.0`.

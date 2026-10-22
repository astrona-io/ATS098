# Question

Solve this question on: `terminal`

**Time:** about 45 minutes, plus a few minutes for the environment to start · **Topic:** Progressive delivery

## Scenario

The podinfo team built a release pipeline with no person in it. A new stable `6.x` tag in the lab registry `registry.localtest.me:5000/podinfo` is chosen by an `ImagePolicy`, written to Git by an `ImageUpdateAutomation`, applied by Flux, and tested and promoted by Flagger. Everything is in the repository `gitops/fleet`:

| File | What it holds |
| --- | --- |
| `clusters/kind/image-podinfo.yaml` | The `ImageRepository` `podinfo` and the `ImagePolicy` `podinfo` |
| `clusters/kind/image-automation.yaml` | The `ImageUpdateAutomation` `podinfo`, author `fluxcdbot <fluxcdbot@example.com>`, pushing to `main` |
| `apps/podinfo/kustomization.yaml` | The tag in `images[].newTag`, with the setter marker for `flux-system:podinfo:tag` |
| `apps/podinfo/canary.yaml` | The `Canary` `podinfo`, provider nginx, with a load-test webhook |

podinfo `6.14.0` is initialized as the primary. The pipeline has never shipped anything: a new release stops at three places between the registry and `podinfo-primary`.

The repository is at `http://gitea.localtest.me:3000/gitops/fleet.git` (lab-only user `gitops`, password `gitops-password`). Start `kubectl -n gitea port-forward svc/gitea-http 3000:3000` in a second terminal before you use `git`. To copy a release into the registry, run:

```sh
kubectl -n registry exec deploy/registry-tools -- \
  regctl image copy ghcr.io/stefanprodan/podinfo:6.14.1 registry.localtest.me:5000/podinfo:6.14.1
```

## Your task

Make the pipeline ship: a new stable `6.x` release in the registry must become a commit by `fluxcdbot` on `main`, pass Flagger's analysis, and run as `podinfo-primary`. Follow a release through the pipeline and fix every place it stops.

## Constraints

- No person in the pipeline: do not set the tag by hand, and do not merge or promote anything yourself.
- Keep Flagger's analysis: no `skipAnalysis`, and keep the `request-success-rate` check with its minimum of `99`.
- Keep the object names and the author. Fix everything in Git.

## Done when

- The `ImagePolicy` and the `ImageUpdateAutomation` come from Git, and the automation updates the folder that holds `apps/podinfo/kustomization.yaml`.
- The `Canary` load test sends traffic through the load tester in the namespace `podinfo`.
- When the grader copies podinfo `6.15.0` into the registry, a commit by `fluxcdbot@example.com` sets `6.15.0` on `main`, the `Canary` is `Succeeded`, and `podinfo-primary` runs `ghcr.io/stefanprodan/podinfo:6.15.0`.

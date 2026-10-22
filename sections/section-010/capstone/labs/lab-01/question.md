# Question

Solve this question on: `terminal`

**Time:** about 30 minutes · **Topic:** Scanning image registries

## Scenario

The build pipeline of podinfo pushes one image for every commit to the repository `registry.localtest.me:5000/podinfo-builds` in the lab registry. Builds of the `main` branch are tagged `main-<commit>-<timestamp>`, for example `main-0c1d2e3-1760007200`. Builds of pull requests are tagged `pr-<number>-<commit>-<timestamp>`. The timestamp is a Unix timestamp: seconds since 1 January 1970, so a bigger number is a later build.

The test environment must always know the newest `main` build. A colleague committed `clusters/kind/image-builds.yaml` to the repository `gitops/fleet` with an `ImageRepository` `podinfo-builds` and an `ImagePolicy` `podinfo-main`. Neither works.

The repository is at `http://gitea.localtest.me:3000/gitops/fleet.git` (lab-only user `gitops`, password `gitops-password`). Start `kubectl -n gitea port-forward svc/gitea-http 3000:3000` in a second terminal before you use `git`. List the tags in the registry with:

```sh
kubectl -n registry exec deploy/registry-tools -- regctl tag ls registry.localtest.me:5000/podinfo-builds
```

## Your task

Make the `ImagePolicy` `podinfo-main` in `flux-system` choose the newest `main` build by its timestamp:

1. Make the scan of `podinfo-builds` succeed. The lab registry uses plain HTTP.
2. Make sure the scan keeps the `main-` tags.
3. Make the policy sort the `main-` tags by their timestamp, and never choose a pull request build.

## Constraints

- Keep the names `podinfo-builds` and `podinfo-main` and the file `clusters/kind/image-builds.yaml`.
- Change the objects in Git. The grader makes Flux apply Git before it checks.
- Do not delete or add tags in the registry yourself; the grader adds its own.

## Done when

- `flux get image repository podinfo-builds` is `Ready`, and its scan keeps the `main-` tags.
- `flux get image policy podinfo-main` shows `main-0c1d2e3-1760007200`.
- After the grader adds `main-aaaaaaa-1760010800` and `pr-42-bbbbbbb-1760099999`, the policy chooses `main-aaaaaaa-1760010800`.

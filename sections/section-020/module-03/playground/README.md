# Operate And Debug Image Automation — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-098-playground-020-03
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

Gitea with gitops/fleet (podinfo 6.14.0, an ImageRepository and a semver ImagePolicy in Git), the lab registry with podinfo 6.14.0, and Flux with the image controllers. The setter marker and an ImageUpdateAutomation are already in Git.

Not yet run: this playground was written from the Flux v2.9 and Flagger 1.45
documentation and has not been started yet.

## Run it

```sh
astrona run -c .
astrona destroy ats-098-playground-020-03
```

`astrona destroy` takes the environment name (`metadata.name` = `ats-098-playground-020-03`), not
the config path. `astrona submit` and `astrona test` do not apply — there is no
grading.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition (runtime + bootstrap only) |
| `bootstrap/prepare.sh` | Environment preparation run once at startup |
| `manifests/lab-start.yaml` | Gitea, tester, the lab registry and registry-tools |
| `manifests/flux-sync.yaml` | The `GitRepository` and Flux `Kustomization` named `fleet` |
| `manifests/repo/` | The files seeded into the repository `gitops/fleet` |
| `docs/overview.md` | What the environment contains and ideas to try |

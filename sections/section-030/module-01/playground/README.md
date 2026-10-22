# Roll Out Releases Gradually With Flagger — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-098-playground-030-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

Gitea with gitops/fleet (podinfo 6.14.0 behind an Ingress, no Canary yet), ingress-nginx, Flagger with its Prometheus and the load tester installed by Flux HelmReleases, and the lab registry.

Not yet run: this playground was written from the Flux v2.9 and Flagger 1.45
documentation and has not been started yet.

## Run it

```sh
astrona run -c .
astrona destroy ats-098-playground-030-01
```

`astrona destroy` takes the environment name (`metadata.name` = `ats-098-playground-030-01`), not
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

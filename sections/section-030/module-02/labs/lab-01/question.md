# Question

Solve this question on: `terminal`

**Time:** about 30 minutes, plus a few minutes for the environment to start · **Topic:** Progressive delivery

## Scenario

podinfo `6.14.0` runs in the namespace `podinfo` behind the Ingress `podinfo` for the host `app.example.com`. Flagger already manages it with a weighted `Canary` named `podinfo`, which sends a random share of all users to a new version. The next release, `6.14.1`, must reach only the testers first. Testers send the HTTP header `x-canary: insider`; every other user must stay on the old version until Flagger promotes.

The repository is `gitops/fleet` at `http://gitea.localtest.me:3000/gitops/fleet.git` (lab-only user `gitops`, password `gitops-password`). Start `kubectl -n gitea port-forward svc/gitea-http 3000:3000` in a second terminal before you use `git`.

## Your task

1. Change the `Canary` `podinfo` in `apps/podinfo/canary.yaml` in Git so that its analysis is an A/B test:
   - run `6` iterations, one every `15s`, and roll back after `5` failed checks;
   - send only requests with the header `x-canary` set exactly to `insider` to the canary;
   - keep the `request-success-rate` check with a minimum of `99` over `1m`;
   - keep the webhook `load-test`, and change its command so the load test sends the header `X-Canary: insider`, otherwise no test traffic reaches the canary.
2. Release `6.14.1` by changing the tag in `apps/podinfo/kustomization.yaml`, and let Flagger promote it.

## Constraints

- Do not set `skipAnalysis`, and do not change Deployments, Services or Ingresses with `kubectl`.
- The analysis must not keep `stepWeight` or `maxWeight`.
- Change the `Canary` and wait for Git to be applied before you release `6.14.1`.

## Done when

- The `Canary` `podinfo` comes from Git with the A/B analysis above.
- Git asks for `6.14.1`.
- The `Canary` is `Succeeded`, and `podinfo-primary` runs `ghcr.io/stefanprodan/podinfo:6.14.1`.

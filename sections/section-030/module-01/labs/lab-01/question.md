# Question

Solve this question on: `terminal`

**Time:** about 30 minutes, plus a few minutes for the environment to start · **Topic:** Progressive delivery

## Scenario

podinfo `6.14.0` runs in the namespace `podinfo` behind the Ingress `podinfo` for the host `app.example.com`. Flux installed ingress-nginx, Flagger (provider nginx, with its own Prometheus) and `flagger-loadtester`. The next release, `6.14.1`, must not reach every user at once. The team wants Flagger to test it on a share of the traffic first.

The repository is `gitops/fleet` at `http://gitea.localtest.me:3000/gitops/fleet.git` (lab-only user `gitops`, password `gitops-password`). Start `kubectl -n gitea port-forward svc/gitea-http 3000:3000` in a second terminal before you use `git`.

## Your task

1. Add a `Canary` named `podinfo` in the namespace `podinfo` to Git, in `apps/podinfo/`, and list it in `apps/podinfo/kustomization.yaml`. It must:
   - use the provider `nginx`, the Deployment `podinfo` as target and the Ingress `podinfo`;
   - create Services on port `9898` (target port `9898`);
   - analyse every `15s`, raise the weight by `25` up to `50`, and roll back after `5` failed checks;
   - require a `request-success-rate` of at least `99` over `1m`;
   - have a webhook named `load-test` that sends traffic through the load tester `http://flagger-loadtester.podinfo/`, with the command `hey -z 1m -q 10 -c 2 -host app.example.com http://ingress-nginx-controller.ingress-nginx/`.
2. Wait until the `Canary` is `Initialized`.
3. Release `6.14.1` by changing the tag in `apps/podinfo/kustomization.yaml`, and let Flagger promote it.

## Constraints

- Do not set `skipAnalysis`, and do not change Deployments or Services with `kubectl`.
- Do not add a `podinfo` Service or a `replicas` field to Git; Flagger owns both.
- Add the `Canary` before you release `6.14.1`. A `Canary` that appears with a new version only initializes it, without analysis.

## Done when

- The `Canary` `podinfo` comes from Git with the analysis above.
- Git asks for `6.14.1`.
- The `Canary` is `Succeeded`, and `podinfo-primary` runs `ghcr.io/stefanprodan/podinfo:6.14.1`.

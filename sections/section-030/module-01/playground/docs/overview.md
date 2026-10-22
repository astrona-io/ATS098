# Overview: Roll Out Releases Gradually With Flagger (Playground)

This is a **playground**, not a lab. It starts a fresh cluster with a Git server, Flux, ingress-nginx and Flagger, and then waits. There is no task, no `astrona submit` and no pass or fail. Explore, break things, `astrona destroy`, start over. It is the heaviest environment of the course and takes several minutes to start.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- **Flux 2.9.6** in `flux-system`, with the image controllers, and the `flux` command-line tool on your PATH.
- **Gitea** in the namespace `gitea`, with the repository `gitops/fleet` at `http://gitea.localtest.me:3000/gitops/fleet.git`. The lab-only user is `gitops`, password `gitops-password`. In the repository:
  - `infrastructure/`: the HelmRepositories and HelmReleases for ingress-nginx 4.15.1, Flagger 1.45.0 (with `meshProvider: nginx` and its own Prometheus) and the Flagger load tester.
  - `apps/podinfo/`: the Namespace, the Deployment `podinfo` (no `replicas` field), the Ingress `podinfo` for the host `app.example.com`, and the Kustomize file `kustomization.yaml` with `newTag: 6.14.0`. No `Canary` yet.
- **ingress-nginx** with the Service `ingress-nginx-controller` (type `ClusterIP`), **Flagger** and **flagger-prometheus** in the namespace `ingress-nginx`, and **flagger-loadtester** in the namespace `podinfo`.
- podinfo `6.14.0` in the namespace `podinfo`. Releases you can use: `6.14.1` and `6.15.0`.

## Helpers

Start the port-forward to Gitea in a second terminal and leave it running; every `git` command needs it. If `gitea.localtest.me` does not resolve, add `127.0.0.1 gitea.localtest.me` to `/etc/hosts`.

```sh
kubectl -n gitea port-forward svc/gitea-http 3000:3000
```

Paste these once in each new terminal. `call_podinfo` sends one request through ingress-nginx, as a user would; pass extra `curl` options such as a header. `canary_events` prints Flagger's events for the `Canary`. `primary_image` prints what users get.

```sh
call_podinfo() {
  kubectl -n podinfo exec deploy/flagger-loadtester -- \
    curl -s -H 'Host: app.example.com' "$@" http://ingress-nginx-controller.ingress-nginx/
}
canary_events() {
  kubectl -n podinfo describe canary podinfo | sed -n '/^Events:/,$p'
}
primary_image() {
  kubectl -n podinfo get deployment podinfo-primary -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
}
```

Use them like this: `call_podinfo`, `call_podinfo -H 'X-Canary: insider'`, `canary_events`, `primary_image`. Clone the repository with `git clone http://gitops:gitops-password@gitea.localtest.me:3000/gitops/fleet.git`.

## Practice tasks

- Add the `Canary` without the load-test webhook, release a new version, and read in the events why the analysis fails.
- Set `stepWeight: 10` and `maxWeight: 50`, and predict how long a good release takes with `interval: 15s` before you try it.
- Cause a rollback with `/status/500`, then put the old tag back in Git and watch the next analysis.
- Switch to A/B testing with a cookie match (`cookie: exact: "canary"`) instead of a header.
- Add the latency `MetricTemplate` and slow the canary down with requests to `/delay/2` during an analysis.

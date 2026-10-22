# Overview: Write New Image Tags Back To Git (Playground)

This is a **playground**, not a lab. It starts a fresh cluster with a Git server, a container registry and Flux, and then waits. There is no task, no `astrona submit` and no pass or fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- **Flux 2.9.6** in `flux-system`, with the four default controllers and the two image controllers, and the `flux` command-line tool on your PATH.
- **Gitea** in the namespace `gitea`, with the repository `gitops/fleet` at `http://gitea.localtest.me:3000/gitops/fleet.git`. The lab-only user is `gitops`, password `gitops-password`, with write access. In the repository:
  - `apps/podinfo/`: podinfo with `images[].newTag: 6.14.0` in the Kustomize file `kustomization.yaml`, and no setter marker.
  - `clusters/kind/image-podinfo.yaml`: the `ImageRepository` `podinfo` for `registry.localtest.me:5000/podinfo` and the `ImagePolicy` `podinfo` with the range `6.x`.
  - No `ImageUpdateAutomation`.
- **A lab container registry** at `registry.localtest.me:5000`, plain HTTP, holding only podinfo `6.14.0`. The pod `registry-tools` in the namespace `registry` runs `regctl`.
- podinfo `6.14.0` running in the namespace `podinfo`. The cluster pulls it from `ghcr.io/stefanprodan/podinfo`.

## Helpers

Start the port-forward to Gitea in a second terminal and leave it running; every `git` command needs it. If `gitea.localtest.me` does not resolve, add `127.0.0.1 gitea.localtest.me` to `/etc/hosts`.

```sh
kubectl -n gitea port-forward svc/gitea-http 3000:3000
```

Paste these once in each new terminal. `push_podinfo_tag` copies a real podinfo release (`6.14.1` or `6.15.0`) into the lab registry. `run_release_loop` runs every step of the loop now instead of waiting. `running_image` prints what the Deployment runs.

```sh
push_podinfo_tag() {
  kubectl -n registry exec deploy/registry-tools -- \
    regctl image copy "ghcr.io/stefanprodan/podinfo:$1" "registry.localtest.me:5000/podinfo:$1"
}
run_release_loop() {
  flux reconcile image repository podinfo
  flux reconcile image update podinfo
  flux reconcile kustomization podinfo --with-source
}
running_image() {
  kubectl -n podinfo get deployment podinfo -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
}
```

Use them like this: `push_podinfo_tag 6.14.1`, `run_release_loop`, `running_image`. Clone the repository with `git clone http://gitops:gitops-password@gitea.localtest.me:3000/gitops/fleet.git`.

## Practice tasks

- Put the full marker `# {"$imagepolicy": "flux-system:podinfo"}` on the `image:` line of the Deployment instead, and predict what the automation writes and why the rollout then fails. Put the `:tag` marker back on `newTag`.
- Set `update.path` to `./clusters` and run the loop. Read `flux get image update podinfo` and explain why nothing is committed.
- Write a message template that uses `.Changed.Changes`, and read the commit it produces.
- Push releases to the branch `image-updates`, then merge them with `git merge --ff-only origin/image-updates`.
- Suspend the automation with `flux suspend image update podinfo`, push a tag, and check that Git does not change. Resume it with `flux resume image update podinfo`.

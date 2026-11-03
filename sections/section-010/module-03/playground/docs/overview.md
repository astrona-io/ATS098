# Overview: Choose Tags With Ranges And Digests (Playground)

This is a **playground**, not a lab. It starts a fresh cluster with a Git server, a container registry and Flux, and then waits. There is no task, no `astrona submit` and no pass or fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- **Flux 2.9.6** in `flux-system`, with the four default controllers and the two image controllers (`image-reflector-controller`, `image-automation-controller`), and the `flux` command-line tool on your PATH.
- **Gitea**, a Git server in the namespace `gitea`, with the repository `gitops/fleet` at `http://gitea.localtest.me:3000/gitops/fleet.git`. The lab-only user is `gitops`, password `gitops-password`. The Flux `Kustomization` `fleet` applies everything under `clusters/kind`, and the Flux `Kustomization` `podinfo` applies `apps/podinfo`: podinfo `6.14.0` in the namespace `podinfo`.
- **A lab container registry** at `registry.localtest.me:5000`, plain HTTP, with the repository `podinfo` and the tags `6.12.0`, `6.13.0`, `6.14.0`, `6.14.1`, `6.15.0`, `6.16.0-beta.1`, `6.16.0-rc.1`, `6.16.0-rc.2`, `6.16.0-rc.10`, `7.0.0-rc.1` and `latest`. The pod `registry-tools` in the namespace `registry` runs `regctl`, a command-line tool for registries.
- No `ImageRepository` and no `ImagePolicy` yet.

## Helpers

Start the port-forward to Gitea in a second terminal and leave it running; every `git` command needs it. If `gitea.localtest.me` does not resolve, add `127.0.0.1 gitea.localtest.me` to `/etc/hosts`.

```sh
kubectl -n gitea port-forward svc/gitea-http 3000:3000
```

Paste these once in each new terminal. `list_tags` prints every tag in the lab registry. `retag_podinfo` adds a new tag to an existing image, so you can make up tags. `show_images` prints the scan results and the policy choices.

```sh
list_tags() {
  kubectl -n registry exec deploy/registry-tools -- regctl tag ls registry.localtest.me:5000/podinfo
}
retag_podinfo() {
  kubectl -n registry exec deploy/registry-tools -- \
    regctl image copy "registry.localtest.me:5000/podinfo:$1" "registry.localtest.me:5000/podinfo:$2"
}
show_images() {
  flux get image repository
  flux get image policy
}
```

Use them like this: `list_tags`, `retag_podinfo 6.15.0 6.15.1`, `show_images`. Clone the repository with `git clone http://gitops:gitops-password@gitea.localtest.me:3000/gitops/fleet.git`.

## Practice tasks

- Commit an `ImageRepository` for `registry.localtest.me:5000/podinfo` with `insecure: true` and four `ImagePolicy` objects with the ranges `6.x`, `~6.14.0`, `^6.14.0` and `>=6.14.0 <6.15.0`. Predict each choice before you look.
- Change a range so it follows release candidates, for example `>=6.15.0-0 <7.0.0-0`, and check that it chooses `6.16.0-rc.10`, not `6.16.0-rc.2`.
- Set `digestReflectionPolicy: Always` with an `interval` and read `.status.latestRef.digest`. Move a tag with `retag_podinfo 6.14.0 6.15.0-moved` and compare.
- Lower the `interval` of the `ImageRepository` to `30s`, add a tag and time how long the policy takes to move. Then run `flux reconcile image repository podinfo`.
- Run `flux events --for ImageRepository/podinfo` and `flux get image all` after every change.

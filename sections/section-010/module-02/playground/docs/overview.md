# Overview: Scan A Private Registry (Playground)

This is a **playground**, not a lab. It starts a fresh cluster with a Git server, two container registries and Flux, and then waits. There is no task, no `astrona submit` and no pass or fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- **Flux 2.9.6** in `flux-system`, with the four default controllers and the two image controllers (`image-reflector-controller`, `image-automation-controller`), and the `flux` command-line tool on your PATH.
- **Gitea**, a Git server in the namespace `gitea`, with the repository `gitops/fleet` at `http://gitea.localtest.me:3000/gitops/fleet.git`. The lab-only user is `gitops`, password `gitops-password`. The Flux `Kustomization` `fleet` applies everything under `clusters/kind`, and the Flux `Kustomization` `podinfo` applies `apps/podinfo`: podinfo `6.14.0` in the namespace `podinfo`.
- **The lab registry** at `registry.localtest.me:5000`, plain HTTP, open to everyone, with the tags `6.12.0` to `6.15.0`, `6.16.0-rc.1`, `7.0.0-rc.1` and `latest`.
- **A private registry** at `registry-private.registry.svc.cluster.local:5000`, plain HTTP, that answers every request without credentials with `401 Unauthorized`. The user is `scanner` and the password is `scanner-password`. It holds the repository `podinfo` with the tags `6.13.0`, `6.14.0` and `6.15.0`.
- The pod `registry-tools` in the namespace `registry` runs `regctl`, a command-line tool for registries. It is already logged in to the private registry.
- No `ImageRepository` and no `ImagePolicy` yet.

## Helpers

Start the port-forward to Gitea in a second terminal and leave it running; every `git` command needs it. If `gitea.localtest.me` does not resolve, add `127.0.0.1 gitea.localtest.me` to `/etc/hosts`.

```sh
kubectl -n gitea port-forward svc/gitea-http 3000:3000
```

Paste these once in each new terminal. `list_private_tags` prints the tags in the private registry. `show_images` prints the scan results and the policy choices.

```sh
list_private_tags() {
  kubectl -n registry exec deploy/registry-tools -- \
    regctl tag ls registry-private.registry.svc.cluster.local:5000/podinfo
}
show_images() {
  flux get image repository
  flux get image policy
}
```

Clone the repository with `git clone http://gitops:gitops-password@gitea.localtest.me:3000/gitops/fleet.git`.

## Practice tasks

- Commit an `ImageRepository` for the private registry and read the error in `flux get image repository`.
- Create a Secret of type `kubernetes.io/dockerconfigjson` with the user `scanner`, and add `secretRef` to the `ImageRepository` in Git.
- Create the Secret with a wrong password and read how the error changes.
- Move the Secret into a `ServiceAccount` as an image pull secret and use `serviceAccountName` instead of `secretRef`.
- Create a Secret that holds a `ca.crt` key with `--dry-run=client -o yaml` and read its shape.

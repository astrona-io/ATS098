# Prerequisites

Before starting this capstone you should be able to:

- Read `flux get image all`, `flux events` and `kubectl describe canary`.
- Read an `ImagePolicy` semver range and an `ImageUpdateAutomation`.
- Clone a Git repository, change a file, commit and push.

## What the environment gives you

The capstone environment builds itself before the task begins:

- A single-node `kind` Kubernetes cluster, with `kubectl` already pointed at it.
- The `flux` command-line tool, version **2.9.6**, on your PATH.
- **Flux 2.9.6** in `flux-system`, with the image reflector and image automation controllers.
- Gitea in the namespace `gitea`, with the repository `gitops/fleet` at
  `http://gitea.localtest.me:3000/gitops/fleet.git`. The lab-only user is `gitops` with the
  password `gitops-password`. Start `kubectl -n gitea port-forward svc/gitea-http 3000:3000`
  in a second terminal before you use `git`. If `gitea.localtest.me` does not resolve,
  add `127.0.0.1 gitea.localtest.me` to `/etc/hosts`.
- The lab container registry `registry.localtest.me:5000` (plain HTTP), and the pod
  `registry-tools` in the namespace `registry` with the `regctl` command.
- **ingress-nginx**, **Flagger 1.45.0** with its Prometheus, and the Flagger load
  tester, installed by Flux from Helm charts. They take several minutes to start.

## Working rules

- Everything is graded on the **final state of Git and the cluster**. Change Flux
  objects and application files in Git, not with `kubectl apply` or `kubectl edit`:
  the grader makes Flux apply Git again before it checks.
- The grader adds new image tags to the lab registry and follows them, so leave the
  automation running.
- The environment needs outbound internet to `ghcr.io`.

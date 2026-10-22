# Get Your Machine Ready

Every playground and lab in this course runs on your own machine, in a small Kubernetes cluster. A tool called `astrona` builds it for you, sets it up, grades your work and removes it again. This page gets your machine ready: first the tools you need, then the handful of `astrona` commands you will use every day, and last what to do when a start goes wrong.

## What you need

Every section needs the same set of tools. Install these before you start:

- **A container engine:** Docker or Podman. The cluster runs inside it.
- **`kind`:** runs Kubernetes inside the container engine. Flux 2.9 needs Kubernetes 1.34.1 or later, so use a recent `kind` release.
- **`kubectl`:** talks to the cluster.
- **`git`:** you clone the course repository, commit and push from your own machine.
- **`flux`:** the Flux command-line tool. Each playground and lab also installs version 2.9.6 of it, so the version always matches the controllers.
- **The astrona command-line tool.**
- **`jq`:** reads JSON, so you can pick out one field of a Flux object.

The playgrounds and labs also need **outbound internet** while they start. They download the Flux command-line tool from GitHub, the controller and podinfo images from `ghcr.io`, and in the last section the ingress-nginx and Flagger Helm charts. Without outbound internet, those starts fail with errors that have nothing to do with Flux.

Give your container engine at least **6 GiB** of memory. The last section runs Gitea, a registry, six Flux controllers, ingress-nginx, Flagger, Prometheus and a load tester in one cluster, and its environments take several minutes to start.

## Reaching the Git server

The Git server runs inside the cluster, so your machine reaches it through a port-forward. Every page that uses `git` asks you to start it in a second terminal and leave it running:

```sh
kubectl -n gitea port-forward svc/gitea-http 3000:3000
```

The repository address is always `http://gitea.localtest.me:3000/gitops/fleet.git`. The name `gitea.localtest.me` is a public DNS name that points at `127.0.0.1`, your own machine, so the port-forward answers it. Inside the cluster, the same name points at the Git server, so Flux and you use the same address.

Some home routers block DNS answers that point at `127.0.0.1`. If `git clone` says it cannot resolve `gitea.localtest.me`, add this line to `/etc/hosts` on your machine:

```
127.0.0.1 gitea.localtest.me
```

The Git server uses plain HTTP and the lab-only user `gitops` with the password `gitops-password`. A real Git server uses HTTPS or SSH and real credentials.

You do not have to check your tools by hand. Let `astrona` look at your machine for you:

```sh
astrona setup
```

`astrona setup` looks at what is missing, shows you each step it would take, and asks before it does anything. On macOS it can install `kind`, `kubectl` and Podman. Install `git`, `flux` and `jq` yourself.

Later, you can check your machine at any time:

```sh
astrona check
```

## The commands you use every day

Once your machine is ready, you need only a handful of `astrona` commands. Each module page and lab page shows the exact command to copy, so you do not need to remember paths. This section walks through them in the order you meet them: sign in, start, pause, submit and clean up.

Labs from the course catalog are tied to your Astrona account, so you sign in first:

```sh
astrona login
```

Next you start a playground or a lab. Each module page and lab page shows the exact `astrona run` command for it. It looks like this:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS098.git -c sections/section-010/module-01/playground
```

When the cluster is ready, `kubectl` already points at it.

A chapter that sends you to a lab asks you to pause the playground first. Pausing frees your machine's memory but keeps everything you built:

```sh
astrona stop <name>
```

When the lab is done, start the playground again and carry on where you left off:

```sh
astrona start <name>
```

Inside a lab, you send your work for grading with `astrona submit`. The grader checks the live cluster. It reads the Flux objects, the Git repository and the running application, so your fix has to actually work, not only make an error message go away. Each lab page shows the exact command:

```sh
astrona submit -c sections/section-010/module-01/labs/lab-01
```

You can submit as often as you like.

When you are done with a playground or a lab, remove it:

```sh
astrona destroy <name>
```

The name is the environment's name, printed by `astrona run` and shown on each page (for example `ats-098-playground-010-01`). It is not the folder path. To see what is on your machine, list it:

```sh
astrona list
```

> [!WARNING]
> **Run one environment at a time.** Each playground and lab is a whole cluster with its own Git server and Flux. Two running at once can use up your machine's memory, and it is easy to send a command to the wrong one. Pause or destroy the playground before you start the lab.

## When a start goes wrong

Sometimes a playground or lab does not start cleanly. Ask `astrona` what is wrong before you try anything else:

```sh
astrona doctor
```

It checks your machine, the lab's configuration and the running lab, and tells you how to fix what it finds.

If a start fails while it downloads something, check your network first. If `git` cannot reach the repository, check that the port-forward is still running in your second terminal; it stops when the playground restarts. Remember also that a lab that starts with Flux objects that are not `Ready` is often broken on purpose: the lab's task tells you when that is the case. With your machine ready and these commands at hand, you can start the first module.

# Suspending And Resuming Automation

Sometimes the loop must stop on purpose: a bad release is in the registry, a freeze is in force, or the team is moving the repository. Stopping is easy, and stopping in a way that lasts is not. This part pauses the automation with the command line, shows what the next sync does to that pause, and pauses it correctly in Git.

## Suspend from the command line

Every Flux object that has `spec.suspend` can be paused. `flux suspend` sets the field, and the controller skips the object at each interval. The object keeps its status, so you can still read it.

<!-- astrona:playground:renew -->

```sh
flux suspend image update podinfo
flux get image update podinfo
```

The `SUSPENDED` column is `True`. Copy a new release into the lab registry and run the loop:

```sh
kubectl -n registry exec deploy/registry-tools -- \
  regctl image copy ghcr.io/stefanprodan/podinfo:6.14.1 registry.localtest.me:5000/podinfo:6.14.1
flux reconcile image repository podinfo
flux get image policy podinfo
```

The scan finds `6.14.1` and the policy chooses it, because only the automation is suspended. Clone the repository and look at the history of the marked file: it has no new commit. The loop is stopped at the automation, and the registry and the policy go on.

Resume it:

```sh
flux resume image update podinfo
```

The controller commits `6.14.1` at once. `flux resume` also reconciles the object, so no wait is needed.

## The sync undoes a command-line pause

Suspend again, and make the Flux `Kustomization` `fleet` apply Git:

```sh
flux suspend image update podinfo
flux reconcile kustomization fleet --with-source
flux get image update podinfo
```

If Git does not contain `suspend: true`, the object may come back not suspended after the sync, because the Flux `Kustomization` applies the object exactly as Git defines it, and Git defines it without the field. The pause from the command line is a change in the cluster that Git does not know about, and a GitOps system puts Git back in charge. Treat a command-line pause as a short pause for investigation, not as a decision.

## Suspend in Git

For a pause that lasts, put the field in the file. In your clone, add one line under `spec` in `clusters/kind/image-automation.yaml`:

```yaml
spec:
  interval: 1m
  suspend: true
```

Commit and push it, and apply it:

```sh
git commit -am "Freeze image automation"
git push
flux reconcile kustomization fleet --with-source
flux get image update podinfo
```

The object is suspended, and every later sync keeps it that way. The history of Git says who froze the loop and when. To lift the freeze, change the line to `suspend: false` or remove it, and commit again.

## Suspend a whole level

To stop everything that Flux applies from one source, suspend the Flux `Kustomization`. To stop the scan, suspend the `ImageRepository`. Choose the object that stops only what you mean to stop. Suspending the `ImageRepository` stops new tags from appearing, and suspending the automation stops new commits while the policy still follows the registry. The second is usually better during a freeze, because the policy is current when you lift it.

You can now pause the loop at the object you choose, and make the pause last by putting it in Git. A paused loop is quiet, so the next part makes it tell people what it does.

## Common pitfalls

> [!WARNING]
> - **A command-line pause that must last.** The next sync can undo it. Put `suspend: true` in Git.
> - **Forgetting a pause in Git.** The loop stays stopped for weeks. Add a comment with the reason and the date next to the field.
> - **Suspending the `ImageRepository` and expecting new commits.** Nothing new is scanned.
> - **Using `flux resume` on an object that Git suspends.** The next sync suspends it again.

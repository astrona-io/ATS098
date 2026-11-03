# Common Failure Causes

Most image automation faults come from a short list. Each one leaves its own evidence in a status, an event or a log, and a learner who knows the list can go from symptom to cause in a few commands. This part gives the controller log, then walks the list in the order of the loop.

## The controller log

Every object's status shows the last result, and the controller log shows the history. The `flux logs` command reads the logs of the Flux controllers, and filters them by kind and name:

<!-- astrona:playground:renew -->

```sh
flux logs --kind=ImageUpdateAutomation --name=podinfo --since=10m
```

The same flags work for `ImageRepository` and `ImagePolicy`. Add `--level=error` to show only errors. The plain Kubernetes command is `kubectl -n flux-system logs deploy/image-automation-controller` for the automation controller, and `deploy/image-reflector-controller` for the scan and the policy.

## The faults, in loop order

| Symptom | Where to look | Likely cause |
| --- | --- | --- |
| The scan is not ready | `flux get image repository`, message | Wrong `image` field, a registry that needs a scheme or `insecure: true`, missing credentials |
| The scan works and the policy chose no tag | `flux get image policy`, message | A range or a filter that matches no tag, a pattern that fails to extract a value |
| The policy chose a tag and Git does not change | `flux get image update`, `lastAutomationRunTime` | A marker that names the wrong policy or has a wrong suffix, an `update.path` without the file, a suspended automation |
| The automation fails | the log of the automation | Credentials that cannot write, a push branch that the server protects, a template that fails to render |
| Git changed and the cluster did not | `flux get kustomization`, `flux trace` | The Flux `Kustomization` is suspended or failing, the push went to a branch Flux does not apply |
| The Deployment shows a wrong image | the marker | A full marker that wrote the scan registry's name |

Walk the table top to bottom and stop at the first row that matches. Each row depends on the one above, so a fault at the top hides every fault below it.

## Two faults to see

Two are easy to reproduce. First, the marker with the wrong policy name. In your clone of `gitops/fleet`, change the marker in `apps/podinfo/kustomization.yaml` from `flux-system:podinfo:tag` to `flux-system:podinfox:tag`:

```sh
sed -i.bak 's/podinfo:tag/podinfox:tag/' apps/podinfo/kustomization.yaml && rm apps/podinfo/kustomization.yaml.bak
git commit -am "Break the marker"
git push
flux reconcile kustomization fleet --with-source
flux reconcile image update podinfo
flux get image update podinfo
flux logs --kind=ImageUpdateAutomation --name=podinfo --since=2m
```

The automation reports that it cannot find the policy, or does not change the file. Either way, the log names the policy it looked for. Restore the marker with `git revert HEAD --no-edit` and push.

Second, a push that the server refuses. In Gitea, a branch protection rule on `main` that allows only pull requests makes every push from the automation fail with a message from the server. The status of the automation carries the Git error, and the log has the full text. The fix is a rule that lets the automation's account push, or `push.branch` to a separate branch that a person merges.

## A habit for the exam and for work

Name the owner of each step before you touch anything: the `ImageRepository` finds tags, the `ImagePolicy` chooses one, the `ImageUpdateAutomation` commits it, and the Flux `Kustomization` applies it. Then read each in order, and change only the object whose result is the first wrong one. A fix made two objects after the real fault hides the fault and keeps it.

You now know how to read the loop, trace a release, pause it, send its events out and match a symptom to a cause. That completes the operating side of image automation.

## Common pitfalls

> [!WARNING]
> - **Fixing the last object in the chain.** The cause is in the first object whose result is wrong.
> - **Reading the log of the wrong controller.** Scans and policies are in `image-reflector-controller`, commits are in `image-automation-controller`.
> - **Reading old log lines.** Use `--since` and reconcile first, so the lines are about your change.
> - **Restarting the controller to fix a fault.** A restart does not change Git or the object, and the fault returns.

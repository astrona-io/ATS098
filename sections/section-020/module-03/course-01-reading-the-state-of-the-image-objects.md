# Reading The State Of The Image Objects

When a release stops, the first job is to see where. Each image object keeps its result in its status, and the `flux` command-line tool prints those statuses in short lines. This part reads all three objects at once, then reads the fields behind the short lines, so you can tell a healthy loop from a stuck one in under a minute.

## One command for all image objects

The `flux get image` commands list the image objects of the cluster. `all` lists every kind at once. The flag `-A` includes every namespace, and without it the tool uses `flux-system`.

<!-- astrona:playground:renew -->

```sh
flux get image all -A
```

The output has three groups: `ImageRepository`, `ImagePolicy` and `ImageUpdateAutomation`. Each line has a name, a `READY` column, a message, and a `SUSPENDED` column. `READY` is `True` when the last reconcile worked. The message says what the controller did: the number of tags a scan found, the tag a policy chose, or the commit an automation pushed. `SUSPENDED` is `True` when someone paused the object.

To read one kind, use its own command. Each takes a name:

```sh
flux get image repository podinfo
flux get image policy podinfo
flux get image update podinfo
```

The three objects hand work to each other in this order, so read them in this order. A repository that is not ready explains a policy that is stale. A stale policy explains an automation that has nothing to write.

## The status behind the line

The short line comes from the status conditions. A condition is an entry with a type, a status of `True` or `False`, a reason and a message. Every Flux object has a `Ready` condition. Print it for the repository:

```sh
kubectl -n flux-system get imagerepository podinfo -o jsonpath='{.status.conditions}'
```

When the object is healthy, the `Ready` condition has the reason `Succeeded`. When it is not, the reason names a class of fault, and the message names the fault itself, for example that the registry refused the connection. The three objects also keep a result outside the conditions:

| Object | Field | What it holds |
| --- | --- | --- |
| `ImageRepository` | `.status.lastScanResult` | The tag count, the latest tags and the scan time |
| `ImagePolicy` | `.status.latestRef` | The name, the tag and, when asked, the digest of the chosen image |
| `ImageUpdateAutomation` | `.status.lastPushCommit`, `.status.lastPushTime`, `.status.lastAutomationRunTime` | The last commit, when it was pushed, and when the controller last ran |

`lastAutomationRunTime` is the field to check for an automation that looks healthy and never commits. If the time moves forward at each interval, the controller runs and finds nothing to change. If it does not move, the object is suspended or the controller is not running.

## Break the scan and read the message

Break the registry address in your clone of `gitops/fleet` (start the port-forward to Gitea first, with `kubectl -n gitea port-forward svc/gitea-http 3000:3000`):

```sh
git clone http://gitops:gitops-password@gitea.localtest.me:3000/gitops/fleet.git
cd fleet
sed -i.bak 's#registry.localtest.me:5000/podinfo#registry.localtest.me:5001/podinfo#' clusters/kind/image-podinfo.yaml && rm clusters/kind/image-podinfo.yaml.bak
git commit -am "Break the registry address"
git push
flux reconcile kustomization fleet --with-source
flux reconcile image repository podinfo
flux get image all
```

The repository is not ready, and its message says that the scan failed with a connection error. The policy keeps the last tag it chose, and the automation still looks ready. This is the usual shape of a fault: the object that fails says so, and the objects after it stay calm because they still hold old results. Restore the address with `git revert HEAD --no-edit`, push, and reconcile again.

You can now read the whole loop in one command and find the first object that fails. A Deployment is the object people look at first, so the next part starts from it.

## Common pitfalls

> [!WARNING]
> - **Reading only the automation.** It can be ready while the scan under it is failing. Start from the repository.
> - **Forgetting `-A`.** The tool lists `flux-system` only.
> - **Trusting `READY: True` for an automation that never commits.** Check `lastAutomationRunTime` and `lastPushCommit`.
> - **Fixing the symptom in the cluster.** A hand edit in the cluster is undone at the next sync. Change Git.

# Solution: Alert On Image Updates

Work the task yourself first. Running `astrona submit -c sections/section-020/module-03/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks three things: the setter marker is still in place, the automation is not suspended and the `Provider` and `Alert` come from Git, and a real release. It copies podinfo `6.15.0` into the registry and follows it to a commit by `fluxcdbot@example.com`.

## Step 1: Find why nothing is committed

Look at the three image objects in one list:

```sh
flux get image all -n flux-system
```

The repository and the policy are ready. The automation `podinfo` shows `SUSPENDED` as `True`. A suspended object does nothing until someone resumes it.

## Step 2: Fix it in Git, not with the command line

Run `flux resume image update podinfo` and the object works for a moment. Flux then applies Git again, Git says `suspend: true`, and the object is suspended again. The fix belongs in Git. Clone the repository (port-forward first):

```sh
git clone http://gitops:gitops-password@gitea.localtest.me:3000/gitops/fleet.git
cd fleet
```

Remove the line `suspend: true` from `clusters/kind/image-automation.yaml`.

## Step 3: Add the Provider and the Alert

Save this as `clusters/kind/image-alerts.yaml`:

```yaml
apiVersion: notification.toolkit.fluxcd.io/v1beta3
kind: Provider
metadata:
  name: image-events
  namespace: flux-system
spec:
  type: generic
  address: http://event-sink.flux-system.svc.cluster.local:8080/
---
apiVersion: notification.toolkit.fluxcd.io/v1beta3
kind: Alert
metadata:
  name: image-updates
  namespace: flux-system
spec:
  providerRef:
    name: image-events
  eventSeverity: info
  eventSources:
    - kind: ImageRepository
      name: podinfo
    - kind: ImagePolicy
      name: podinfo
    - kind: ImageUpdateAutomation
      name: podinfo
```

Commit both files and push:

```sh
git add clusters/kind/image-automation.yaml clusters/kind/image-alerts.yaml
git commit -m "Resume the image automation and alert on image events"
git push
flux reconcile kustomization fleet --with-source
flux get image update podinfo
```

## Step 4: Test with 6.14.1

```sh
kubectl -n registry exec deploy/registry-tools -- \
  regctl image copy ghcr.io/stefanprodan/podinfo:6.14.1 registry.localtest.me:5000/podinfo:6.14.1
flux reconcile image repository podinfo
flux reconcile image update podinfo
git pull
git log -1 --format='%ae %s' -- apps/podinfo/kustomization.yaml
```

The last change to the file is by `fluxcdbot@example.com`.

## Step 5: Submit

```sh
astrona submit -c sections/section-020/module-03/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| `flux resume image update podinfo` only | The next sync applies `suspend: true` from Git again |
| An Alert without the `ImageUpdateAutomation` source | The commit events are never sent |
| `kubectl apply` of the Alert | The grader makes Flux apply Git first, and the object is not in Git |
| Editing `apps/podinfo/kustomization.yaml` by hand | The last change is not by `fluxcdbot` |

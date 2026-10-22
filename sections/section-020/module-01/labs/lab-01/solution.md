# Solution: Automate The podinfo Release

Work the task yourself first. Running `astrona submit -c sections/section-020/module-01/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks three things: the marker on the `newTag` line, the `ImageUpdateAutomation` in Git with the right author, branch and path, and a real release. It copies podinfo `6.15.0` into the registry and follows it to a commit by `fluxcdbot@example.com` and to the running Deployment.

## Step 1: Clone the repository

Start the port-forward in a second terminal (`kubectl -n gitea port-forward svc/gitea-http 3000:3000`), then clone:

```sh
git clone http://gitops:gitops-password@gitea.localtest.me:3000/gitops/fleet.git
cd fleet
cat apps/podinfo/kustomization.yaml
```

The tag is in `images[].newTag: 6.14.0`, with no marker.

## Step 2: Mark the tag

The policy scans `registry.localtest.me:5000/podinfo`, but the cluster pulls `ghcr.io/stefanprodan/podinfo`. A full marker would write the lab registry's name into Git, so use the `:tag` form. Change `apps/podinfo/kustomization.yaml` so the whole file reads:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespace.yaml
  - deployment.yaml
  - service.yaml
images:
  - name: ghcr.io/stefanprodan/podinfo
    newTag: 6.14.0 # {"$imagepolicy": "flux-system:podinfo:tag"}
```

## Step 3: Add the automation

Save this as `clusters/kind/image-automation.yaml`:

```yaml
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImageUpdateAutomation
metadata:
  name: podinfo
  namespace: flux-system
spec:
  interval: 1m
  sourceRef:
    kind: GitRepository
    name: fleet
  git:
    checkout:
      ref:
        branch: main
    commit:
      author:
        name: fluxcdbot
        email: fluxcdbot@example.com
      messageTemplate: "Automated image update by {{ .AutomationObject }}"
    push:
      branch: main
  update:
    path: ./apps/podinfo
    strategy: Setters
```

Commit both files together and push:

```sh
git add apps/podinfo/kustomization.yaml clusters/kind/image-automation.yaml
git commit -m "Automate podinfo releases"
git push
flux reconcile kustomization fleet --with-source
flux get image update podinfo
```

The automation is `Ready`. It has nothing to commit yet, because the policy still chooses `6.14.0`.

## Step 4: Test with 6.14.1

Copy the release into the lab registry and run the loop now instead of waiting:

```sh
kubectl -n registry exec deploy/registry-tools -- \
  regctl image copy ghcr.io/stefanprodan/podinfo:6.14.1 registry.localtest.me:5000/podinfo:6.14.1
flux reconcile image repository podinfo
flux reconcile image update podinfo
flux reconcile kustomization podinfo --with-source
kubectl -n podinfo rollout status deployment/podinfo
```

Then check Git and the cluster:

```sh
git pull
git log -1 --format='%ae %s' -- apps/podinfo/kustomization.yaml
kubectl -n podinfo get deployment podinfo -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

The last change to the file is by `fluxcdbot@example.com`, and podinfo runs `ghcr.io/stefanprodan/podinfo:6.14.1`.

## Step 5: Submit

```sh
astrona submit -c sections/section-020/module-01/labs/lab-01
```

The grader runs the same loop with `6.15.0`.

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| The full marker on the Deployment's `image:` line | The automation writes `registry.localtest.me:5000/podinfo:6.15.0`, which the cluster cannot pull, and the marker check fails |
| `update.path: ./clusters/kind` | No marked file under the path; the automation never commits |
| `push.branch: image-updates` | The commit never reaches `main`, so the cluster never changes |
| Setting `newTag: 6.15.0` by hand | The last change is not by `fluxcdbot`, and the next release would need a person again |
| `kubectl apply` of the automation | The grader makes Flux apply Git first, and the object is not in Git |

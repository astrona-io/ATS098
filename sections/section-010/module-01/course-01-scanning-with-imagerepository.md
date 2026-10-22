# Scanning A Registry With ImageRepository

Flux applies what Git says, and Git says podinfo `6.14.0`. Two newer releases already sit in the registry, and Flux does not know about them. Before Flux can roll out a new tag, something has to look at the registry and list what is there. This part sets up that look: one `ImageRepository`, committed to Git like every other Flux object, and the scan result it produces.

## The controller and the object

A container registry is a server that stores container images. Each image lives in a repository of the registry, and a tag is a name that points at one image, such as `6.15.0`. Registries answer a standard HTTP interface, so one client can list the tags of any of them.

The image reflector controller is that client in Flux. It is one of two optional Flux controllers for image automation, and your playground runs it in the namespace `flux-system`. It watches `ImageRepository` objects. Each `ImageRepository` names one image, and at each interval the controller lists the image's tags and stores the result in the object's status.

```mermaid
flowchart LR
    R["registry"] -->|"list tags"| C["image-reflector-controller"]
    C -->|"status"| I["ImageRepository"]
```

The diagram shows the controller reading the tags from the registry and writing them into the status of the `ImageRepository`.

## Write the first ImageRepository

Everything Flux does in this cluster comes from Git, so the `ImageRepository` goes into the repository too. Git work happens on your machine. Start the port-forward to Gitea in a second terminal and leave it running:

<!-- astrona:playground:renew -->

```sh
kubectl -n gitea port-forward svc/gitea-http 3000:3000
```

Back in your first terminal, clone the repository. The user `gitops` with the password `gitops-password` exists only in this lab. If `gitea.localtest.me` does not resolve, add `127.0.0.1 gitea.localtest.me` to `/etc/hosts` and try again.

```sh
git clone http://gitops:gitops-password@gitea.localtest.me:3000/gitops/fleet.git
cd fleet
```

Save this as `clusters/kind/image-podinfo.yaml` in your clone:

```yaml
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImageRepository
metadata:
  name: podinfo
  namespace: flux-system
spec:
  image: registry.localtest.me:5000/podinfo
  interval: 1m
  # The lab registry has no TLS. A real registry uses HTTPS.
  insecure: true
```

The `image` field is the registry address and the repository, with no `http://` in front and no tag. The `interval` says how often the controller lists the tags again. `insecure: true` allows a registry that uses plain HTTP, which is true only for this lab registry.

Commit and push it:

```sh
git add clusters/kind/image-podinfo.yaml
git commit -m "Scan the podinfo image"
git push
```

Then make Flux apply it now, instead of waiting for the next interval, and check the result:

```sh
flux reconcile kustomization fleet --with-source
flux get image repository podinfo
```

The `READY` column shows `True` and the message says how many tags the last scan found. The count is nine, one for every tag in the lab registry. If the scan fails, the message says why, for example that the registry answered over HTTP while the controller expected HTTPS.

## Read the scan result

The one-line message hides most of the result. The full scan result is in the status of the object:

```sh
kubectl -n flux-system get imagerepository podinfo -o jsonpath='{.status.lastScanResult}' | jq
```

Three fields matter. `tagCount` is the number of tags that the scan kept. `latestTags` lists the most recent of them; it is a sample for people to read, not the order Flux uses to choose. `scanTime` says when the controller last asked the registry. A `canonicalImageName` field next to them shows the image name with every part written out.

The list holds `latest`, `7.0.0-rc.1` and `6.16.0-rc.1` next to the releases. The controller does not judge tags: it stores every one it finds. Choosing between them is the job of a different object.

## Leave tags out with exclusionList

Some tags should never count, whatever rule chooses later. Signatures of images, for example, are stored as tags that end in `.sig`. The `exclusionList` field holds regular expressions, and the scan leaves out every tag that matches one of them. When you do not set the field, it holds one expression, `^.*\.sig$`, so signature tags are left out by default.

Leave out the moving tag `latest` too. A tag that points at a different image every week is not a release. Change the end of `clusters/kind/image-podinfo.yaml` so it reads:

```yaml
  insecure: true
  exclusionList:
    - '^.*\.sig$'
    - '^latest$'
```

When you set `exclusionList`, it replaces the default, so the `.sig` expression is listed again. Commit, push and check the count:

```sh
git commit -am "Leave out the latest tag"
git push
flux reconcile kustomization fleet --with-source
flux reconcile image repository podinfo
flux get image repository podinfo
```

The scan now keeps eight tags. `latest` is still in the registry; the controller only stops reporting it.

You now have a scan of the registry, stored in Git and refreshed every minute, with the tags that should never count left out. What the scan cannot do is choose. Eight tags remain, and three of them are not stable releases. Choosing one takes a policy.

## Common pitfalls

> [!WARNING]
> - **Writing a scheme or a tag in `image`.** The field takes `registry.localtest.me:5000/podinfo`, not `http://registry.localtest.me:5000/podinfo:6.14.0`.
> - **Leaving out `insecure: true` for a plain HTTP registry.** The scan fails with a TLS error. A real registry uses HTTPS and does not need the field.
> - **Forgetting the default when you set `exclusionList`.** Your list replaces `^.*\.sig$`, so add it back if you want signature tags left out.
> - **Reading `latestTags` as Flux's choice.** It is only a sample of recent tags. The choice comes from an `ImagePolicy`.
> - **Applying the object with `kubectl apply`.** It works until the next sync. Then Flux applies Git again, and an object that only exists in the cluster is not managed by anyone.

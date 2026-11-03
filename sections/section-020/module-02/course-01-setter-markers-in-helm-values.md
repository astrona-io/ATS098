# Setter Markers In Helm Values

Many applications are not deployed with a plain Kustomize file. They are deployed with a Helm chart, and the image is a value: a `repository` and a `tag` in a values file, or in the `spec.values` of a `HelmRelease`. The automation can update those fields too. This part shows how a marker maps onto the parts of an image reference, and puts three markers in a values file.

## One image reference, three parts

An image reference has up to three parts: the name (`ghcr.io/stefanprodan/podinfo`), the tag (`6.14.0`) and the digest (`sha256:...`). Charts store them in different ways. Some charts take one `image` string. Many take `image.repository` and `image.tag` as two fields. The marker suffix decides which part of the policy's choice a line receives:

| Marker suffix | Writes | Fits a field such as |
| --- | --- | --- |
| none | `name:tag` | `image: ghcr.io/stefanprodan/podinfo:6.14.0` |
| `:name` | the name | `repository:` |
| `:tag` | the tag | `tag:` |
| `:digest` | the digest | `digest:` |

The marker is a comment at the end of the line, and its JSON object has one key, `$imagepolicy`. The value is `<namespace>:<name>` of the policy, plus the suffix. The controller reads the marker, takes the policy's `.status.latestRef`, and writes the part that the suffix names.

## Mark a values file

The playground has no Helm chart, and that does not matter here. The controller edits any YAML file under `update.path`, whether or not anything applies it. The commands below need your clone of `gitops/fleet` and the port-forward to Gitea in a second terminal.

<!-- astrona:playground:renew -->

```sh
kubectl -n gitea port-forward svc/gitea-http 3000:3000
```

In your first terminal, clone the repository:

```sh
git clone http://gitops:gitops-password@gitea.localtest.me:3000/gitops/fleet.git
cd fleet
```

Save this as `apps/podinfo/values.yaml`:

```yaml
image:
  repository: ghcr.io/stefanprodan/podinfo # {"$imagepolicy": "flux-system:podinfo:name"}
  tag: 6.13.0 # {"$imagepolicy": "flux-system:podinfo:tag"}
```

Kustomize ignores this file, because `kustomization.yaml` does not list it. The automation reads it, because it is under `./apps/podinfo`. Commit, push and run the loop:

```sh
git add apps/podinfo/values.yaml
git commit -m "Add a values file with setter markers"
git push
flux reconcile kustomization fleet --with-source
flux reconcile image update podinfo
git pull
cat apps/podinfo/values.yaml
```

The file now says `6.14.0` for the tag. The `repository` line changed too: it holds `registry.localtest.me:5000/podinfo`, the name the policy scans. That is the result of the `:name` marker, and it shows the rule: the controller writes the name of the image that the `ImageRepository` scans, not the name your cluster pulls from.

## Why the registry name matters

A scan and a pull usually use the same registry, so `:name` and the full marker work. In this lab they differ on purpose. When they differ, mark only the tag, as the Kustomize file does, and leave the name fixed. When they are the same, the full marker on an `image:` field is the shortest choice.

## The same markers in a HelmRelease

A `HelmRelease` object holds values in `spec.values`. The markers go on the same kind of fields:

```yaml
spec:
  values:
    image:
      repository: ghcr.io/stefanprodan/podinfo # {"$imagepolicy": "flux-system:podinfo:name"}
      tag: 6.14.0 # {"$imagepolicy": "flux-system:podinfo:tag"}
```

The helm-controller, one of the default Flux controllers, renders the chart with the new values and upgrades the release after the commit. The release loop is the same: the automation commits, the `GitRepository` fetches, and the helm-controller applies.

You can now mark any field that holds a name or a tag. The next question is what happens when a tag is not enough, because the same tag may point at a different image tomorrow.

## Common pitfalls

> [!WARNING]
> - **A `:name` marker on a registry that differs from the pull registry.** The controller writes the scan registry's name, and the cluster pulls from the wrong place.
> - **A marker on a line that holds more than one value.** Put the marker on the line of the field that it must change.
> - **Expecting Kustomize to apply the values file.** Only the files that `kustomization.yaml` lists are built.
> - **A policy name without the namespace.** The marker needs `<namespace>:<name>`.

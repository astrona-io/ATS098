# Marking Fields With Setter Markers

A repository holds hundreds of lines that look like an image tag. If a controller changed every one of them each time a policy moved, it would break things it was never meant to touch. So Flux does the opposite: it changes nothing until you mark a line, and the mark says exactly which policy owns that line. This part explains the mark, the setter marker, and puts one on podinfo's tag.

## A policy moves, and nothing else does

Start with the problem you are about to solve. Copy podinfo `6.14.1` into the lab registry; the helper copies the upstream image under the same tag:

<!-- astrona:playground:renew -->

```sh
push_podinfo_tag() {
  # push_podinfo_tag TAG: copies podinfo TAG from ghcr.io into the lab registry.
  kubectl -n registry exec deploy/registry-tools -- \
    regctl image copy "ghcr.io/stefanprodan/podinfo:$1" "registry.localtest.me:5000/podinfo:$1"
}
push_podinfo_tag 6.14.1
```

Then make the image reflector controller scan now, and compare the policy with the running Deployment:

```sh
flux reconcile image repository podinfo
flux get image policy podinfo
kubectl -n podinfo get deployment podinfo -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

The policy chooses `6.14.1`, and the Deployment runs `ghcr.io/stefanprodan/podinfo:6.14.0`. The choice is real, but it lives only in the policy's status. The cluster follows Git, and no line in Git refers to the policy.

## What a setter marker is

A setter marker is a YAML comment at the end of a line. It holds a small JSON object with one key, `$imagepolicy`, whose value names a policy as `<namespace>:<name>`. The image automation controller reads the marker and replaces the value on that line with what the policy chose. There are four forms, and the suffix says which part of the image reference goes on the line:

| Marker | Writes | Use it on |
| --- | --- | --- |
| `# {"$imagepolicy": "flux-system:podinfo"}` | The full reference, `registry/name:tag` | An `image:` field in a Deployment |
| `# {"$imagepolicy": "flux-system:podinfo:name"}` | The image name only | A `repository:` field, for example in Helm values |
| `# {"$imagepolicy": "flux-system:podinfo:tag"}` | The tag only | A `tag:` or `newTag:` field |
| `# {"$imagepolicy": "flux-system:podinfo:digest"}` | The digest only | A `digest:` field; needs `digestReflectionPolicy` on the policy |

The full form on a Deployment would be wrong here. The policy scans `registry.localtest.me:5000/podinfo`, so the full form would write that name into the Deployment, and the cluster cannot pull from the lab registry. The cluster pulls from `ghcr.io/stefanprodan/podinfo`. Only the tag must change, and in this repository the tag lives in the Kustomize file `kustomization.yaml`, in `images[].newTag`. Kustomize, the tool Flux uses to build the folder, replaces the tag of every image with that name when it builds `apps/podinfo`.

## Mark the tag

Clone the repository. The port-forward to Gitea must run in a second terminal (`kubectl -n gitea port-forward svc/gitea-http 3000:3000`), and the user `gitops` with the password `gitops-password` exists only in this lab. If `gitea.localtest.me` does not resolve, add `127.0.0.1 gitea.localtest.me` to `/etc/hosts`.

```sh
git clone http://gitops:gitops-password@gitea.localtest.me:3000/gitops/fleet.git
cd fleet
```

Change `apps/podinfo/kustomization.yaml` so the whole file reads:

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

The marker sits on the `newTag` line, names the policy `podinfo` in `flux-system`, and asks for the tag only. Commit and push it:

```sh
git commit -am "Mark the podinfo tag for image automation"
git push
```

Then check the cluster again:

```sh
flux reconcile kustomization podinfo --with-source
kubectl -n podinfo get deployment podinfo -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

Nothing changed: podinfo still runs `6.14.0`. A YAML comment means nothing to Kubernetes or to Kustomize, and no controller is yet told to look for markers. That is the safety property of setters: a marker is inert until an `ImageUpdateAutomation` covers its file.

You now know how to tell Flux which line belongs to which policy, and why the tag-only form fits a repository that pulls from a different registry than it scans. The marker is in place and the policy has chosen `6.14.1`. What is missing is the controller that reads the marker and commits.

## Common pitfalls

> [!WARNING]
> - **The full form where only the tag should change.** It writes the scanned registry's name into the line, and the cluster then pulls from the wrong place.
> - **A typo in the policy name or namespace.** The marker names a policy that does not exist, and the automation silently leaves the line alone.
> - **The marker on its own line.** It must be a comment at the end of the line it changes.
> - **Single quotes or missing quotes inside the marker.** The comment is JSON: double quotes around the key and the value.
> - **Expecting the marker to change the cluster.** Only an `ImageUpdateAutomation` acts on markers, and it only changes Git.

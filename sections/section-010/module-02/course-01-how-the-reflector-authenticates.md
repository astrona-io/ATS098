# How The Reflector Authenticates

A scan that fails is the best way to learn how authentication works, because the failure shows each step. This part commits an `ImageRepository` for the private registry with no credentials, reads the error, and then looks at the request itself. Once you know which request the registry rejects, every later field of the `ImageRepository` has a clear job.

## What a registry asks for

A container registry is a server that stores container images and answers a standard HTTP interface. To list the tags of an image, a client sends `GET /v2/<repository>/tags/list`. A public registry answers with the list. A private registry answers `401 Unauthorized` and adds a `WWW-Authenticate` header that says how to authenticate.

There are two common answers. A registry with basic authentication asks for a user name and a password sent with the request. A registry with token authentication names an authorization service: the client logs in there, receives a short-lived token and sends the token with the request. The private registry in your playground uses basic authentication.

The image reflector controller is the client. It reads the credentials from the `ImageRepository` fields, answers the challenge, and then lists the tags. When it has no credentials, it sends the request without them and records the `401` as the result.

```mermaid
flowchart LR
    C["image-reflector-controller"] -->|"GET tags/list"| R["private registry"]
    R -->|"401 + WWW-Authenticate"| C
    C -->|"GET with credentials"| R
    R -->|"200 + tag list"| C
```

The diagram shows the controller asking, receiving the challenge, and asking again with credentials.

## See the failure

Start the port-forward to Gitea in a second terminal and leave it running:

<!-- astrona:playground:renew -->

```sh
kubectl -n gitea port-forward svc/gitea-http 3000:3000
```

Back in your first terminal, clone the repository. The user `gitops` with the password `gitops-password` exists only in this lab. If `gitea.localtest.me` does not resolve, add `127.0.0.1 gitea.localtest.me` to `/etc/hosts` and try again.

```sh
git clone http://gitops:gitops-password@gitea.localtest.me:3000/gitops/fleet.git
cd fleet
```

Save this as `clusters/kind/image-private.yaml` in your clone:

```yaml
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImageRepository
metadata:
  name: private
  namespace: flux-system
spec:
  image: registry-private.registry.svc.cluster.local:5000/podinfo
  interval: 1m
  # The private registry has no TLS. A real registry uses HTTPS.
  insecure: true
```

The `image` field holds the registry address and the repository, with no scheme and no tag. `insecure: true` allows plain HTTP, which is true only for this lab. Commit and push it, then make Flux apply it and read the result:

```sh
git add clusters/kind/image-private.yaml
git commit -m "Scan the private registry"
git push
flux reconcile kustomization fleet --with-source
flux get image repository private
```

The `READY` column shows `False`. The message says that the registry answered `401` and that the request was unauthorized. The controller found no tag, so `tagCount` does not exist in the status yet. The `ImageRepository` itself is correct; only the proof of identity is missing.

## Send the request yourself

You can send the same request that the controller sends. The `tester` pod in the namespace `gitea` has `curl`:

```sh
kubectl -n gitea exec deploy/tester -- \
  curl -si http://registry-private.registry.svc.cluster.local:5000/v2/podinfo/tags/list
```

The first line of the answer is the `401` status, and the `WWW-Authenticate` header names the scheme `Basic` and the realm of the registry, which is the name of the protected area. Now add the credentials with the `-u` option:

```sh
kubectl -n gitea exec deploy/tester -- \
  curl -s -u scanner:scanner-password http://registry-private.registry.svc.cluster.local:5000/v2/podinfo/tags/list
```

The registry answers with a JSON object that holds the image name and the three tags. The controller needs exactly this: the same user name and password, delivered in a form it can read from the cluster.

## Where the controller looks for credentials

The `ImageRepository` can name credentials in four ways:

| Field | What it holds |
| --- | --- |
| `secretRef` | The name of a Secret with a registry login |
| `serviceAccountName` | The name of a `ServiceAccount` whose image pull secrets hold the login |
| `provider` | A cloud name (`aws`, `azure`, `gcp`) so the controller uses the identity of the cloud |
| none of them | No credentials: anonymous access |

Anonymous access is the default, which is why the lab registry works with no fields at all. Every field names an object or a setting in the namespace of the `ImageRepository`, and the controller reads it when it scans, so a change to the Secret is used from the next scan.

You now know what the registry rejects and what the controller needs. The failing `ImageRepository` stays in the cluster, because the Secret that fixes it is created next.

## Common pitfalls

> [!WARNING]
> - **Writing credentials into the `image` field.** A value such as `scanner:scanner-password@registry-private...` is not an image name. Credentials go in a Secret.
> - **Reading `Ready: False` as a broken controller.** The message holds the registry's answer. Read it before you change anything.
> - **Testing from your own machine.** The registry address `registry-private.registry.svc.cluster.local` exists only inside the cluster, so run test requests from a pod.
> - **Expecting anonymous access to a private registry.** Without a credential field, the controller sends no login, and the registry rejects the request.

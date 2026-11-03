# Service Accounts And Shared Credentials

The `secretRef` field works well for one `ImageRepository`. In a cluster with several teams, a single Secret named in every object is hard to manage. Kubernetes already has an object that bundles credentials for pulling images: the `ServiceAccount`. This part uses a `ServiceAccount` for the registry login, and then looks at a second question: which namespaces may use an `ImageRepository` that another namespace owns.

## Image pull secrets on a ServiceAccount

A `ServiceAccount` is the identity that a workload uses inside the cluster. A `ServiceAccount` can list Secrets of type `kubernetes.io/dockerconfigjson` in its `imagePullSecrets` field. Kubernetes uses those Secrets when a pod that runs as that `ServiceAccount` pulls an image.

The `serviceAccountName` field of an `ImageRepository` reuses the same idea. The image reflector controller reads the `ServiceAccount` of that name in the namespace of the `ImageRepository`, finds its image pull secrets, and uses them as the login for the scan. The `ImageRepository` then needs no `secretRef`.

The advantage is that one `ServiceAccount` is the single place where a team's registry logins are listed. Adding a registry means adding one Secret to the list, not editing every `ImageRepository`.

## Use a ServiceAccount for the scan

The Secret `private-registry-auth` must exist in `flux-system`; create it with `kubectl create secret docker-registry` if you removed it. Save this as `clusters/kind/serviceaccount-registry-reader.yaml` in your clone:

<!-- astrona:playground:renew -->

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: registry-reader
  namespace: flux-system
imagePullSecrets:
  - name: private-registry-auth
```

The file holds only the name of the Secret, so it is safe in Git. Now save a second `ImageRepository` as `clusters/kind/image-private-sa.yaml`. It scans the same image as before, and it names the `ServiceAccount` instead of the Secret:

```yaml
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImageRepository
metadata:
  name: private-sa
  namespace: flux-system
spec:
  image: registry-private.registry.svc.cluster.local:5000/podinfo
  interval: 1m
  # The private registry has no TLS. A real registry uses HTTPS.
  insecure: true
  serviceAccountName: registry-reader
```

Commit, push, and read both scans:

```sh
git add clusters/kind/serviceaccount-registry-reader.yaml clusters/kind/image-private-sa.yaml
git commit -m "Scan the private registry with a ServiceAccount"
git push
flux reconcile kustomization fleet --with-source
flux reconcile image repository private-sa
flux get image repository
```

Both `private` and `private-sa` are `Ready` with three tags. The first uses the Secret directly, and the second reaches the same Secret through the `ServiceAccount`.

## Who may use an ImageRepository

An `ImagePolicy` normally points at an `ImageRepository` in its own namespace. A policy can also name another namespace with `imageRepositoryRef.namespace`. That would let any team read a scan that another team paid for with its credentials, so Flux refuses by default.

The owner of the `ImageRepository` opens it with `accessFrom`. The field holds a list of namespace selectors, and a namespace may reference the `ImageRepository` when its labels match one selector. Create a namespace with a label, and open the `ImageRepository` `private` to it. Save this as `clusters/kind/team-a.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: team-a
  labels:
    registry-access: private
---
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImagePolicy
metadata:
  name: podinfo
  namespace: team-a
spec:
  imageRepositoryRef:
    name: private
    namespace: flux-system
  policy:
    semver:
      range: '6.x'
```

Commit it and read the policy before the `ImageRepository` allows the namespace:

```sh
git add clusters/kind/team-a.yaml
git commit -m "Add a policy in team-a"
git push
flux reconcile kustomization fleet --with-source
flux get image policy --namespace team-a
```

The policy is not `Ready`, and its message says that the reference to the `ImageRepository` in `flux-system` is not allowed. Now change `clusters/kind/image-private.yaml` so the `ImageRepository` `private` accepts namespaces with the label:

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
  secretRef:
    name: private-registry-auth
  accessFrom:
    namespaceSelectors:
      - matchLabels:
          registry-access: private
```

Apply it and check again:

```sh
git commit -am "Allow namespaces labelled registry-access=private"
git push
flux reconcile kustomization fleet --with-source
flux reconcile image policy podinfo --namespace team-a
flux get image policy --namespace team-a
```

The policy in `team-a` is `Ready` and chooses `6.15.0`. The Secret stayed in `flux-system`: the team never saw the password, only the scan result.

You now have two ways to hand the controller a login, and a rule for who may read a scan. Both assume a registry with a user name and a password. Cloud registries, private certificate authorities and proxies each need something different.

## Common pitfalls

> [!WARNING]
> - **A `ServiceAccount` without `imagePullSecrets`.** The scan then has no login. The `ServiceAccount` must exist in the namespace of the `ImageRepository`.
> - **A pull secret in another namespace.** `imagePullSecrets` names a Secret in the same namespace as the `ServiceAccount`.
> - **Opening `accessFrom` to every namespace.** A selector with no labels matches all namespaces. Use a label that only the intended teams carry.
> - **Forgetting the label on the namespace.** The selector reads labels of the namespace, not of the policy.

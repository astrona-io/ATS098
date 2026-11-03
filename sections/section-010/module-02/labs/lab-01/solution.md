# Solution: Scan A Private Registry

Work the task yourself first. Running `astrona submit -c sections/section-010/module-02/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks two things: the `ImageRepository` `podinfo` comes from Git, names a Secret of type `kubernetes.io/dockerconfigjson` and finds the three tags; and after it adds `6.15.1` to the private registry, the policy chooses `6.15.1`.

## Step 1: Read the first error

```sh
flux get image repository podinfo
kubectl -n flux-system describe imagerepository podinfo
```

The object is not `Ready`. The message says the registry answered over HTTP while the controller expected HTTPS. The private registry has no TLS, so the `ImageRepository` needs `insecure: true`. That is the first cause. It hides the second one, because the scan never reaches the point where the registry asks for credentials.

## Step 2: Create the Secret

The password goes into a Secret in the namespace `flux-system`, not into Git. A Secret of type `kubernetes.io/dockerconfigjson` holds registry credentials in the format that container tools use:

```sh
kubectl -n flux-system create secret docker-registry private-registry-auth \
  --docker-server=registry-private.registry.svc.cluster.local:5000 \
  --docker-username=scanner \
  --docker-password=scanner-password
```

The `--docker-server` value must be the registry address exactly as it is written in the `image` field of the `ImageRepository`, with the port and without a scheme.

## Step 3: Change the ImageRepository in Git

Start the port-forward in a second terminal if it is not running, then clone the repository:

```sh
git clone http://gitops:gitops-password@gitea.localtest.me:3000/gitops/fleet.git
cd fleet
```

Change the `ImageRepository` in `clusters/kind/image-podinfo.yaml` so it reads:

```yaml
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImageRepository
metadata:
  name: podinfo
  namespace: flux-system
spec:
  image: registry-private.registry.svc.cluster.local:5000/podinfo
  interval: 1m
  # The private registry has no TLS. A real registry uses HTTPS.
  insecure: true
  secretRef:
    name: private-registry-auth
```

Leave the `ImagePolicy` in the same file as it is. Commit and push:

```sh
git commit -am "Scan the private registry with credentials"
git push
```

## Step 4: Make Flux apply it and check

```sh
flux reconcile kustomization fleet --with-source
flux reconcile image repository podinfo
flux get image repository podinfo
flux get image policy podinfo
```

The scan is `Ready` and found three tags. The policy chooses `6.15.0`.

## Step 5: Prove it follows the next release

Add the tag the grader will add, and scan again:

```sh
kubectl -n registry exec deploy/registry-tools -- \
  regctl image copy registry-private.registry.svc.cluster.local:5000/podinfo:6.15.0 \
  registry-private.registry.svc.cluster.local:5000/podinfo:6.15.1
flux reconcile image repository podinfo
flux get image policy podinfo
```

The policy moves to `6.15.1`.

## Step 6: Submit

```sh
astrona submit -c sections/section-010/module-02/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Write the password into the `ImageRepository` or a file in Git | The `ImageRepository` has no password field, and a password in Git is readable by everyone with access to the repository |
| `kubectl edit imagerepository podinfo` | The grader makes Flux apply Git first, and Git has no `secretRef` |
| A Secret in another namespace | The `secretRef` is read from the namespace of the `ImageRepository` only |
| A Secret with `--docker-server` set to `http://...` | The controller looks up the credentials by host, so the key does not match |

## Practice on your own

- Delete the Secret and read how the status of the `ImageRepository` changes.
- Create the Secret with a wrong password and compare the error with the missing Secret.
- Move the credentials into a `ServiceAccount` with `imagePullSecrets` and use `serviceAccountName` instead of `secretRef`.

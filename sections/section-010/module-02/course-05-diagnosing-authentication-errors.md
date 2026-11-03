# Diagnosing Authentication Errors

A failed scan always has a cause that can be found in a few minutes, if you read the right place first. This part gives a method and then breaks the working setup on purpose, one fault at a time, so you see what each fault looks like. The goal is to read the message and know which field to change.

## The method

Work from the symptom to the cause in four steps. First, read the status line with `flux get image repository`. Second, read the full condition and the recent events, which hold the complete message. Third, repeat the request by hand from a pod with the same credentials, to learn whether the registry or the object is wrong. Fourth, change one thing in Git and scan again.

The commands for the first two steps are these:

<!-- astrona:playground:renew -->

```sh
flux get image repository private
kubectl -n flux-system describe imagerepository private
flux events --for ImageRepository/private
```

The `describe` output lists the conditions: `Ready` is `True` or `False`, and the message explains why. The `flux events` command lists the Kubernetes events of the object, newest last. The third step uses `regctl`, the registry command-line tool in the pod `registry-tools`, which is already logged in to the private registry:

```sh
kubectl -n registry exec deploy/registry-tools -- \
  regctl tag ls registry-private.registry.svc.cluster.local:5000/podinfo
```

If this command prints the tags, the registry and the login are fine, and the fault is in the object or the Secret. If it fails, the fault is in the registry or the login.

## Fault one: the Secret does not exist

Delete the Secret and scan again:

```sh
kubectl -n flux-system delete secret private-registry-auth
flux reconcile image repository private
flux get image repository private
```

The `ImageRepository` is `Ready: False`, and the message says that the Secret `private-registry-auth` was not found. The message names the object, so the fix is clear: create the Secret in `flux-system` with the same name. Create it again with the correct password:

```sh
kubectl -n flux-system create secret docker-registry private-registry-auth \
  --docker-server=registry-private.registry.svc.cluster.local:5000 \
  --docker-username=scanner \
  --docker-password=scanner-password
flux reconcile image repository private
```

## Fault two: the password is wrong

Replace the Secret with one that holds a wrong password. A tool that creates objects with `kubectl apply` replaces an existing Secret when you pipe a dry run into it:

```sh
kubectl -n flux-system create secret docker-registry private-registry-auth \
  --docker-server=registry-private.registry.svc.cluster.local:5000 \
  --docker-username=scanner \
  --docker-password=wrong-password \
  --dry-run=client -o yaml | kubectl apply -f -
flux reconcile image repository private
flux get image repository private
```

The Secret exists and has the right type, but the message now reports `401 Unauthorized` again. A missing Secret and a wrong password give different messages, which is the quickest way to tell them apart: a missing Secret names the Secret, and a wrong password names the registry's answer. Repeat the request with `curl -u scanner:wrong-password` from the `tester` pod to confirm that the registry itself rejects the password. Then put the correct one back with the same command and `scanner-password`.

## Fault three: the host in the Secret does not match

Create the Secret with a server value that has no port:

```sh
kubectl -n flux-system create secret docker-registry private-registry-auth \
  --docker-server=registry-private.registry.svc.cluster.local \
  --docker-username=scanner \
  --docker-password=scanner-password \
  --dry-run=client -o yaml | kubectl apply -f -
flux reconcile image repository private
flux get image repository private
```

The password is right and the Secret exists, but the scan fails with `401` again. The controller looks up the login by the registry host of the `image` field, `registry-private.registry.svc.cluster.local:5000`, and finds no entry for it, so it sends no credentials. When the message is a `401` and the password is correct, compare the address in the Secret with the address in `image`. Restore the Secret with the port.

## Fault four: TLS and HTTP do not match

Remove `insecure: true` from `clusters/kind/image-private.yaml`, push it, and scan:

```sh
git commit -am "Remove insecure"
git push
flux reconcile kustomization fleet --with-source
flux reconcile image repository private
flux get image repository private
```

The message now says that the server gave an HTTP response to an HTTPS client. The controller used HTTPS because the object said nothing else, and the registry speaks plain HTTP. For a registry with real HTTPS the same field is not the answer: the message there names an unknown certificate authority, and the field to change is `certSecretRef`. Put `insecure: true` back and push.

## A table to keep

| What the message says | What is wrong | Where to fix it |
| --- | --- | --- |
| A Secret is not found | The `secretRef` name or the namespace | Create the Secret, or correct the name |
| `401 Unauthorized`, Secret exists | Wrong password, or address mismatch | Recreate the Secret, check the host with the port |
| `403 Forbidden` or `denied` | The login is valid but may not read this repository | Grant the account read access in the registry |
| HTTP response to an HTTPS client | The registry has no TLS | `insecure: true`, for a lab registry only |
| Certificate signed by an unknown authority | A private CA | `certSecretRef` with `ca.crt` |
| Connection refused or timeout | The address, the port or a proxy | Check `image`, the network path and `proxySecretRef` |

Each row names one field to change and one place to look. You can now take a failed scan, read it, repeat the request by hand and change exactly one thing in Git. The same method works for any `ImageRepository`, whatever the registry.

## Common pitfalls

> [!WARNING]
> - **Changing three things at once.** Change one field, scan, and read the message. Otherwise you cannot tell which change worked.
> - **Waiting for the interval.** A fix is only tested at the next scan. Run `flux reconcile image repository` after each change.
> - **Fixing the Secret in the cluster and the `ImageRepository` in the cluster too.** The `ImageRepository` comes from Git, so a change made with `kubectl` is undone at the next sync. Only the Secret lives outside Git.
> - **Trusting an old message.** A condition shows the result of the last scan. Check the scan time in the status before you read it.

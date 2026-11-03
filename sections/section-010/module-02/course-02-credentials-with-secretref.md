# Credentials With secretRef

The scan of the private registry fails with `401`, and the registry accepts the user `scanner`. What is missing is a place for the password. In Flux, that place is a Secret in the cluster, and the `ImageRepository` points at it with `secretRef`. This part creates the Secret, connects it, and explains why the password never goes into Git.

## The Secret format

A registry login is stored in a Secret of type `kubernetes.io/dockerconfigjson`. The Secret has one key, `.dockerconfigjson`, and its value is a JSON document in the format of the Docker client configuration file. The document maps a registry address to a user name and a password. The same format is used by Kubernetes for pulling images, so the tools that create it are the same.

The address in the document is how the controller finds the login. It compares the registry host of the `image` field with the addresses in the document, so the address must match, with the port and without a scheme.

## Create the Secret with kubectl

`kubectl create secret docker-registry` builds the document for you. Run it in the namespace of the `ImageRepository`, `flux-system`:

<!-- astrona:playground:renew -->

```sh
kubectl -n flux-system create secret docker-registry private-registry-auth \
  --docker-server=registry-private.registry.svc.cluster.local:5000 \
  --docker-username=scanner \
  --docker-password=scanner-password
```

Check the type and the key without printing the password:

```sh
kubectl -n flux-system get secret private-registry-auth -o jsonpath='{.type}{"\n"}'
kubectl -n flux-system get secret private-registry-auth -o jsonpath='{.data}' | jq 'keys'
```

The type is `kubernetes.io/dockerconfigjson` and the only key is `.dockerconfigjson`. The Flux command-line tool creates the same Secret with `flux create secret oci`. This command only prints the object because of `--export`, so you can compare the two without changing the cluster:

```sh
flux create secret oci private-registry-auth \
  --url=registry-private.registry.svc.cluster.local:5000 \
  --username=scanner --password=scanner-password \
  --export
```

The output is a Secret with the same type and key. Use whichever tool you prefer.

## Connect the Secret with secretRef

Change `clusters/kind/image-private.yaml` in your clone so it names the Secret:

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
```

Commit, push and scan again:

```sh
git commit -am "Use credentials for the private registry"
git push
flux reconcile kustomization fleet --with-source
flux reconcile image repository private
flux get image repository private
```

The object is `Ready` and the message says it found three tags. The status shows the same fields as for any registry: `tagCount` is `3`, and `latestTags` lists them.

## Why the Secret stays out of Git

The `ImageRepository` is in Git, and the Secret is not. A password in a Git repository is readable by everyone who can read the repository, and it stays in the history after a later commit removes it. The `secretRef` holds only the name of the Secret, which is not sensitive.

That leaves the question of how the Secret gets into every cluster. Teams answer it in one of three ways: an administrator creates it with `kubectl` or `flux create secret`, an external secret tool copies it from a vault, or the Secret is committed in an encrypted form that the cluster decrypts. Flux supports the last way with SOPS (Secrets OPerationS), where the Kustomization decrypts the file. The `ImageRepository` does not care which way you pick: it reads a Secret with that name from its own namespace.

## One Secret for many registries

The document in `.dockerconfigjson` can hold several registries. If your images come from two registries, one Secret can hold both logins, and two `ImageRepository` objects can name it. The controller picks the entry that matches the host of each `image`.

You can now scan a registry that needs a login, and you know where the password lives. The next question is who may use the credentials. A Secret named by `secretRef` is tied to one namespace, and larger setups give every team a `ServiceAccount` instead.

## Common pitfalls

> [!WARNING]
> - **Creating the Secret in another namespace.** The `secretRef` is read from the namespace of the `ImageRepository`. A Secret in `default` is never found.
> - **A `--docker-server` that does not match the `image` field.** `http://registry-private...` or a missing port gives a Secret that the controller cannot match to the host.
> - **A Secret of type `Opaque` with the JSON inside.** The type must be `kubernetes.io/dockerconfigjson` and the key must be `.dockerconfigjson`.
> - **Committing the Secret as plain YAML.** The base64 text of a Secret is not encrypted. Anyone can decode it.
> - **Expecting the next scan to be instant.** A new Secret is read at the next scan. Run `flux reconcile image repository` to scan now.

## Your mission: Scan A Private Registry

You can now connect a registry login to an `ImageRepository` without putting the password into Git. The graded lab gives you an `ImageRepository` in Git that cannot scan the private registry, for more than one reason, and asks you to fix it so the policy follows the tags of that registry.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-098-playground-010-02
```

Then start the lab:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS098.git -c sections/section-010/module-02/labs/lab-01
```

The task is on the next page. Solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-010/module-02/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-098-lab-010-02
astrona start ats-098-playground-010-02
```

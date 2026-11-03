# Cloud Registries, TLS And Proxies

A registry password is the simplest login. Production registries often use something else: a cloud account that issues short-lived tokens, a certificate authority that only your company trusts, or a network that only allows traffic through a proxy. This part covers the three fields that handle those cases: `provider`, `certSecretRef` and `proxySecretRef`.

The registry in the playground has no TLS and no cloud account, so the objects in this part are shown for you to read and are not applied. The Secrets are printed with `--dry-run=client`, which builds the object and prints it without sending it to the cluster.

## Cloud providers

A cloud registry such as Amazon Elastic Container Registry (ECR), Azure Container Registry (ACR) or Google Artifact Registry does not give out a permanent password. A client asks the cloud for a token that is valid for a few hours. The `provider` field tells the controller which cloud to ask:

| Value | Registry | Where the controller gets its identity |
| --- | --- | --- |
| `generic` | Any registry (the default) | From `secretRef` or `serviceAccountName`, or none |
| `aws` | ECR | From the AWS identity of the controller pod, for example an IAM role for the service account |
| `azure` | ACR | From the Azure identity of the controller pod, for example workload identity |
| `gcp` | Artifact Registry and Container Registry | From the Google identity of the controller pod, for example workload identity |

With a cloud value, no password is stored in the cluster. The cloud account is granted read access to the registry, the controller pod gets the cloud identity through the cluster configuration, and the controller requests a fresh token for each scan. The token is not kept in a Secret you manage.

A scan of an ECR repository looks like this. It is not applied here:

```yaml
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImageRepository
metadata:
  name: podinfo-ecr
  namespace: flux-system
spec:
  image: 123456789012.dkr.ecr.eu-west-1.amazonaws.com/podinfo
  interval: 5m
  provider: aws
```

For Azure the image is `myregistry.azurecr.io/podinfo` with `provider: azure`, and for Google the image is `europe-docker.pkg.dev/my-project/my-repository/podinfo` with `provider: gcp`. The `interval` can be longer for a cloud registry, because every scan asks the cloud for a token and the registry for a list.

## A private certificate authority

A registry that uses HTTPS presents a certificate. The controller accepts it only if a certificate authority (CA) that it trusts signed it. A company registry is often signed by a private CA that the controller does not know, and the scan fails with a message about an unknown authority.

The `certSecretRef` field names a Secret with the extra certificates. The key `ca.crt` holds the CA certificate in PEM format, a text format that starts with `-----BEGIN CERTIFICATE-----`. The keys `tls.crt` and `tls.key` hold a client certificate and its private key, for registries that require mutual TLS (mTLS), where the client proves its identity with a certificate too.

Create a certificate for the practice. It is valid for one day and is used for nothing else:

<!-- astrona:playground:renew -->

```sh
openssl req -x509 -newkey rsa:2048 -nodes -days 1 \
  -keyout ca.key -out ca.crt -subj "/CN=lab-registry-ca"
```

Print the Secret that would carry it:

```sh
kubectl -n flux-system create secret generic registry-ca \
  --from-file=ca.crt=ca.crt \
  --dry-run=client -o yaml
```

The output shows a Secret of type `Opaque` with one key, `ca.crt`, that holds the certificate in base64. For mTLS you add `--from-file=tls.crt=client.crt --from-file=tls.key=client.key`. The `ImageRepository` then names the Secret:

```yaml
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImageRepository
metadata:
  name: podinfo-internal
  namespace: flux-system
spec:
  image: registry.internal.example.com/team/podinfo
  interval: 5m
  secretRef:
    name: private-registry-auth
  certSecretRef:
    name: registry-ca
```

The two Secrets do different jobs: `secretRef` is the login, and `certSecretRef` is what the controller trusts. A registry that uses both a password and a private CA needs both fields. Do not use `insecure: true` to get around an unknown CA; that field switches HTTPS off, it does not skip the check.

## A proxy

In a network that only allows outgoing traffic through a proxy, the controller cannot reach the registry directly. The `proxySecretRef` field names a Secret with the proxy address. The key `address` is required and holds the proxy URL. The keys `username` and `password` are optional, for a proxy that asks for a login.

Print the Secret for a proxy at an example address:

```sh
kubectl -n flux-system create secret generic registry-proxy \
  --from-literal=address=http://proxy.example.com:3128 \
  --from-literal=username=flux \
  --from-literal=password=example-password \
  --dry-run=client -o yaml
```

The `ImageRepository` adds `proxySecretRef` with `name: registry-proxy`. The proxy address lives in a Secret and not in the `ImageRepository` because it can contain a password. Only the scan of this one `ImageRepository` goes through the proxy; the other Flux controllers keep their own proxy settings.

You can now choose the right field for each kind of registry: a Secret for a password, a `ServiceAccount` for a team, `provider` for a cloud, `certSecretRef` for a private CA and `proxySecretRef` for a proxy. The last skill is to find which field is wrong from the error that a scan reports.

## Common pitfalls

> [!WARNING]
> - **Using `insecure: true` for a private CA.** The field means plain HTTP. A private CA needs `certSecretRef`.
> - **Putting the CA in `secretRef`.** `secretRef` holds a registry login. The CA belongs in `certSecretRef` under the key `ca.crt`.
> - **A proxy address without a scheme.** Write `http://proxy.example.com:3128`, not `proxy.example.com:3128`.
> - **Setting `provider: aws` and expecting a password to be used.** With a cloud provider the identity of the controller pod is used. Check the role of the pod, not a Secret.
> - **Leaving `ca.key` or other key files in your working directory.** The private key of a certificate is a secret too. Delete practice keys when you finish.

# Summary

A private registry answers a request without credentials with `401 Unauthorized` and a header that says how to log in. The image reflector controller, the Flux controller that reads registries, answers that challenge with the login named in the `ImageRepository`. Without a login it sends the request anonymously, and the scan fails.

## What you learned

The `secretRef` field names a Secret of type `kubernetes.io/dockerconfigjson` in the namespace of the `ImageRepository`. The Secret holds the registry address, a user name and a password, and the controller finds the login by comparing the registry host of the `image` field, with its port, to the address in the Secret. The password stays in the cluster. Git holds the `ImageRepository` and only the name of the Secret, because a password in a repository is readable by everyone and stays in the history.

The `serviceAccountName` field uses the image pull secrets of a `ServiceAccount` instead, so one object lists the logins of a team. The `accessFrom` field opens an `ImageRepository` to other namespaces by label. Without it, a policy in another namespace is not allowed to use the scan.

Registries that are not a simple password use other fields. The `provider` field `aws`, `azure` or `gcp` makes the controller use the cloud identity of its pod to obtain a short-lived token. The `certSecretRef` field holds a certificate authority in the key `ca.crt`, and a client certificate in `tls.crt` and `tls.key` for mutual TLS. The `proxySecretRef` field holds a proxy address in the key `address`, with optional `username` and `password`. The `insecure` field switches HTTPS off for a lab registry and never replaces a private authority.

Diagnosis follows the message. A missing Secret names the Secret, a wrong password or a mismatched host gives `401`, a registry without TLS gives an HTTP response to an HTTPS client, and a private authority gives an unknown certificate error. Repeating the request by hand with `regctl` or `curl` shows whether the registry or the object is at fault. The key facts to remember are these:

- Credentials live in a Secret in the cluster, and the `ImageRepository` in Git names it.
- The Secret address must match the `image` host and port, with no scheme.
- `secretRef` and `serviceAccountName` carry passwords, `provider` carries a cloud identity, `certSecretRef` carries trust and `proxySecretRef` carries a proxy.
- Change one thing at a time and scan again after each change.

<!-- astrona:playground:destroy -->

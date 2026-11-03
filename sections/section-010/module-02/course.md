# Authenticate To A Private Registry

The lab registry from the first module lets anyone list its tags. Real registries do not. A company keeps its images in a private registry, and the registry answers every request without credentials with `401 Unauthorized`. The image reflector controller then cannot scan the image, the `ImagePolicy` has nothing to choose from, and no release ever starts.

This module teaches how the controller proves who it is. The image reflector controller is the optional Flux controller that reads container registries. An `ImageRepository` tells it where to scan and, with a few optional fields, how to authenticate. Keep one sentence in mind: **the `ImageRepository` names the credentials, and the credentials live in a Secret, never in Git.**

The module has five parts. **How The Reflector Authenticates** shows the failure first and explains the request that the controller sends. **Credentials With secretRef** creates a Secret of type `kubernetes.io/dockerconfigjson` and connects it; a graded lab follows it. **Service Accounts And Shared Credentials** moves the credentials to a `ServiceAccount` and shows who may use an `ImageRepository`. **Cloud Registries, TLS And Proxies** covers `provider`, `certSecretRef` and `proxySecretRef`. **Diagnosing Authentication Errors** reads each failure and isolates it with `regctl`.

## Learning objectives

After this module you can:

- Explain what a registry sends when credentials are missing and what the image reflector controller does next.
- Create a Secret of type `kubernetes.io/dockerconfigjson` with `kubectl` and with `flux create secret oci`.
- Connect the Secret to an `ImageRepository` with `secretRef`, and say why the Secret stays out of Git.
- Use `serviceAccountName` with image pull secrets, and limit which namespaces may use an `ImageRepository` with `accessFrom`.
- Choose between `provider: generic`, `aws`, `azure` and `gcp`.
- Give the controller a certificate authority and a client certificate with `certSecretRef`, and a proxy with `proxySecretRef`.
- Tell a missing Secret, a wrong password, a TLS error and a proxy error apart from the status message.

## Before you start

You need to know what an `ImageRepository` and an `ImagePolicy` do and how to commit a Flux object to the repository `gitops/fleet`. You need `kubectl` and `git` from the terminal. A Kubernetes Secret is an object that stores small pieces of sensitive data, such as a password; you will create several.

Your playground is a single-node `kind` cluster with **Flux 2.9.6**, including the two image controllers, and the `flux` command-line tool on your PATH. Gitea, a Git server inside the cluster, holds the repository `gitops/fleet`, and the Flux `Kustomization` named `fleet` applies every file under `clusters/kind` in it.

Two registries run in the cluster. The lab registry at `registry.localtest.me:5000` is open to everyone. The private registry at `registry-private.registry.svc.cluster.local:5000` needs the user `scanner` and the password `scanner-password`. Both use plain HTTP, and the private one holds podinfo `6.13.0`, `6.14.0` and `6.15.0`.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

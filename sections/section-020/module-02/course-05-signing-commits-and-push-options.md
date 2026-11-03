# Signing Commits And Push Options

A commit author is only a name and an email that anyone can type. On a repository where Flux decides what runs in production, a team may want proof that a commit came from the automation and not from a person who set the same name. A signature is that proof. This part signs the automation's commits with a GPG key and then changes how the commits are pushed.

## Signed commits

GPG (GNU Privacy Guard) is a tool that signs data with a private key. A Git server or a reader verifies the signature with the matching public key. When the automation signs its commits, a branch protection rule on the Git server can require a valid signature, and a commit from anyone else is refused.

The controller reads the private key from a Kubernetes Secret in the namespace of the automation. The Secret holds the key in the entry `git.asc`, in ASCII-armored form (a text encoding of the key), and, if the key has a passphrase, the passphrase in the entry `passphrase`. `spec.git.commit.signingKey.secretRef.name` names the Secret.

## Create a key and a Secret

The commands below need your clone of `gitops/fleet`, and the `gpg` command on your machine.

<!-- astrona:playground:renew -->

Create a key without a passphrase for the automation:

```sh
gpg --batch --passphrase '' --quick-generate-key 'fluxcdbot <fluxcdbot@example.com>'
```

Export the private key into a Secret:

```sh
gpg --export-secret-keys --armor fluxcdbot@example.com > git.asc
kubectl -n flux-system create secret generic signing-key --from-file=git.asc=git.asc
rm git.asc
```

The key lives in the cluster now. Keep this Secret out of Git in plain form; a real repository stores it encrypted, for example with SOPS, or creates it from a secret manager. Reference it from the automation. Add this under `spec.git.commit` in `clusters/kind/image-automation.yaml`:

```yaml
      signingKey:
        secretRef:
          name: signing-key
```

Commit, push and make the automation work on a new release:

```sh
git commit -am "Sign the commits of the automation"
git push
flux reconcile kustomization fleet --with-source
kubectl -n registry exec deploy/registry-tools -- \
  regctl image copy ghcr.io/stefanprodan/podinfo:6.15.0 registry.localtest.me:5000/podinfo:6.15.0
flux reconcile image repository podinfo
flux reconcile image update podinfo
git pull
git cat-file commit HEAD
```

The commit object now has a `gpgsig` header with a block that starts with `-----BEGIN PGP SIGNATURE-----`. Git servers show the commit as verified when they know the public key of the signer. Gitea in this lab does not know it, so it shows no verification.

## Change the push

By default the controller pushes the commit to the branch in `spec.git.push.branch`. Two more fields change the push:

- `spec.git.push.refspec` is a Git refspec, a rule that maps a local reference to a remote reference. `refs/heads/main:refs/heads/auto` pushes the commit that the controller made on `main` to the branch `auto`, and the controller never has to check out the target.
- `spec.git.push.options` is a map of push options, strings that a Git server passes to its hooks. Some servers use them to open a pull request or to skip a pipeline.

A refspec is the more precise tool when the checkout branch and the push branch must differ, because the controller works from a fresh clone of the checkout branch every time.

```yaml
    push:
      refspec: refs/heads/main:refs/heads/auto
```

With this refspec, the controller pushes its commit to the branch `auto` and not to `main`. A refspec that names a branch another writer also uses makes the history harder to read, so give the automation its own branch.

You can now sign release commits and place them where your process needs them. That completes the controls of the release loop itself.

## Common pitfalls

> [!WARNING]
> - **A `signingKey` Secret without the `git.asc` entry.** The controller cannot read the key, and the automation reports an error.
> - **A key with a passphrase and no `passphrase` entry.** The controller cannot unlock the key.
> - **A key that was never added to the Git server.** The commit is signed but shows as unverified.
> - **Committing the exported private key to Git.** Anyone with read access can sign as the automation. Store the Secret encrypted.
> - **A refspec that points at a branch with different history.** The push is rejected as a non-fast-forward.

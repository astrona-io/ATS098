# Summary

The release loop works with one marker and one fixed message, and a real repository asks for more. The image automation controller can write into any YAML file, in any form of the image reference, and it can describe and sign what it commits.

## What you learned

A setter marker names a policy as `<namespace>:<name>` and a suffix. No suffix writes the full `name:tag`, `:name` writes the image name, `:tag` writes the tag, and `:digest` writes the digest. The name that the controller writes is the one the `ImageRepository` scans. When that registry differs from the registry the cluster pulls from, only the tag may be marked. Markers work in Kustomize `images`, in Helm values files and in the `spec.values` of a `HelmRelease`.

A tag can move, and a digest cannot. `spec.digestReflectionPolicy` on an `ImagePolicy` is `Never`, `IfNotPresent` or `Always`, and `Always` needs `spec.interval`. The result is in `.status.latestRef.digest`, and one policy should supply both the tag and the digest of a release.

The `Setters` strategy is the only strategy. The controller reads the `.yaml` and `.yml` files under `update.path`, relative to the repository root, and changes only marked values. A wrong path produces a healthy automation that never commits. `flux create image update --export` prints the object, and it belongs in Git.

The commit message is a Go template. `.Changed.Changes` lists every change with `.OldValue`, `.NewValue` and `.Setter`, `.Changed.FileChanges` and `.Changed.Objects` group them, `.Values` reads `messageTemplateValues`, and `.Updated` no longer exists. A `signingKey` Secret with the entry `git.asc` makes the controller sign its commits. `push.refspec` and `push.options` change where and how the commit is pushed.

The key facts to remember are these:

- The suffix of the marker decides which part of the image reference is written.
- `digestReflectionPolicy: Always` needs an `interval`.
- An automation with a wrong `update.path` is `Ready` and never commits.
- Render the message template once after each change.
- Store the signing key Secret encrypted, never in plain form in Git.

<!-- astrona:playground:destroy -->

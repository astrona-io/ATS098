# Summary

A chosen tag only matters when it reaches Git, because Flux applies Git. The image automation controller, the second optional Flux controller for images, writes the tag there: it clones the repository, changes the lines you marked, commits and pushes. It never changes the cluster directly.

## What you learned

A setter marker is a comment at the end of a YAML line, such as `# {"$imagepolicy": "flux-system:podinfo:tag"}`. It names one `ImagePolicy` as `<namespace>:<name>`, and the suffix says what to write: nothing for the full image reference, `:name` for the image name, `:tag` for the tag and `:digest` for the digest. When the policy scans a different registry from the one the cluster pulls from, only the tag may change, so the marker goes on `images[].newTag` in the Kustomize file `kustomization.yaml` with the `:tag` suffix. A marker on its own changes nothing.

An `ImageUpdateAutomation` names the `GitRepository` to clone (`sourceRef`), the branch to check out, the folder to search for markers (`update.path`, the repository root by default), the commit author (`email` required) and message template, and the push branch. It pushes with the `GitRepository`'s credentials, so they need write access. `flux get image update` and `.status.lastPushCommit` show the last commit it pushed.

The release loop has four owners: the `ImageRepository` finds the tag, the `ImagePolicy` chooses it, the `ImageUpdateAutomation` commits it, and the `GitRepository` and Flux `Kustomization` apply it. Each step waits for its own interval. `flux reconcile image repository`, `flux reconcile image update` and `flux reconcile kustomization --with-source` run them now, in that order.

The commit message template is a Go template that can use `.AutomationObject` and `.Changed` (`FileChanges`, `Objects`, `Changes`); the old `.Updated` field is gone. Pushing to a separate branch turns each release into a change that a person merges, and Flux applies it only after the merge to `main`. The key facts to remember are these:

- The controller only changes lines with a marker, and only in Git.
- `update.path` must contain the marked file, and the push branch must be the branch Flux applies, unless a person merges.
- A hand edit to a marked value is undone by the next run; change the policy instead.
- Follow a stuck release step by step: scan, policy, commit, sync, rollout.

<!-- astrona:playground:destroy -->

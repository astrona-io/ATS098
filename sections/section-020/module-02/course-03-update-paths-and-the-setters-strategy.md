# Update Paths And The Setters Strategy

An automation that changes files in a Git repository must know which files to change. If it searched everything, a marker anywhere could trigger a commit. If it searched the wrong folder, it would never commit. The controller's rules for this are short. This part states them, creates an automation from the command line, and breaks the path on purpose to read the symptom.

## What the controller reads

The field `spec.update.strategy` is `Setters`. It is the only strategy and the default. With it, the controller walks the folder `spec.update.path`, reads every file with the extension `.yaml` or `.yml`, finds setter markers and replaces the marked values. It changes nothing else. It does not need the files to be Kubernetes objects, and it does not care whether anything applies them.

The path is relative to the root of the repository and starts with `./`. If you leave it out, the controller searches the whole repository. That works for a small repository and is slow and risky for a large one, so name the folder.

Two other fields place the work. `spec.sourceRef` points at a `GitRepository` in the cluster; the controller reuses its URL and its credentials. `spec.git.checkout.ref.branch` names the branch to clone. Without it the controller uses the branch of the `GitRepository`.

## Generate the object from the command line

The `flux` command-line tool writes the YAML for you. With `--export` it prints the object and does not create anything in the cluster:

<!-- astrona:playground:renew -->

```sh
flux create image update podinfo \
  --git-repo-ref=fleet \
  --git-repo-path=./apps/podinfo \
  --checkout-branch=main \
  --push-branch=main \
  --author-name=fluxcdbot \
  --author-email=fluxcdbot@example.com \
  --commit-template='Automated image update by {{ .AutomationObject }}' \
  --export
```

The output is an `ImageUpdateAutomation` with the same fields as `clusters/kind/image-automation.yaml`. Commit the output to Git instead of applying it, because the Flux `Kustomization` `fleet` would remove an object that only exists in the cluster.

## Break the path

Change `update.path` in `clusters/kind/image-automation.yaml` in your clone to a folder that has no marked file:

```yaml
  update:
    path: ./clusters
    strategy: Setters
```

Then commit, push, and make the loop run:

```sh
git commit -am "Point the automation at clusters"
git push
flux reconcile kustomization fleet --with-source
flux reconcile image update podinfo
flux get image update podinfo
```

The automation stays `Ready` and reports no error. Nothing is wrong from the controller's point of view: it searched a folder without markers and found nothing to change. This is the hardest fault to see, because no object turns red.

## Several automations in one repository

One repository can hold many applications, and each can have its own automation with its own path, author and branch. Two automations that write the same files at the same time race each other, so give each one its own folder, with its own markers.

Set the path back to `./apps/podinfo` before you continue, and push the change. You now know how the controller picks its files, and you can read a silent automation. The next part changes what the controller writes in the commit.

## Common pitfalls

> [!WARNING]
> - **A path without the leading `./` or with a wrong folder.** The controller reads another folder or none, and never commits.
> - **A marker in a file with another extension.** The controller reads only `.yaml` and `.yml` files.
> - **Two automations over the same folder.** They write the same lines and conflict.
> - **Leaving `update.path` out in a large repository.** The controller scans every file at every run.
> - **Applying the generated object with `kubectl` instead of committing it.** The next sync of `fleet` prunes it.

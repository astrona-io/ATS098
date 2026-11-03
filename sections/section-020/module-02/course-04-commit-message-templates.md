# Commit Message Templates

A history of commits that all say "Automated image update" tells a reader that something changed, and nothing about what. When a release breaks production, the first question is which commit introduced which tag. A template that writes the old value and the new value into the message answers it from `git log`. This part writes that template and explains each field it can use.

## The template language

`spec.git.commit.messageTemplate` is a Go template: ordinary text with actions in double braces. The controller renders it once for each commit, with this data:

| Field | What it holds |
| --- | --- |
| `.AutomationObject` | The namespace and name of the automation |
| `.Changed.FileChanges` | The files that changed, with the changes in each file |
| `.Changed.Objects` | The objects that changed, with their changes |
| `.Changed.Changes` | Every changed value, as a flat list |
| `.Values` | Values you define in `spec.git.commit.messageTemplateValues` |

Each entry of `.Changed.Changes` has three fields: `.OldValue`, `.NewValue` and `.Setter`. `.Setter` is the marker that caused the change, for example `flux-system:podinfo:tag`. The older field `.Updated` is gone, and a template that uses it cannot render.

## List the changes

The commands below need the automation in your clone of `gitops/fleet` and the port-forward to Gitea in a second terminal.

<!-- astrona:playground:renew -->

Change the `commit` part of `clusters/kind/image-automation.yaml` so it reads:

```yaml
    commit:
      author:
        name: fluxcdbot
        email: fluxcdbot@example.com
      messageTemplate: |
        Release {{ .Values.application }}

        {{ range .Changed.Changes -}}
        - {{ .OldValue }} -> {{ .NewValue }} ({{ .Setter }})
        {{ end -}}
      messageTemplateValues:
        application: podinfo
```

The `range` loop runs once for each change. The `-` inside the braces removes the line break next to it, so the list has no blank lines. `messageTemplateValues` is a map of strings, and `.Values.application` reads one of them. Commit and push the change, then copy a release into the registry:

```sh
git commit -am "Describe every change in release commits"
git push
flux reconcile kustomization fleet --with-source
kubectl -n registry exec deploy/registry-tools -- \
  regctl image copy ghcr.io/stefanprodan/podinfo:6.14.1 registry.localtest.me:5000/podinfo:6.14.1
flux reconcile image repository podinfo
flux reconcile image update podinfo
git pull
git log -1 --format='%B'
```

The newest commit message starts with `Release podinfo` and lists each change with the old value, the new value and the marker. The list has one line for each marked value that changed, in every file under the path.

## Group by file or by object

`.Changed.Changes` is a flat list. When a commit changes several files, a reader may prefer them grouped. `.Changed.FileChanges` is a map from the file name to the changes in it, and `.Changed.Objects` is a map from an object to its changes. Both can be looped with `range`, and the key is the file name or the object. Use the one that fits how your team reads history.

## Validate the template before you rely on it

A template that fails to render stops the commit, and the automation reports the error in its status. After each change to the template, run `flux reconcile image update podinfo` and read `flux get image update podinfo`. A render error shows there at once, and not at the next release.

You can now make each release commit explain itself. Two more things shape the history: who signs the commits, and where they are pushed.

## Common pitfalls

> [!WARNING]
> - **`.Updated` in the template.** The field no longer exists. Use `.Changed`.
> - **`.Values` for a key that `messageTemplateValues` does not define.** The message has an empty value, or the render fails.
> - **Ranging over `.Changed.FileChanges` as if it were a list.** It is a map; use `$name, $changes :=` in the `range`.
> - **A template that is never rendered before a real release.** Reconcile once after each edit and read the status.

## Your mission: Describe Releases In Commit Messages

You can now write a commit message template that lists what a release changed. The graded lab gives you an automation with a fixed message and the wrong author, and asks you to fix both in Git, so that each release commit names the old tag and the new tag.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-098-playground-020-02
```

Then start the lab:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS098.git -c sections/section-020/module-02/labs/lab-01
```

The task is on the next page. Solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-020/module-02/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-098-lab-020-02
astrona start ats-098-playground-020-02
```

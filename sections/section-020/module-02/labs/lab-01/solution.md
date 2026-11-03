# Solution: Describe Releases In Commit Messages

Work the task yourself first. Running `astrona submit -c sections/section-020/module-02/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks three things: the setter marker is still on the `newTag` line, the `ImageUpdateAutomation` in Git has the right author and a template with `.Changed.Changes`, and a real release. It copies podinfo `6.15.0` into the registry and reads the commit the automation makes.

## Step 1: Clone the repository and read the automation

Start the port-forward in a second terminal (`kubectl -n gitea port-forward svc/gitea-http 3000:3000`), then clone:

```sh
git clone http://gitops:gitops-password@gitea.localtest.me:3000/gitops/fleet.git
cd fleet
cat clusters/kind/image-automation.yaml
```

The author is `fluxcdbot` and the message template is one fixed line.

## Step 2: Change the author and the template

Change the `commit` part of `clusters/kind/image-automation.yaml` so it reads:

```yaml
    commit:
      author:
        name: release-bot
        email: release-bot@example.com
      messageTemplate: |
        Release podinfo

        {{ range .Changed.Changes -}}
        - {{ .OldValue }} -> {{ .NewValue }}
        {{ end -}}
```

The `range` loop runs once for each changed value. `.OldValue` is the value before the change and `.NewValue` is the value after it. Commit and push:

```sh
git commit -am "Describe releases in commit messages"
git push
flux reconcile kustomization fleet --with-source
flux get image update podinfo
```

## Step 3: Test with 6.14.1

```sh
kubectl -n registry exec deploy/registry-tools -- \
  regctl image copy ghcr.io/stefanprodan/podinfo:6.14.1 registry.localtest.me:5000/podinfo:6.14.1
flux reconcile image repository podinfo
flux reconcile image update podinfo
git pull
git log -1 --format='%an <%ae>%n%B' -- apps/podinfo/kustomization.yaml
```

The newest commit is by `release-bot <release-bot@example.com>` and its message lists the old tag and the new tag.

## Step 4: Submit

```sh
astrona submit -c sections/section-020/module-02/labs/lab-01
```

The grader runs the same loop with `6.15.0`.

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| The old field `.Updated` in the template | The field no longer exists, and the automation cannot render the message |
| Only changing the author | The template check fails, because the message has no values |
| Pushing to `image-updates` | The commit never reaches `main`, and the grader reads `main` |
| Editing `apps/podinfo/kustomization.yaml` by hand | The last change is not by `release-bot` |

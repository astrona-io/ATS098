# Section 020: Automated Git Write-Backs

An `ImagePolicy` can choose the right new tag, but the choice only lives in the policy's status. The cluster still runs what Git says, and Git still names the old tag. Someone has to change the file, commit and push, every time a release arrives. In GitOps that someone should not be a person, and it must not be a controller that changes the cluster behind Git's back.

This section covers the second half of Flux image automation: writing the chosen tag into Git. The image automation controller, the second optional Flux controller for images, clones the repository, finds the fields you marked, writes the new tag, commits and pushes. Git stays the only source of truth, and the history shows every release as a commit by the automation.

**Topic covered:** automated Git write-backs

## What you will learn

- What a setter marker is, its four forms, and why the `:tag` form fits the Kustomize file `kustomization.yaml`.
- Writing an `ImageUpdateAutomation`: the repository, the branch to check out, the path to update, the commit author and the push branch.
- The release loop: new tag, policy, commit, sync, rollout, and the commands that speed up each step.
- Reading `flux get image update`, `.status.lastPushCommit` and the commit in Git.
- Commit message templates and the data they can use.
- Pushing to a separate branch so a person reviews each release before it reaches `main`.

## The learning path

Work through the module in order. It has a landing page, three short parts, a graded lab right after the part it tests, and a summary. The landing page starts the module's playground.

### 1. Write New Image Tags Back To Git

The module starts at its landing page, which also launches the playground. The playground scans the lab registry with a SemVer policy that follows `6.x`, and runs podinfo `6.14.0`. Nothing writes to Git yet.

1. Marking Fields With Setter Markers
2. ImageUpdateAutomation And The Release Loop, followed by the lab **Automate The podinfo Release**
3. Commit Messages, Authors And Branches
4. Summary

## Section capstone: Repair A Release Loop That Never Commits

The capstone is one graded scenario that combines the whole module. A team set up the whole release loop in Git, and no release ever reaches the cluster. The fault is not in one place: a new tag stops at four different points between the registry and `main`. Follow a tag through the loop and fix each stop. Work it after the module lab.

Start the capstone:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS098.git -c sections/section-020/capstone/labs/lab-01
```

When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-020/capstone/labs/lab-01
```

When the capstone is done, remove it:

```sh
astrona destroy ats-098-capstone-020
```

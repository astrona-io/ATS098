# Section 010: Scanning Image Registries

A new release of an application starts as a new tag in a container registry. Before Flux can roll it out, Flux has to notice the tag and decide whether it is the one to run. A registry holds many kinds of tags side by side: stable releases, release candidates, `latest`, and build tags with a commit and a timestamp. Choosing the wrong one ships the wrong code.

This section covers the first half of Flux image automation: finding tags and choosing one. The image reflector controller, an optional Flux controller, does both. An `ImageRepository` tells it which image to scan. An `ImagePolicy` tells it how to choose one tag from the scan. Nothing here changes Git or the cluster yet. The result is one field, `.status.latestRef.tag`, and getting that field right is the whole skill.

**Topic covered:** scanning image registries and choosing tags

## What you will learn

- What the image reflector controller does and which objects it reads.
- Writing an `ImageRepository` for a registry, with a scan interval and, for a plain HTTP registry, `insecure: true`.
- Reading the scan result: how many tags were found and which ones are the newest.
- Leaving tags out of the scan with `exclusionList`.
- Choosing a tag with a SemVer, numerical or alphabetical `ImagePolicy`, and why the choice matters.
- Why a SemVer range such as `6.x` skips release candidates.
- Keeping only some tags with `filterTags.pattern`, and sorting build tags by a timestamp taken out with `filterTags.extract`.

## The learning path

Work through the module in order. It has a landing page, three short parts, a graded lab right after the part it tests, and a summary. The module has its own playground, a cluster where you can explore freely, and the landing page starts it for you.

### 1. Scan A Registry And Choose A Tag

The module starts at its landing page, which also launches the playground. The playground holds a lab registry with podinfo tags from `6.12.0` to `6.15.0`, two release candidates and a `latest` tag.

1. Scanning A Registry With ImageRepository
2. Choosing A Tag With ImagePolicy, followed by the lab **Pick The Newest Stable Release**
3. Filtering And Extracting Build Tags
4. Summary

## Section capstone: Track The Newest Main Build

The capstone is one graded scenario that combines the whole module. A build pipeline pushes a tag for every commit, such as `main-0c1d2e3-1760007200`, and a tag for every pull request. The scan of those tags fails, the scan leaves out the tags that matter, and the policy cannot sort them. Make Flux follow the newest build of the `main` branch. Work it after the module lab.

Start the capstone:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS098.git -c sections/section-010/capstone/labs/lab-01
```

When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-010/capstone/labs/lab-01
```

When the capstone is done, remove it:

```sh
astrona destroy ats-098-capstone-010
```

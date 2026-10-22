# ATS098 — Image Automation & Progressive Delivery (FluxCD)

Course material for the **Image Automation & Progressive Delivery** domain of
the Astrona FluxCD training path ([ATP019](https://github.com/astrona-io/ATP019)),
which is **15% of the path**. Written for **Flux v2.9.6** and **Flagger 1.45.0**.

> **Status: draft, not yet run.** Every page, playground and lab was written
> from the Flux v2.9 and Flagger 1.45 documentation. None has been started on a
> cluster, and no lab has passed `astrona test` yet. See `CLAUDE.md` for the
> open risks.

The course opens with an Introduction in `sections/intro/` (welcome, machine setup,
how the course is made). Everything else lives under `sections/`. Each section
contains:

- **Modules** — a reading chapter split into a short landing page, ordered
  deep-dive parts and a summary page, a throwaway **playground** to explore in,
  and a graded **lab** placed right after the part it tests.
- **A capstone** — one larger graded lab combining that section's modules into a
  single scenario with several independent faults.

---

## Sections

| Section | Title | Modules | Labs | Topic |
| --- | --- | --- | --- | --- |
| [010](sections/section-010) | Scanning Image Registries | 1 | 1 + capstone | `ImageRepository`, `ImagePolicy` |
| [020](sections/section-020) | Automated Git Write-Backs | 1 | 1 + capstone | `ImageUpdateAutomation`, setter markers |
| [030](sections/section-030) | Progressive Delivery With Flagger | 1 | 1 + capstone | Flagger `Canary`, A/B testing |

The order is the order a release travels: a new tag in the registry, a commit
in Git, and a gradual rollout to users.

---

## Modules

| Module | Reader | Parts | Labs |
| --- | --- | --- | --- |
| 010-01 | [Scan A Registry And Choose A Tag](sections/section-010/module-01/course.md) | 3 | [lab-01](sections/section-010/module-01/labs/lab-01) |
| 020-01 | [Write New Image Tags Back To Git](sections/section-020/module-01/course.md) | 3 | [lab-01](sections/section-020/module-01/labs/lab-01) |
| 030-01 | [Roll Out Releases Gradually With Flagger](sections/section-030/module-01/course.md) | 3 | [lab-01](sections/section-030/module-01/labs/lab-01) |

---

## Capstones

| Capstone | Scenario | Faults |
| --- | --- | --- |
| [010](sections/section-010/capstone/labs/lab-01) | Track The Newest Main Build | no `insecure` for an HTTP registry, an `exclusionList` that drops the main builds, a numerical policy without `extract` |
| [020](sections/section-020/capstone/labs/lab-01) | Repair A Release Loop That Never Commits | the scan, a marker for a policy that does not exist, a wrong `update.path`, a wrong push branch |
| [030](sections/section-030/capstone/labs/lab-01) | Ship A Release From Registry To Primary | a policy range that stops at 6.14, a wrong `update.path`, a load test sent to the wrong namespace |

---

## The lab environment

Every playground and lab is a **kind** cluster with:

- Gitea (`gitea/gitea:28.2.0-rootless`) holding `gitops/fleet`, reachable as
  `http://gitea.localtest.me:3000` on the reader's machine (port-forward) and in
  the cluster (CoreDNS rewrite);
- a lab container registry (`registry:2.8.3`) at `registry.localtest.me:5000`,
  plain HTTP, and `registry-tools` (`regclient/regctl:v0.11.6-alpine`) to copy
  podinfo tags into it;
- Flux 2.9.6 with the image reflector and image automation controllers, synced
  from `clusters/kind` by the Flux `Kustomization` `fleet`;
- in section 030 only: ingress-nginx 4.15.1, Flagger 1.45.0 with its Prometheus
  and the Flagger load tester, installed by Flux HelmReleases from
  `infrastructure/`. These environments need about 6 GiB and several minutes
  to start.

The plumbing (manifests, Git seeds, bootstrap, solution and validation
scripts, `config.yaml` and the author READMEs) is the same pattern in every
environment; change a shared piece in all nine.

## Running a playground

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS098.git -c sections/<section>/<module>/playground
astrona destroy <name>
```

## Running a lab

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS098.git -c sections/<section>/<module>/labs/lab-01
astrona submit -c sections/<section>/<module>/labs/lab-01
astrona destroy <name>
```

Most graders add a new podinfo tag to the lab registry and follow it through
the policy, a commit by the automation, and the cluster. They reject the
plausible-but-wrong fix: editing a tag by hand, applying Flux objects with
`kubectl` instead of Git, or skipping Flagger's analysis.

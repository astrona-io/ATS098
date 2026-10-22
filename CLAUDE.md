# Writing style for this repo

All study text here (course pages, lab docs, READMEs, comments in YAML and
scripts) is for people learning a technical subject, often for a
certification exam. Many of them are not native English speakers and have no
university degree.

## Technical documentation in plain English

This is technical documentation. Say exactly what the system does, with the
real technical terms, in clear and simple English. Never hide a concept
behind a metaphor, a made-up name or a vague word: the reader must learn the
words they will meet in the product, the logs and the exam.

Strict guidelines:

1. Use the correct technical term every time (request, response, pod,
   namespace, Service, sidecar proxy, certificate, mTLS, JWT, listener). The
   first time a term appears in a file, define it in one plain sentence that
   says what it is and what it does. Spell out every acronym on first use.
2. No metaphors or analogies in explanations. Not "the communications
   officer", but "the sidecar proxy (Envoy)"; not "a signal", but "a
   request"; not "the planet", but "the namespace".
3. Simple sentences. Target a Flesch-Kincaid Grade Level of 8 or 9 for the
   prose around the terms. Keep sentences direct; split long sentences into
   two. No corporate buzzwords.
4. Use short paragraphs (max 3-4 sentences per paragraph).
5. Use the active voice ("istiod sends the configuration", not "the
   configuration is sent").

## How this applies to course material

- **Know which file you are in.** A module has a short landing page, a few
  deep-dive parts and a summary page. The landing page is a map: goals, what
  to know first, the order of the parts. The real teaching goes in the parts.
  The summary closes the module. A lab
  has a task, a step-by-step solution and a short intro. Keep each file to its
  job. Do not add "Prerequisite: ... Next: ..." navigation lines to pages;
  the landing page and the course outline already give the order.
- **Keep each part short.** One idea per part, about 5 to 8 minutes of
  reading and at most about 8 command blocks, so a learner can finish it with
  the playground in one sitting of about 15 minutes. Split at a natural seam
  where each half ends with something the learner has seen work. Never split
  only to hit a number. When you split, renumber the files, fix every "Part N"
  reference in the module and `astrona.yaml`.
- **Read like a book, not like a web page.** Each part reads as a chapter of
  a technical book. Open with a short paragraph on the problem it solves and
  why it matters. Link each paragraph to the next with a transition sentence.
  Close with a paragraph that sums up what the reader now knows and the
  question still open, before `## Common pitfalls` and the mission. Write
  explanations as prose; keep bullets for real lists (fields, ordered steps,
  options). Use `##` only when the topic changes and `###` only inside a long
  section, never for a single command. Weave hands-on steps into the text:
  one or two sentences on what to run and why, the command, the real output,
  then a sentence or two on what it shows.
- **The module ends with a summary.** The last page of every module is
  `course-0N-summary.md` with the title `# Summary`: a few short prose
  paragraphs on what the reader learned, organised by idea, optionally with
  one short list of key facts. It names no parts, modules, sections or
  chapters, and has no links, lab table, quiz or commands. Its last line is
  `<!-- astrona:playground:destroy -->` on its own line; the platform turns it
  into the step that removes the playground.
- **Every heading gets an intro.** A `##` section that has `###`
  subsections starts with one to three sentences that say what the section
  is about and why it matters, before the first `###`. Never put a `###`
  directly under a `##`.
- **Every module stands on its own.** Never refer to other sections or
  modules: no "see section 040", "as module 3 showed", "you met this in
  section 000", and no links to pages in another module. If the reader needs
  a fact from elsewhere, state the fact directly in one or two sentences.
  This also goes for parts of the same module: never write "Part 2 shows",
  "from Part 1" or "as in Part 3". Say the fact itself ("the commands below
  need the `scout` `DestinationRule` applied"). This includes the summary.
  The landing page does not have a "Where this fits" section.
- **Write words out in full.** Do not use informal short forms in prose:
  write "communications", "configuration", "repository", "administrator",
  "for example" and "that is", never "comms", "config", "repo", "admin",
  "e.g." or "i.e.". Names in code, commands and file paths stay as they are.
- **Exam terms stay.** The product's own names are what the reader must learn
  (for example a resource kind, a field, a command). Use them as they are and
  define each one in plain technical words the first time it appears in a
  file. Spell out acronyms on first use, with a short plain meaning.
- **The space theme is only for examples.** Space appears in two places and
  nowhere else: the names of the example workloads (the Starfleet: `bridge`,
  `scout`, `shuttle`, `probe`, the `starfleet` and `outpost` namespaces) and
  the short scenario that opens a lab task or a practice exercise (for
  example "the `drifter` in `outpost` must keep reaching the probe"). The
  explanation around an example is plain technical text: write "the
  `shuttle` pod sends a request to the `probe` Service", never "the shuttle
  sends a signal to the probe ship". Do not address the reader as an
  astronaut, and do not use space metaphors (communications officer, mission
  control, badge, airlock, guest list, star chart) for Istio or Kubernetes
  concepts. Titles of pages and labs name the technical task ("Require mTLS
  With PeerAuthentication"), not a space story.
- **Show one real example before the rule.** Start with a concrete case the
  reader can run, then give the general rule.
- **Say which part does the work.** Readers often mix up the parts of a system
  that sit close together. Whenever something happens, say which component
  did it.
- **Never change code to fit the style.** Commands, configuration files, field
  names, resource names, log lines and command output stay exactly as they
  are. They were run and checked on a real system. Never make up command
  output. If you shorten it, say that you did.
- **Prose only.** The grade-level and sentence rules apply to explanations.
  They do not apply to code blocks, tables of field names or reference lists
  (those may stay short and dense).
- **Keep the page furniture the same.** Hands-on steps are part of the prose
  (see "Read like a book"), not boxes or headings of their own. A `> [!TIP]` box is
  only for a real tip: advice the reader can reuse beyond this one step (a
  habit, a shortcut, how to spot a problem, an exam habit). Everything else
  is a normal sentence: notes about the current step ("if the log line is
  old, run it again"), background facts, optional extra steps, and plain
  information. Never a command snippet, never two in a row, and most pages
  need zero or one tip. Each part ends with a
  `## Common pitfalls` `> [!WARNING]` block for that part only. Use a Mermaid
  diagram for a flow, an order or a state change, keep it under about 12
  boxes, and follow it with one sentence that says what it shows.
- **Labs come right after the part they practise.** Do not collect all
  graded labs at the end of a module. In `astrona.yaml`, put each lab (its
  `question.md` reading and the `lab` entry) right after the reading part it
  tests. If a part teaches a gradeable skill and no lab covers it, create a
  new lab. That part then ends with a `## Your mission: <lab title>` section:
  one sentence on what the reader can now do, one on what the mission asks,
  then pause the playground (`astrona stop <playground name>`), the
  `astrona run` and `astrona submit` commands, and finally
  `astrona destroy <lab name>` plus `astrona start <playground name>`.
- **Renew the playground before hands-on work.** Every reading part that
  runs commands has `<!-- astrona:playground:renew -->` exactly once, on its
  own line, right before the first hands-on step (the first "Save this as"
  or the first command block), so the playground timer is reset before the
  learner needs the playground. Not on landing pages (they carry
  `<!-- astrona:playground -->`), summary pages (they carry
  `<!-- astrona:playground:destroy -->`) or pages without commands.
- **Mermaid without HTML.** The platform renders Mermaid with HTML labels
  switched off, so `<br/>` and any other HTML tag break the drawing. Rules:
  - One line per box, no `<br/>`, no HTML. Keep the box to the thing's name
    (`"scout-v2"`, `"istiod"`, `"Service: scout"`).
  - Put the logic on the arrows: `E -->|"version: v2"| P2`,
    `I -->|"CDS"| C`, `A -->|"end-user: jason"| B`. Keep edge labels short.
  - Quote every label. Prefer `flowchart TB`; use `LR` only for a short chain.
  - Sequence diagrams: short participant aliases (`participant S as shuttle`)
    and short message text.
  - Anything longer (cluster names, full hostnames) goes in the sentence under
    the diagram.
- **Every course starts with an Introduction.** It lives in `sections/intro/`
  and is the first entry in `astrona.yaml` (`id: module-intro`, title
  "Introduction"). It has exactly these four pages, in this order:
  - `README.md`, `# Introduction`: what the introduction covers and its three
    pages, named in prose (no links), ending with the topic the course starts
    with.
  - `course-01-welcome.md`, `# Welcome To The Course`: who the course is for,
    the exam domain and what the reader can do at the end, the words the
    course uses, the example app, how the course is laid out and how to read
    a page.
  - `course-02-get-your-machine-ready.md`, `# Get Your Machine Ready`: the
    tools to install, the `astrona` commands used every day, and what to do
    when a start goes wrong.
  - `course-03-how-this-course-is-made.md`, `# How This Course Is Made`: how
    content is written and checked, the maintainers, how to report a mistake,
    and the license.
  The Introduction teaches no product content and has no playground, labs or
  summary. Its only links are the repository's contributors page, issues
  page and license.
- **No links to other course files.** A course page (every reading listed in
  `astrona.yaml`, the playground guide `docs/overview.md`, and a lab's
  `question.md` and `solution.md`) never links to or points the reader at
  another page or file of the repository: no links to parts, summaries,
  labs, `question.md`, other modules, sections or the Introduction, and no
  "see `practice.md`" or "open `config.yaml`". The platform shows the pages in
  the order of `astrona.yaml`, so a link only adds a second, often wrong,
  path. Name a thing in plain words when the reader needs it ("the task is on
  the next page"), and state a fact on the page itself instead of sending the
  reader somewhere else. Repository files for authors (the root `README.md`,
  a lab's or playground's `README.md`) may link.
- **No links to outside sources.** Course pages, labs and playground docs do
  not link to or point at outside websites (the one exception is the
  `resources` field of a lab entry in `astrona.yaml`) (official docs, GitHub, blogs,
  RFCs), and they have no "Reference" or "Official docs" lists. Everything the
  reader needs is explained on the page itself. Not affected: addresses the
  reader actually uses in a command or browser (`http://127.0.0.1:9080`,
  `curl https://httpbin.org`), and the Introduction's contributors and
  "report a mistake" links.
- **Configuration goes to a file first.** Whenever the reader should apply
  YAML (course parts, playground docs, labs), use three separate steps:
  1. "Save this as `virtualservice-scout.yaml`:" followed by a plain
     ` ```yaml ` block with only the YAML. No `cat > file <<'EOF'`, no
     `kubectl apply -f - <<EOF`, no shell around it.
  2. "Apply it:" followed by a ` ```sh ` block with only
     `kubectl apply -f virtualservice-scout.yaml`.
  3. "Then check the result:" followed by the check commands, if any.
  The file name says the kind and the object. If a value must come from the
  reader's cluster (an IP address), use a placeholder like `<PARTNER>` in the
  YAML and say how to get the value (`echo $PARTNER`); never put shell
  variables inside YAML. Apply an object the first time its YAML appears; do
  not show it once "to read" and paste it again later. Never tell the reader
  to apply something from the playground's `examples/` folder: they start the
  playground with `astrona run`, so that folder is not on their machine.
- **Helpers have readable names.** Shell helper functions and variables use
  names that say what they do (`check_route`, `count_versions`,
  `$SERVICE_URL`), never single letters.


## About this repo (ATS098 only)

Everything above is general and can be copied to other course repositories. This
section is only true for this one.

### What the student is trying to learn

- **The goal:** master the **Image Automation & Progressive Delivery** domain
  of the **FluxCD** training path (`ATP019`). It is 15% of the path. There is
  no official Flux certification exam; the path's domains and weights are
  Astrona's own, set in `ATP019/path.yaml`.
- **What the domain really tests:** making a new container image travel from
  a registry to production without a person editing YAML, and making that
  travel safe. The student must *do* things (scan a registry, choose a tag
  with a policy, mark a field for Flux to update, let Flux commit to Git,
  and let Flagger shift traffic to a new version and promote or roll it
  back). Every fix is proved with a real new tag that moves through the loop:
  the policy picks it, a commit appears in Git, and the workload runs it.
- **The three topics:** scanning image registries, automated Git write-backs,
  and progressive delivery with Flagger. The README table maps each section
  to its topic.
- **The sections:**

  | Section | Title | Topic |
  | --- | --- | --- |
  | 010 | Scanning Image Registries | `ImageRepository` and `ImagePolicy` |
  | 020 | Automated Git Write-Backs | `ImageUpdateAutomation` and setter markers |
  | 030 | Progressive Delivery With Flagger | Flagger, the `Canary` resource, A/B testing |

- **The version:** everything is written for **Flux v2.9.6** (CLI and
  controllers, with `image-reflector-controller` and
  `image-automation-controller`) and **Flagger 1.45.0** (Helm chart
  `flagger` 1.45.0, `loadtester` chart 0.39.0) with the **ingress-nginx**
  Helm chart 4.15.1, on a single-node `kind` cluster. Flux 2.9 supports
  Kubernetes 1.34.1 or later. Do not teach fields, flags or output from other
  versions without saying so.
- **The main sources:** the Flux image automation documentation,
  <https://fluxcd.io/flux/components/image/> and
  <https://fluxcd.io/flux/guides/image-update/>, and the Flagger
  documentation, <https://docs.flagger.app/>. Check every page against them.

### Status: built, not yet run

The first version of this repository was written from the Flux v2.9 and
Flagger 1.45 documentation **without a live run**. No playground or lab has
been started, and no `astrona test` has passed yet. Until a maintainer runs
them:

- Pages describe results in words. Do not add `text` output blocks until the
  output comes from a real run, and then paste it exactly.
- Treat every lab as unverified. Run `astrona validate` and `astrona test` on
  each one, one cluster at a time, before the course goes past `maturity:
  draft`.
- Remove this subsection when every lab has passed `astrona test`.

The open risks, most important first:

1. **Git credentials over plain HTTP.** The Flux documentation describes
   basic authentication for HTTPS only, and the repository `gitops/fleet` is
   private, so source-controller and image-automation-controller send the
   `gitops` credentials to `http://gitea.localtest.me:3000`. If either
   refuses, every environment fails at the first fetch or push. The fallback
   is Gitea on HTTPS with a self-signed certificate (`caFile` in the Secret).
2. **The lab registry tools.** `regctl` (image `regclient/regctl:v0.11.6-alpine`)
   copies tags into the lab registry. The container command runs
   `regctl registry set --tls disabled registry.localtest.me:5000` once at
   start; check that the flag and the configuration directory
   (`/home/appuser/.regctl`) work in that image.
3. **Flux and Flagger on one Deployment.** The `podinfo` Deployment in
   section 030 has no `replicas` field in Git, so Flux's server-side apply
   never owns the field that Flagger sets to `0`. Check that Flux does not
   report drift on the Flagger-managed target Deployment.
4. **ingress-nginx.** The ingress-nginx project stopped publishing releases
   after March 2026 (chart 4.15.1 is the last). Flagger's nginx tutorial still
   uses it, so the course does too. Say so once, in plain words, where the
   router is introduced; the canary model is the same with Flagger's Gateway
   API provider.

### Terms, not metaphors

Explanations use Flux's, Flagger's, OCI's and Kubernetes' own words. Define
each one in plain technical language on first use in a file, for example:

| Term | First-use definition (example wording) |
| --- | --- |
| Container registry | A server that stores container images and their tags, and answers the OCI distribution API |
| Tag | A name that points at one image in a repository of a registry, for example `6.15.0` |
| `ImageRepository` | Tells image-reflector-controller which image to scan, how often, and which tags to ignore |
| `ImagePolicy` | Tells image-reflector-controller how to choose one tag from the scanned list; the result is in `.status.latestRef` |
| SemVer policy | Chooses the highest tag that is a semantic version and matches a range, for example `6.x` |
| Numerical / alphabetical policy | Chooses the last tag in numeric or alphabetic order (`order: asc` by default) |
| `filterTags` | A regular expression (`pattern`) that keeps only matching tags, and an optional `extract` that takes a named part, such as a timestamp, for the policy to sort on |
| `exclusionList` | Regular expressions for tags the scan leaves out; the default leaves out `^.*\.sig$` (Cosign signatures) |
| `ImageUpdateAutomation` | Tells image-automation-controller which Git repository to clone, which path to update, and how to commit and push |
| Setter marker | A YAML comment, for example `# {"$imagepolicy": "flux-system:podinfo:tag"}`, that names the `ImagePolicy` whose result Flux writes into that line |
| Write-back | A commit that a controller pushes to Git, so Git stays the desired state |
| Flagger | A progressive delivery operator: it runs a new version next to the old one, shifts traffic step by step, checks metrics, and promotes or rolls back |
| `Canary` | The Flagger resource that names the target Deployment, the router and the analysis |
| Primary / canary | Flagger's copy of the last good version (`podinfo-primary`) / the new version under test (the target `podinfo` Deployment and `podinfo-canary` Service) |
| Analysis | Flagger's loop: every `interval` it checks the metrics, and either raises the canary weight by `stepWeight` up to `maxWeight`, or counts a failed check; `threshold` failed checks roll back |
| `MetricTemplate` | A Flagger resource with a custom Prometheus query for the analysis |
| Load tester | `flagger-loadtester`, a Service that runs commands such as `hey` when Flagger calls its webhook, so the canary gets traffic to measure |
| A/B testing | Routing only requests that match a header or cookie to the canary, for a number of `iterations` |
| Blue/green | Testing the new version with no user traffic, then switching all traffic at once |

Do not invent friendly names for these (no "the release robot", "the
traffic dial"). The product's names are what the student meets in the
console and the logs.

### The example workloads

| Name | Image | What it is |
| --- | --- | --- |
| `gitea` (Deployment and Service `gitea-http`, namespace `gitea`) | `gitea/gitea:28.2.0-rootless` | The in-cluster Git server, HTTP on port `3000`, storage on `emptyDir` |
| Gitea user `gitops` | | Password `gitops-password`, administrator. Lab-only credentials; say so when a page uses them |
| Repository `gitops/fleet` | | The cluster's Git repository |
| `registry` (Deployment and Service, namespace `registry`) | `registry:2.8.3` | The lab container registry, HTTP on port `5000`, storage on `emptyDir`. Holds copies of podinfo tags as `registry.localtest.me:5000/podinfo` |
| `registry-tools` (namespace `registry`) | `regclient/regctl:v0.11.6-alpine` | Runs `regctl` to copy and list tags in the lab registry |
| `podinfo` (Deployment, namespace `podinfo`) | `ghcr.io/stefanprodan/podinfo` | The demo application, port `9898`. Its tag comes from `images[].newTag` in `apps/podinfo/kustomization.yaml` |
| `tester` (namespace `gitea`) | `nicolaka/netshoot:v0.13` | Client pod with `curl` and `jq`. Graders call the Gitea API from here |
| `ingress-nginx-controller` (namespace `ingress-nginx`) | ingress-nginx chart 4.15.1 | Section 030 only. The router Flagger shifts traffic with; Service type `ClusterIP` |
| `flagger`, `flagger-prometheus` (namespace `ingress-nginx`) | Flagger chart 1.45.0 | Section 030 only. Flagger with `meshProvider: nginx` and its bundled Prometheus |
| `flagger-loadtester` (namespace `podinfo`) | loadtester chart 0.39.0 | Section 030 only. Sends load through the ingress during the analysis |

**Why the registry holds copies.** The cluster always pulls podinfo from
`ghcr.io/stefanprodan/podinfo`, because the `kind` node cannot pull from an
HTTP registry inside the cluster. The policy scans the lab registry, so the
reader decides when a "new release" appears. Every tag that is deployed must
therefore also exist upstream: `6.12.0`, `6.13.0`, `6.14.0`, `6.14.1`,
`6.15.0`. Made-up tags (`6.16.0-rc.1`, `main-1a2b3c4-1760000000`) are only
for scanning exercises and are never deployed. Explain this in one sentence
where a page needs it.

The setter marker is on `images[].newTag` in the Kustomize file
`apps/podinfo/kustomization.yaml`, with the `:tag` suffix, so Flux writes only
the tag and the image name stays `ghcr.io/stefanprodan/podinfo`.

The repository layout:

```text
fleet/
├── apps/podinfo/          # namespace, deployment, service (010/020) or ingress (030), kustomization.yaml
├── clusters/kind/         # Flux objects for this cluster: podinfo.yaml, image-podinfo.yaml, ...
└── infrastructure/        # section 030 only: HelmRepositories and HelmReleases
```

Flux is installed with `flux install --components-extra=image-reflector-controller,image-automation-controller`
and synced by hand-applied objects: Secret `fleet-auth`, `GitRepository`
`fleet` and Flux `Kustomization` `fleet` (path `./clusters/kind`, prune on),
all in `flux-system`. Everything the reader adds goes to Git under
`clusters/kind/` or `apps/podinfo/`.

### Environment facts the text must respect

- **One Git address and one registry address that work everywhere.**
  `http://gitea.localtest.me:3000/gitops/fleet.git` and
  `registry.localtest.me:5000`. Both public names resolve to `127.0.0.1`. On
  the reader's machine a port-forward answers
  (`kubectl -n gitea port-forward svc/gitea-http 3000:3000`); the reader does
  not need the registry from their machine, because `registry-tools` works
  inside the cluster. Inside the cluster, the bootstrap adds two CoreDNS
  `rewrite stop` blocks (copy them from any `bootstrap/` script here; never
  the one-line `rewrite name` form): each sends the name to its Service and
  rewrites the answer name back, because Go programs, Flux included, ignore an
  answer whose name differs from the question. If a home router blocks DNS
  answers that point at `127.0.0.1`, the reader adds
  `127.0.0.1 gitea.localtest.me` to `/etc/hosts`.
- **HTTP only.** The registry has no TLS, so every `ImageRepository` here sets
  `insecure: true` ("allows connecting to a non-TLS HTTP container
  registry"). Say on each such page that a real registry uses HTTPS.
- **Copying tags.** Pages and scripts use two helpers:

  ```sh
  push_podinfo_tag() {
    # push_podinfo_tag TAG: copies podinfo TAG from ghcr.io into the lab registry.
    kubectl -n registry exec deploy/registry-tools -- \
      regctl image copy "ghcr.io/stefanprodan/podinfo:$1" "registry.localtest.me:5000/podinfo:$1"
  }
  retag_podinfo() {
    # retag_podinfo FROM TO: adds tag TO to the image that tag FROM points at, in the lab registry.
    kubectl -n registry exec deploy/registry-tools -- \
      regctl image copy "registry.localtest.me:5000/podinfo:$1" "registry.localtest.me:5000/podinfo:$2"
  }
  ```

  List tags with
  `kubectl -n registry exec deploy/registry-tools -- regctl tag ls registry.localtest.me:5000/podinfo`.
- **Flux facts (from the documentation, not yet seen on a run):**
  - `image.toolkit.fluxcd.io/v1` for `ImageRepository`, `ImagePolicy` and
    `ImageUpdateAutomation`.
  - `ImageRepository`: `image` (no scheme), `interval`, `timeout`,
    `secretRef`, `certSecretRef`, `insecure`, `exclusionList` (default
    `^.*\.sig$`), `provider`, `suspend`; status `lastScanResult.tagCount`,
    `lastScanResult.latestTags`, `canonicalImageName`.
  - `ImagePolicy`: `imageRepositoryRef`, `policy.semver.range`,
    `policy.numerical.order`, `policy.alphabetical.order` (`asc` default),
    `filterTags.pattern` and `filterTags.extract` (for example
    `'^RELEASE\.(?P<timestamp>.*)Z$'` and `'$timestamp'`),
    `digestReflectionPolicy`; status `latestRef.image`, `latestRef.tag`,
    `observedPreviousRef`.
  - `ImageUpdateAutomation`: `interval`, `sourceRef`,
    `git.checkout.ref.branch`, `git.commit.author.name` and `.email`
    (`email` required), `git.commit.messageTemplate` (Go template with
    `.AutomationObject`, `.Changed.FileChanges`, `.Changed.Objects`,
    `.Changed.Changes`, `.Values`; the old `.Updated` is gone),
    `git.push.branch`, `update.path` (default the repository root),
    `update.strategy` (`Setters`, the only one); status `lastPushCommit`,
    `lastPushTime`.
  - Setter markers: full image `# {"$imagepolicy": "<ns>:<policy>"}`, and
    `:name`, `:tag`, `:digest` suffixes (`:digest` needs
    `digestReflectionPolicy` `IfNotPresent` or `Always`).
- **Flagger facts (from the documentation, not yet seen on a run):**
  - `flagger.app/v1beta1` `Canary`: `provider: nginx`, `targetRef`,
    `ingressRef`, `autoscalerRef` (optional), `progressDeadlineSeconds`,
    `service.port`, `service.targetPort`, `analysis.interval`, `.threshold`,
    `.maxWeight`, `.stepWeight`, `.iterations` and `.match` (A/B),
    `.metrics[]` (`request-success-rate`, `request-duration`, or
    `templateRef` with `thresholdRange.min`/`max` and `interval`),
    `.webhooks[]` (`type: pre-rollout` acceptance test, load test).
  - Flagger creates `podinfo-primary` (Deployment), the Services `podinfo`,
    `podinfo-primary` and `podinfo-canary`, and the Ingress `podinfo-canary`.
    So Git holds **no** `podinfo` Service in section 030.
  - Statuses: `Initialized`, `Progressing`, `Succeeded`, `Failed`.
  - The load test runs `hey` in `flagger-loadtester`; because the lab has no
    DNS for `app.example.com`, the command sends to the ingress Service with
    the host header:
    `hey -z 1m -q 10 -c 2 -host app.example.com http://ingress-nginx-controller.ingress-nginx/`.
- **Many environments start broken on purpose.** A lab seeds a fault in Git
  or in the cluster (a policy that picks the wrong tag, a marker that names
  the wrong policy, a wrong `update.path`, a load test that sends nothing).
  The fault is the material. Never "fix" it in the bootstrap.
- **The proof is a new tag moving through the loop.** Graders push or retag
  an image in the lab registry, run `flux reconcile image repository` and
  related commands instead of waiting, and then check `.status.latestRef.tag`,
  a new commit in Gitea by the automation author, the Deployment image, and
  for section 030 the `Canary` phase and the `podinfo-primary` image.

### Where things are in this repo

| What | Where |
| --- | --- |
| Course outline the platform reads: every reading page and lab, in order. Never list `solution.md` here | `astrona.yaml` |
| Overview, sections and modules tables, how to run things | `README.md` |
| Introduction (see "Every course starts with an Introduction") | `sections/intro/` |
| Section overview and its modules | `sections/section-0N0/README.md` |
| Module reading: landing page, deep-dive parts, closing page | `sections/section-0N0/module-0M/course.md`, `course-0N-*.md` |
| Graded lab: task, walkthrough, setup, grader | `.../labs/lab-01/` (`question.md`, `solution.md`, `prerequisites.md`, `bootstrap/`, `manifests/`, `solution/`, `testing/`, `validation/`) |
| Ungraded sandbox for a module | `.../playground/` (`config.yaml`, `bootstrap/prepare.sh`, `manifests/`, `docs/overview.md`, which is the only learner page) |
| One graded integration lab per section | `sections/section-0N0/capstone/labs/lab-01/` |

A lab folder holds:

| Path | Purpose |
| --- | --- |
| `config.yaml` | Lab definition; `metadata.docs` points at `question.md` and `solution.md` |
| `README.md` | Short intro for authors with `estimated_duration` front matter and the run, submit and destroy commands |
| `prerequisites.md` | What the learner needs before starting |
| `question.md` | The task. Starts with `# Question` and `Solve this question on: \`terminal\`` |
| `solution.md` | Step-by-step walkthrough |
| `bootstrap/01-install-git-and-flux.sh` | The Flux CLI, Gitea with the seeded repository, the lab registry, the CoreDNS rewrites and Flux with the image controllers. The same in every environment |
| `bootstrap/02-seed-state.sh` | Tags in the registry, the Flux sync objects, section 030's infrastructure, and the lab's faults |
| `manifests/` | `lab-start.yaml` (Gitea, tester, registry, registry-tools), `flux-sync.yaml`, and `repo/` (the files seeded into Git) |
| `solution/apply.sh` | Reference end state, applied only by `astrona test`; changes Git through the Gitea API because `astrona test` has no port-forward |
| `testing/wait-for-flux.sh` | Waits until Gitea, the registry and the Flux controllers answer |
| `validation/validate-*.sh` | Behavioural grading, one script per check |

### Lab metadata in `astrona.yaml`

`astrona.yaml` has a `training:` block (id `ATS098`, domain
`Image Automation & Progressive Delivery`, weight `15`) and one entry per
section under `modules:` (`module-010`, `module-020`, `module-030`). Each
section's `content` lists, in order: the section `README.md`, then for each
module its landing page, its parts, and right after the part a lab tests, a
`Question` reading (`labs/lab-01/question.md`) followed by the `type: lab`
entry; the module's closing page comes last. The section capstone closes the
section. Playgrounds are not listed.

Every `type: lab` entry carries the same fields, in the same order, as in
ATS016: `title`, `path`, `difficulty`, `estimated_duration`, `topic`,
`task_kind`, `tags`, `learning_goals`, `resources`.

- `difficulty`: `beginner`, `intermediate` or `advanced`.
- `estimated_duration`: realistic time to solve it, for example `15m`, `30m`.
  Section 030 environments take several minutes longer to start.
- `topic`: exactly one of `image-scanning`, `image-policies`,
  `image-automation`, `progressive-delivery`.
- `task_kind`: exactly one of `build`, `troubleshooting` or `migration`.
- `tags`: 4 to 8 ids, only from the tag list below. Add a new tag to the list
  first if nothing fits.
- `learning_goals`: 2 or 3 plain sentences, each starting with a verb.
- `resources`: 1 to 4 pages on `fluxcd.io` or `docs.flagger.app`, each with a
  `name` and a `url` that loads. This is the **only** place outside links are
  allowed.

**Tag list** (lower case, hyphens, never synonyms):

- Scanning and policies: `imagerepository`, `imagepolicy`, `semver`,
  `numerical`, `alphabetical`, `filter-tags`, `exclusion-list`,
  `insecure-registry`
- Automation: `imageupdateautomation`, `setter-marker`, `git-write-back`,
  `commit-template`, `push-branch`
- Flagger: `flagger`, `canary`, `canary-analysis`, `rollback`, `ab-testing`,
  `metric-template`, `load-tester`, `ingress-nginx`
- Flux: `kustomization`, `helmrelease`, `flux-reconcile`, `flux-get`

### Running things

```bash
# Playground (ungraded)
astrona run --git ssh://git@github.com/astrona-io/ATS098.git -c sections/section-010/module-01/playground
astrona destroy ats-098-playground-010-01   # takes metadata.name from config.yaml, not the path

# Lab or capstone (graded against the live cluster)
astrona run --git ssh://git@github.com/astrona-io/ATS098.git -c sections/section-010/module-01/labs/lab-01
astrona submit -c sections/section-010/module-01/labs/lab-01
astrona destroy ats-098-lab-010-01

# Authors: run a local, uncommitted copy, and prove a lab passes with its reference solution
astrona run -c sections/section-010/module-01/playground
astrona test -c sections/section-010/module-01/labs/lab-01
```

Names: a playground is `ats-098-playground-<section>-<module>`, a module lab
is `ats-098-lab-<section>-<module>` and a capstone is
`ats-098-capstone-<section>`; keep those names. Lab bootstrap scripts do not
pin a kube context: astrona sets `KUBECONFIG` for the lab. Every lab must pass
`astrona validate` and `astrona test`.

Graders check **behaviour**, not just that an object exists: a new tag in the
registry must reach `.status.latestRef`, Git and the running Deployment, and
in section 030 the `podinfo-primary` Deployment after a `Succeeded` analysis.
Graders also reject the plausible but wrong fix (`kubectl apply` of a Flux
object that belongs in Git, editing the Deployment image by hand, pinning the
tag in Git instead of automating it, suspending the `Canary`, skipping the
analysis with `skipAnalysis: true`). A lab's `question.md` and `solution.md`
must match what its `validation/` scripts actually check.

Test clusters on the maintainer's machine: one at a time. Section 030
environments are the heaviest in the path (Gitea, the registry, six Flux
controllers, ingress-nginx, Flagger, Prometheus and the load tester): give the
container engine about 6 GiB.

### Where to find trusted sources

Check facts here before writing them down. Prefer these over memory.

- **Image automation:** [ImageRepository](https://fluxcd.io/flux/components/image/imagerepositories/),
  [ImagePolicy](https://fluxcd.io/flux/components/image/imagepolicies/),
  [ImageUpdateAutomation](https://fluxcd.io/flux/components/image/imageupdateautomations/),
  [automate image updates to Git](https://fluxcd.io/flux/guides/image-update/)
- **Flagger:** [NGINX canary deployments](https://docs.flagger.app/tutorials/nginx-progressive-delivery),
  [deployment strategies](https://docs.flagger.app/usage/deployment-strategies),
  [metrics analysis](https://docs.flagger.app/usage/metrics),
  [webhooks](https://docs.flagger.app/usage/webhooks)
- **Flux:** [HelmRelease](https://fluxcd.io/flux/components/helm/helmreleases/),
  [command reference](https://fluxcd.io/flux/cmd/)
- **The landscape:** Flux and Flagger are both part of the Flux project, a
  graduated project of the Cloud Native Computing Foundation (CNCF).

### Skills to use here

The `astrona-course-*` skills do most authoring jobs in this repository:
planning (`domain-plan`), creating the tree (`domain-scaffold`), building
modules (`domain-build`), deep-dive parts (`deep-dive`), labs and playgrounds
(`lab`), lab docs (`lab-docs`), challenges (`create-challenge`), quizzes
(`generate-assessment`) and fact-checking (`review-accuracy`).

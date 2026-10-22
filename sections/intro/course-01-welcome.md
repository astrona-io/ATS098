# Welcome To The Course

This course trains you for the **Image Automation & Progressive Delivery** part of the Astrona **FluxCD** training path. That part is 15% of the path. This page tells you who the course is for, what you can do at the end, which words and example setup it uses, and how its pages fit together.

## Who this course is for

You already run applications with Flux: you know what a `GitRepository` and a Flux `Kustomization` do, and you can change a file in Git and watch Flux apply it. You know your way around Kubernetes Deployments, Services and Ingresses. You do not need to know the image automation controllers or Flagger yet. Each new idea is explained the first time it appears.

## What you can do at the end

A release is a new container image that has to reach production. This course teaches you to let Flux find it, write it to Git, and roll it out safely, so nobody edits a tag by hand. The course has three topics, and each one turns into a set of skills you will practise.

The first topic is **scanning image registries**. You will learn to:

- Scan a container registry with an `ImageRepository` and read the tags it found.
- Choose one tag with an `ImagePolicy`: the highest semantic version in a range, or the last tag in numeric or alphabetic order.
- Filter build tags such as `main-1a2b3c4-1760007200` and sort them by the timestamp they carry.

A chosen tag is only useful if it reaches Git, so the second topic is **automated Git write-backs**. You will learn to:

- Mark the field Flux may change with a setter marker.
- Write an `ImageUpdateAutomation` that commits the new tag and pushes it.
- Follow one new tag from the registry to a commit and a running Deployment.

The third topic is **progressive delivery with Flagger**. You will learn to:

- Describe a canary release with Flagger's `Canary` resource.
- Read Flagger's analysis as it shifts traffic, promotes or rolls back.
- Route only some users to a new version with A/B testing, and check a release with your own Prometheus query.

Everything is written for **Flux v2.9.6** and **Flagger 1.45.0**.

## The words this course uses

The pages use Flux's, Flagger's and Kubernetes' own terms, because those are the words you meet in the product, the logs and the documentation. Each term gets a short, plain definition the first time it appears on a page. A few terms come back on almost every page, so here they are up front.

A **container registry** stores container images, and a **tag** is a name that points at one image, such as `6.15.0`. **Image automation** is Flux's name for finding new tags and writing them to Git. A **write-back** is a commit that a controller makes, not a person. A **canary** is a new version that runs next to the old one and gets a growing share of the traffic while its error rate is measured.

Four new objects come back on almost every page:

| Object | What it does |
| --- | --- |
| `ImageRepository` | Tells Flux which image to scan for tags, and how often |
| `ImagePolicy` | Tells Flux how to choose one tag from the scan |
| `ImageUpdateAutomation` | Tells Flux where to write the chosen tag in Git, and how to commit it |
| `Canary` | Tells Flagger how to roll out a new version of a Deployment |

## The example setup in your playground

Every playground and lab runs the same setup. A Git server, Gitea, holds the repository `gitops/fleet`, and Flux applies it to the cluster. The demo application `podinfo`, a small web server, runs in the namespace `podinfo`. A small container registry runs inside the cluster too, so you decide when a "new release" appears: one command copies a podinfo tag into it.

You work with the repository from your own machine: you clone it, change a file, commit and push. In the last section, the cluster also runs ingress-nginx, Flagger and a load tester. Many labs start with something broken on purpose. That is the material, not a fault in the course.

## How the course is laid out

The course has three sections, in the order a release travels: from the registry, through Git, to the users.

| Section | What it covers |
| --- | --- |
| 010 | Scanning Image Registries |
| 020 | Automated Git Write-Backs |
| 030 | Progressive Delivery With Flagger |

Each section has one or more **modules**, and each module teaches one skill. A module brings together four kinds of material:

| What | What it is for | Graded? |
| --- | --- | --- |
| **Reading** | A short landing page, a few chapters that teach one idea each, and a summary | No |
| **Playground** | A small cluster on your own machine, to try everything you read | No |
| **Lab** | A cluster in a starting state, a task, and a grader that checks your work | Yes |
| **Capstone** | The last lab in a section, with several faults at once | Yes |

The best order is simple: read the chapters with the playground open next to them, take each lab when a chapter sends you to it, and finish each section with its capstone. The next part of this page explains how a module's pages guide you through that order.

## How to read a page

A module starts with a **landing page**. It says what the module teaches, what you should know first, and the order of its chapters. At the bottom of the landing page you start the module's playground, and you keep it running while you read.

The chapters (the parts of a module) read like the chapters of a technical book. Each one opens with the problem it solves, explains one idea in connected paragraphs, and closes with what you now know. The hands-on steps sit right in the text: a sentence or two on what to run and why, the command, and then what the result shows. Run each step in your playground as you reach it. You learn more from one real result than from a page of text.

Every chapter ends with a box of common pitfalls, the mistakes people make most often with what the chapter taught, and how to spot them. Now and then a page also has a tip box with a habit or shortcut you can use again, well beyond that page. The two boxes look like this:

> [!TIP]
> **A tip.** A habit or shortcut you can use again, well beyond this one page.

> [!WARNING]
> **Common pitfalls.** The mistakes people make most often with what you just learned, and how to spot them. Every chapter ends with one.

When a graded lab tests what a chapter taught, that chapter ends with a **Your mission** section. It tells you what the lab asks, then gives every command you need, in order: pause the playground with `astrona stop`, start the lab with `astrona run`, and send your work for grading with `astrona submit`. Solve the lab on your own before you look at its solution. When the lab is done, remove it with `astrona destroy` and start the playground again with `astrona start`, so you can carry on reading where you left off.

The last page of every module is the **Summary**. It sums up what you learned in a few short paragraphs, organised by idea. It also ends the module's hands-on work: the Summary page removes the playground, so your machine is clean before the next module.

One rule holds on every page. Code blocks are exactly what you type. Never change a command to make it "look right". If the result is different from what the page describes, that difference is the lesson.

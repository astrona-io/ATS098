# Section 030: Progressive Delivery With Flagger

Image automation gets a new release into the cluster without a person, and that is exactly what makes it risky. A broken release reaches every user the moment the Deployment rolls out. Kubernetes checks that the new pods start and pass their readiness probe; it does not check that they answer requests correctly.

This section adds the safety step. Flagger is a progressive delivery operator from the Flux project. It runs the new version next to the old one, sends it a growing share of the traffic, and reads metrics after every step. If the metrics stay good, it promotes the new version. If they do not, it sends all traffic back to the old version. You describe all of that in one object, the `Canary`, and Flagger does the rest.

**Topic covered:** progressive delivery

## What you will learn

- What Flagger does, which objects it creates, and what primary and canary mean.
- Writing a `Canary` for a Deployment behind ingress-nginx, the router Flagger shifts traffic with.
- Reading the analysis: interval, step weight, maximum weight, threshold and the request success rate.
- Following a promotion, and causing a rollback on purpose.
- Load tests and acceptance tests with Flagger's load tester and webhooks.
- A/B testing with a header match, blue/green deployments, and a custom Prometheus query in a `MetricTemplate`.

## The learning path

Work through the module in order. It has a landing page, three short parts, a graded lab right after the part it tests, and a summary. The landing page starts the module's playground. The playground installs ingress-nginx, Flagger, Prometheus and the load tester through Flux, so it takes several minutes to start.

### 1. Roll Out Releases Gradually With Flagger

The module starts at its landing page, which also launches the playground. The playground runs podinfo `6.14.0` behind an Ingress, with no `Canary` yet.

1. Flagger And The Canary Resource
2. Canary Analysis, Promotion And Rollback, followed by the lab **Promote A New Version Through A Canary**
3. A/B Testing, Blue/Green And Custom Metrics
4. Summary

## Section capstone: Ship A Release From Registry To Primary

The capstone joins image automation and Flagger into one pipeline: a new tag in the registry must end up as Flagger's promoted primary, with no person in between. The pipeline is all there and does not work. A release stops at three places: in the policy, in the automation, and in the canary analysis. Work it after the module lab.

Start the capstone:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS098.git -c sections/section-030/capstone/labs/lab-01
```

When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-030/capstone/labs/lab-01
```

When the capstone is done, remove it:

```sh
astrona destroy ats-098-capstone-030
```

# Summary

An image loop has four owners in a row, and a fault at one of them looks like a release that never arrives. Operating the loop means finding the first owner whose result is wrong.

## What you learned

`flux get image all` lists the repositories, the policies and the automations together. Each line shows `READY`, a message and `SUSPENDED`. Behind the line are the conditions and a result field: `.status.lastScanResult` for a repository, `.status.latestRef` for a policy, and `.status.lastPushCommit` with `.status.lastAutomationRunTime` for an automation. An object that fails says so, and the objects after it keep their old results and look calm.

`flux trace` goes from an applied object, such as a Deployment, back through the Flux `Kustomization` and the `GitRepository` to the commit. The commit's author shows whether a person or the automation made the change.

`flux suspend` and `flux resume` pause an object from the command line, and the next sync can undo that pause because Git does not contain it. A lasting pause is `spec.suspend: true` in Git. Suspending the automation stops commits and leaves the policy current.

A `Provider` names where events go, and an `Alert` names the sources and the severity. `flux events --for Kind/name` reads events, and `flux logs --kind --name` reads controller logs. Common faults are a wrong registry address or credentials, a range that matches nothing, a marker with the wrong policy or suffix, a path without the file, a suspended object, a push that the server refuses, and a template that fails to render.

The key facts to remember are these:

- Read the objects in loop order, and fix the first wrong one.
- A command-line pause is temporary; a pause in Git lasts.
- An automation that is ready and never commits has a path, marker or policy fault.
- The log of the scan and the policy is in the reflector controller; the log of commits is in the automation controller.

<!-- astrona:playground:destroy -->

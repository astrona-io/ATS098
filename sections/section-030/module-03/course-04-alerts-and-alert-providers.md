# Alerts And Alert Providers

A rollback at night protects the users and tells nobody. The team learns about it from a ticket the next day. Flagger can send a message at the moment of a promotion, a failed check or a rollback. This part configures the receiver, attaches it to a `Canary`, and shows how the severity decides which events a receiver gets.

## The AlertProvider

An `AlertProvider` is a Flagger object that describes where to send messages. Its `type` names the kind of receiver. The types include `slack`, `discord`, `msteams`, `rocket`, `webex`, `telegram` and `generic`. A `generic` provider sends the event as a JSON `POST` to any address, which fits a custom receiver or an incident system. The other fields are the `address` of the receiver, a `channel` and `username` for chat tools, and a `secretRef` that names a Kubernetes Secret with the `address` or token, so the secret address stays out of Git.

Save this as `apps/podinfo/alertprovider-on-call.yaml`:

```yaml
apiVersion: flagger.app/v1beta1
kind: AlertProvider
metadata:
  name: on-call
  namespace: podinfo
spec:
  type: generic
  address: http://flagger-loadtester.podinfo/
```

The playground has no chat tool, so this address points at a Service that exists. It does not accept alerts, and Flagger logs a warning when it cannot deliver one. A delivery failure never changes the result of a release. A real setup uses a `slack` or `generic` provider with the address of the team's receiver, kept in a Secret.

## Attach it with a severity

An `alerts` list in the `analysis` of the `Canary` attaches providers. Each entry has a `name`, a `severity` and a `providerRef`. The severity says which events the provider gets:

| Severity | Events sent |
| --- | --- |
| `info` | All events: start, step advance, promotion, failed check and rollback |
| `warn` | Warnings and errors: failed checks and rollbacks |
| `error` | Errors only: a rollback and a release that cannot start |

The default is `info`. Add this to the `analysis` of `apps/podinfo/canary.yaml`, next to `metrics` and `webhooks`:

<!-- astrona:playground:renew -->

```yaml
    alerts:
      - name: "on-call rollbacks"
        severity: error
        providerRef:
          name: on-call
          namespace: podinfo
```

This entry sends only errors to `on-call`. A team often adds a second entry with `severity: info` for a quiet channel that records every release. Without `alerts`, Flagger sends nothing, unless the chart was installed with a global `slack.url`, which sends every event to one Slack webhook.

## Commit and read the result

List `alertprovider-on-call.yaml` in `resources` of `apps/podinfo/kustomization.yaml`. Then commit, push and apply:

```sh
git add apps/podinfo
git commit -m "Alert on-call about podinfo rollbacks"
git push
flux reconcile kustomization podinfo --with-source
kubectl -n podinfo get alertprovider
```

The list shows the provider `on-call`. Release a version and let it fail with the same steps as in the status part of the earlier module, or with a load test that sends errors. The Kubernetes events of the `Canary` record the same events that the alerts carry, so they are the place to compare:

```sh
kubectl -n podinfo describe canary podinfo | sed -n '/^Events:/,$p'
kubectl -n ingress-nginx logs deploy/flagger --tail=30
```

The events show the warning and the rollback. The Flagger log shows, for each alert Flagger could not deliver, a warning that names the provider. A provider that works shows no such line.

A third route sends events to an outside receiver without an `AlertProvider`: a webhook of the type `event` gets every event as a `POST`. Use it when you need the whole event stream in a system that has no provider type.

You can now route the events of a release to the people who need them and choose how much each receiver hears. The last part is about the case where nothing is sent because nothing moves.

## Common pitfalls

> [!WARNING]
> - **An `AlertProvider` that no `Canary` refers to.** Flagger sends nothing.
> - **`severity: info` on a busy channel.** Every step of every release reaches it, and people stop reading.
> - **A secret address in the `address` field.** It lands in Git; use `secretRef`.
> - **A `providerRef` without the right namespace.** Flagger looks for the provider in the wrong place and logs an error.
> - **Treating an alert as the record of a release.** The events and the status of the `Canary` are the record.

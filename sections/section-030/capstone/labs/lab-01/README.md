---
estimated_duration: 45m
---

# Ship A Release From Registry To Primary

- **ID:** CAPSTONE
- **Slug:** ats-098-capstone-030
- **Author:** Paris Nakita Kejser
- **Type:** Astrona graded capstone

Graded capstone for the namespace `podinfo`. Read `question.md` for the task; `solution.md` is the walkthrough.

Not yet run: this capstone was written from the Flux v2.9 and Flagger 1.45
documentation and has not passed `astrona validate` or `astrona test` yet.

## Run it

```sh
astrona run -c .
astrona submit
astrona destroy ats-098-capstone-030
```

`astrona destroy` takes the environment name (`metadata.name` = `ats-098-capstone-030`), not
the config path.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition, bootstrap and grading |
| `question.md` | The task |
| `solution.md` | Step-by-step walkthrough |
| `prerequisites.md` | Assumed knowledge and what the environment provides |
| `bootstrap/` | Environment preparation and the starting state |
| `manifests/` | Gitea, tester and the lab registry, the Flux sync objects, and `repo/`: the files seeded into Git, faults included |
| `solution/` | Reference solution used by `astrona test`; `solution/repo/` holds the corrected Git files |
| `testing/` | Helpers `astrona test` runs before the reference solution |
| `validation/` | Grading scripts, one per check |

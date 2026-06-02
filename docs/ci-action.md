# CI Action & the PR visual gate (T6.4)

AmbientVRT ships a reusable GitHub Actions workflow that turns a pull request into
a **visual-regression gate**: every PR re-captures the previews in the canonical
container, compares them against the committed baselines, fails the check on any
unaccepted change, and uploads the HTML report plus the baseline/candidate/diff
PNGs as an artifact you can download and eyeball.

> The backlog (v0.2) framed this as a Forgejo Action. This repository's CI is
> GitHub Actions, so the same design is delivered as GitHub workflows under
> `.github/workflows/` and validated locally with [`act`](https://github.com/nektos/act).

## The workflows

| File | Role |
| --- | --- |
| [`.github/workflows/ambient.yml`](../.github/workflows/ambient.yml) | **Reusable** (`workflow_call`) gate: builds the shared `ambient` binary, runs `ambient test` for an example inside the canonical Flutter container, uploads `report.html` + diff PNGs. |
| [`.github/workflows/ambient-flutter.yml`](../.github/workflows/ambient-flutter.yml) | Caller: invokes the reusable gate for `examples/flutter-previews` on every push and PR. |
| [`.github/workflows/ambient-accept.yml`](../.github/workflows/ambient-accept.yml) | Accept path: on the `ambient-accept` PR label, re-bless baselines in the canonical container and push them to the PR branch. |

### Reusable inputs (`ambient.yml`)

| Input | Default | Meaning |
| --- | --- | --- |
| `example-path` | — (required) | Directory holding the example's `ambient.config.yaml`. |
| `config` | `ambient.config.yaml` | Config filename within `example-path`. |
| `canonical-env` | `''` | Stamped into `AMBIENT_CAPTURE_ENV` so in-container captures match the config's `canonicalEnv` (the authoritative fingerprint source — see [capture-env](../docker/capture-env/README.md)). |
| `artifact-name` | `ambient-report` | Name of the uploaded report artifact. |
| `comment` | `true` | Post (and update on re-runs) a sticky PR comment with the Markdown report summary. No-op on push events. |

## The PR comment

Pass/fail is terse. To make a run readable at a glance, `ambient test` writes a
Markdown twin of the HTML report — `summary.md` — next to `report.html` (so the
uploaded artifact carries both). The gate copies it into a sticky pull-request
comment via [`marocchino/sticky-pull-request-comment`](https://github.com/marocchino/sticky-pull-request-comment),
keyed by the `ambient-visual-gate` header so re-runs edit the same comment
instead of stacking new ones. The body is an overall status line, the
changed/size-changed/new/passed counts, and a table of the snapshots that need a
look (mismatch % and size); a footer links to the run where the full HTML report
artifact — with the baseline/candidate/diff triptychs — can be downloaded.

The comment needs `pull-requests: write`. The reusable workflow declares it, but
a called workflow's token is capped by its caller, so the caller
(`ambient-flutter.yml`) grants it too. The comment step is `continue-on-error`
and the post is skipped on push events, so a read-only fork-PR token never masks
the gate's real conclusion.

## How pass/fail becomes a commit status

`ambient test` exits nonzero when any snapshot is `changed` or an un-accepted
`new` (see `AmbientExitCode`). That nonzero exit fails the `ambient-test` job, and
the reusable job's conclusion is reported back to the head commit as the check
`Ambient (Flutter example) / visual / ambient test`. Add that check to branch
protection to make the gate required. The "Upload report + diffs" step runs with
`if: always()`, so the diff artifact is attached **even on a red run**.

## Why the canonical container

Pixel output only reproduces if the renderer is fixed. The gate runs in
`ghcr.io/cirruslabs/flutter:3.44.0` — the same pinned SDK the canonical
[`docker/capture-env/flutter`](../docker/capture-env/flutter/Dockerfile) image is
built `FROM`, with the example's bundled fonts. Baselines committed under
`examples/flutter-previews/.ambient/baselines/` were captured in this image, so a
clean re-capture is byte-identical and the gate is green until a widget actually
changes.

## The end-to-end PR loop

1. **Open a PR that changes a component.** The recaptured PNG differs from the
   baseline → `ambient test` reports `changed` → the check goes **red** and the
   `ambient-report-flutter` artifact carries `report.html` + the
   `baseline/candidate/diff` triptych.
2. **Accept the change**, either:
   - add the **`ambient-accept`** label to the PR — `ambient-accept.yml`
     re-captures, runs `ambient accept`, and pushes the refreshed baselines to the
     PR branch (same-repo branches only; fork PRs get a read-only token, so accept
     locally instead); **or**
   - run `ambient accept` locally in the canonical image and commit the baselines.
3. **Re-run.** The pushed baselines re-trigger the gate; the re-capture now
   matches → the check goes **green**.

## Validating locally with `act`

CI here is verified with `act` over the colima Docker socket:

```sh
export DOCKER_HOST="unix:///Users/<you>/.colima/default/docker.sock"

# Green path (matches committed baselines): job succeeds, 1-file artifact.
act push -W .github/workflows/ambient-flutter.yml \
  --artifact-server-path /tmp/ambient-art

# Red path: tweak a widget in examples/flutter-previews/lib/src/previews.dart,
# re-run the same command — the job fails and the artifact gains
# assets/changed/<hash>/{baseline,candidate,diff}.png. Revert the tweak after.
```

`--artifact-server-path` is required for `actions/upload-artifact` to land under
`act`. The label-driven `ambient-accept.yml` pushes to git and needs a real token,
so it is not `act`-validatable; the gate itself (the part that matters for the
check) is.

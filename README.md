# AmbientVRT

Framework-agnostic visual regression testing: capture component/preview snapshots, compare them against blessed baselines, and gate changes in CI. One core engine, pluggable capture adapters (Flutter and React Native).

## Layout

This is a [melos](https://melos.invertase.dev/) monorepo backed by a Dart [pub workspace](https://dart.dev/tools/pub/workspaces).

| Path | Package | Purpose |
| --- | --- | --- |
| `packages/ambient_core` | `ambient_core` | The engine: manifest model, comparator, baseline/ID logic, storage, and report generation. No adapter or CLI code. |
| `packages/ambient_cli` | `ambient_cli` | The `ambient` command (`init`, `test`, `capture`, `accept`) and the orchestrator. Depends on `ambient_core`. |
| `packages/ambient_flutter` | `ambient_flutter` | Flutter capture adapter: discovers `@Preview` widgets, renders them to PNGs, emits the core manifest. Depends on `ambient_core`. |
| `js/` | `ambientvrt` (npm) | React Native capture adapter and the npm distribution wrapper for the core binary. |
| `schemas/` | — | Versioned JSON Schemas for the manifest and `ambient.config.yaml`. |
| `docker/` | — | Pinned canonical capture environments. |
| `examples/` | — | Committed Flutter and RN sample apps used as e2e substrate. |
| `docs/` | — | Design docs and contracts. |

CLI command: `ambient` · Dart packages: `ambient_core`, `ambient_cli`, `ambient_flutter` · npm package: `ambientvrt`.

## Getting started

```sh
dart pub global activate melos
melos bootstrap   # resolves the pub workspace
melos run analyze # dart analyze across all packages
melos run workspace-test --no-select # run package tests
```

## Standalone binary

```sh
./tool/build.sh
./ambient --version
```

Tag pushes run `.github/workflows/release.yml`, which builds the Linux binary, smoke-tests it in `debian:bookworm-slim`, and publishes it as a GitHub Release asset. To exercise the same workflow locally with `act`, use an artifact directory so the build and smoke-test jobs can share the compiled binary:

```sh
act workflow_dispatch -W .github/workflows/release.yml --artifact-server-path /tmp/act-artifacts
```

## npm wrapper

The `ambientvrt` npm package is a thin wrapper around the standalone Linux binary. On Linux, `npm install` runs a `postinstall` step that downloads the matching GitHub Release asset for the package version and vendors it inside the package before `ambient` is invoked.

For local and CI validation before a tagged release exists, set `AMBIENT_BINARY_PATH=/path/to/ambient` during `npm ci`; the postinstall script copies that binary into the package instead of downloading from GitHub Releases.

To exercise the GitHub Actions CI workflow locally with `act`, use the same artifact directory so the Linux binary build job can hand its artifact to the Node wrapper smoke test:

```sh
act -W .github/workflows/ci.yml --artifact-server-path /tmp/act-artifacts
```

## React Native capture adapter

The npm package also ships the React Native capture adapter (`ambient-rn-capture`). It enumerates a built Storybook (`@storybook/react-native-web-vite`), serves it locally, and screenshots each story — across configured variants driven by Storybook globals — with Playwright/Chromium, emitting the core manifest (snapshot ids derived to match `ambient_core`). The sample app lives in `examples/rn-storybook`.

```sh
cd js && npm ci && npm run build
npx playwright install chromium
cd ../examples/rn-storybook && npm ci && npm run build-storybook
# full loop against the shared core binary:
AMBIENT_BIN=../../build/ambient ../../build/ambient test --config ambient.config.yaml
```

The `.github/workflows/rn-adapter.yml` workflow builds the shared binary, the npm package, and the example Storybook, then runs the capture + full-loop e2e tests. Validate it locally with `act` (one self-contained job, no artifacts needed):

```sh
act -W .github/workflows/rn-adapter.yml
```

## PR visual gate

`.github/workflows/ambient.yml` is a reusable workflow that runs `ambient test`
for an example inside the canonical Flutter container, fails the check on any
unaccepted visual change, and uploads `report.html` plus the baseline/candidate/diff
PNGs as an artifact. `.github/workflows/ambient-flutter.yml` calls it on every push
and PR over `examples/flutter-previews` (whose baselines are committed under
`.ambient/baselines/`). Adding the `ambient-accept` label to a PR re-blesses the
baselines via `.github/workflows/ambient-accept.yml`. See
[`docs/ci-action.md`](docs/ci-action.md) for the full PR loop and `act` commands.

```sh
act push -W .github/workflows/ambient-flutter.yml --artifact-server-path /tmp/act-artifacts
```

## License

[Apache-2.0](LICENSE).

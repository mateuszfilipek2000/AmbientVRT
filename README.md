# AmbientVRT

Framework-agnostic visual regression testing: capture component/preview snapshots, compare them against blessed baselines, and gate changes in CI. One core engine, pluggable capture adapters (Flutter today, React Native next).

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

## License

[Apache-2.0](LICENSE).

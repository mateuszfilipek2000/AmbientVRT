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
melos run test    # run package tests
```

## License

[Apache-2.0](LICENSE).

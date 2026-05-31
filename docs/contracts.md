# Contracts

AmbientVRT's two machine-readable contracts live in [`schemas/`](../schemas) as
JSON Schema (draft 2020-12):

- **`manifest.schema.json`** — the *internal* contract every capture adapter
  emits and the core consumes.
- **`config.schema.json`** — the *user-authored* `ambient.config.yaml`.

Both are validated against the fixtures in [`schemas/fixtures/`](../schemas/fixtures)
by `schemas/validate.mjs` (run `npm test` in `schemas/`). Each fixture is named
`<schema>.<valid|invalid>.json`; valid fixtures must pass, invalid ones must fail.

## Manifest (`manifest.schema.json`)

A manifest is a top-level object carrying a version plus an array of per-snapshot
entries.

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `manifestVersion` | string `^\d+\.\d+$` | yes | `major.minor`. The core refuses a manifest whose **major** it doesn't support. |
| `entries` | array of entry | yes | One record per captured snapshot. |

### Entry

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `id` | string (non-empty) | yes | Stable, semantic, platform-derived snapshot ID — **never positional**. Variant suffixes append deterministically (e.g. `components-button--primary::flutter::theme=dark`). |
| `platform` | enum `flutter` \| `react-native` | yes | Capture platform. |
| `variant` | object | no | Structured `{ theme?, brightness?, locale?, sizeName? }`. Kept structured (not baked into the ID) so the report can group/filter. `brightness` is `light` \| `dark`. |
| `width` | integer > 0 | yes | Logical width in px. |
| `height` | integer > 0 | yes | Logical height in px. |
| `dpr` | number > 0 | yes | Device pixel ratio used to render. |
| `contentHash` | string `^[a-f0-9]{64}$` | yes | SHA-256 (lowercase hex) of the PNG bytes. Powers flake detection + the rename heuristic. |
| `envFingerprint` | string (non-empty) | yes | Capture-environment identifier (canonical Docker image digest or toolchain versions). |
| `imagePath` | string (relative, `*.png`) | yes | Path to the PNG within the run dir. Must be relative (no leading `/`, no `..`) and end in `.png`. |

`additionalProperties` is **false** at both the manifest and entry level —
unknown keys are rejected so adapters can't silently drift the contract.

## Config (`config.schema.json`)

Authored as YAML (`ambient.config.yaml`); validated against this schema after
parsing to JSON.

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `adapters` | array (≥1) of adapter | yes | Capture adapters to run. |
| `storage` | storage object | yes | Where baselines live. |
| `compare` | object | no | `threshold` (0..1, default 0.1; smaller = stricter) and `perSnapshot` (id → threshold override). |
| `variants` | array of unique strings | no | Variant names to capture (e.g. `light`, `dark`). |
| `canonicalEnv` | string | no | Reference to the canonical capture-env image; captures from a different env are flagged. |

### Adapter

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `platform` | enum `flutter` \| `react-native` | yes | — |
| `projectPath` | string | required **when** `platform: flutter` | Project root. |
| `command` | array of non-empty strings | no | Override the adapter executable and fixed argv prefix. When omitted, AmbientVRT uses the platform default binary name (`ambient-flutter-capture` / `ambient-rn-capture`). |
| `storybookStaticDir` | string | required **when** `platform: react-native` | Built Storybook static dir. |

## Capture subprocess contract

The CLI orchestrator invokes each adapter as a subprocess and treats it as an
opaque executable. The adapter command comes from `adapter.command` when set,
otherwise the platform default binary name is used.

For every adapter invocation, AmbientVRT appends these arguments:

- `--out-dir <dir>` — directory where the adapter must write its PNGs and
  `manifest.json`.
- `--project-path <dir>` — for `platform: flutter`.
- `--storybook-static-dir <dir>` — for `platform: react-native`.
- `--variant <value>` — repeated once per configured variant.
- `--canonical-env <value>` — when the config sets `canonicalEnv`.

The adapter must exit non-zero on failure. On success it must emit a
schema-valid `manifest.json` in `--out-dir`, with every `imagePath` pointing to
PNG files under that same directory.

### Storage

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `backend` | enum `local` \| `s3` | yes | — |
| `path` | string | required **when** `backend: local` | Directory for local baselines. |

`additionalProperties` is **false** throughout, and the conditional `required`
rules (via `if`/`then`) mean, e.g., a `flutter` adapter missing `projectPath`
fails with a located error.

## Example `ambient.config.yaml`

```yaml
adapters:
  - platform: flutter
    projectPath: ./
    # command: [ambient-flutter-capture]
  - platform: react-native
    storybookStaticDir: ./storybook-static
    # command: [ambient-rn-capture]
storage:
  backend: local
  path: .ambient/baselines
compare:
  threshold: 0.1
  perSnapshot: {}        # id -> threshold override
variants: [light, dark]
canonicalEnv: ambient/capture-env@sha256:<digest>
```

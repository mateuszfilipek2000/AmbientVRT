# AmbientVRT

**Framework-agnostic visual regression testing.** Capture snapshots of your UI
components, compare them against blessed baselines, and gate visual changes in
CI — with one core engine and pluggable capture adapters for **Flutter** and
**React Native**.

> ⚠️ **Status: pre-1.0 (`0.1.0`).** AmbientVRT is under active development and
> APIs, config, and the manifest format may change. The prebuilt binary is
> **Linux x64/arm64 only**; on other platforms you can build from source or
> vendor your own binary (see below).

## What it does

1. **Capture** — an adapter renders your components/previews to PNGs and emits a
   normalized *manifest* describing each snapshot (id, platform, variant,
   brightness, …).
2. **Compare** — the core engine diffs each captured snapshot against its
   accepted baseline using a pixel comparator with a configurable threshold.
3. **Gate** — in CI, any unaccepted visual change fails the check and produces
   an HTML report (with an interactive diff viewer) plus baseline/candidate/diff
   PNGs as an artifact.
4. **Accept** — when a change is intentional, you bless the new captures as the
   baselines.

Baselines live alongside your code (committed under `.ambient/baselines/`) or in
S3-compatible object storage (e.g. MinIO).

## Supported adapters

| Adapter | What it captures | Distribution |
| --- | --- | --- |
| **Flutter** | `@Preview` / `MultiPreview` widgets, rendered to PNGs | `ambient_flutter` Dart package (build from source for now) |
| **React Native** | A built Storybook (`@storybook/react-native-web-vite`), screenshotted per story and variant via Playwright/Chromium | `ambientvrt` npm package (`ambient-rn-capture`) |

## Installation

### React Native (npm)

```sh
npm install --save-dev ambientvrt
npx playwright install chromium
```

On Linux, install vendors the matching `ambient` core binary automatically. On
macOS/Windows the download is skipped (the published binary is Linux-only); set
`AMBIENT_BINARY_PATH=/path/to/ambient` during install to vendor your own, or run
inside the canonical Linux container.

### Flutter / standalone binary

The Dart packages are not yet published to pub.dev. Until then, clone this
repository and build the standalone binary:

```sh
./tool/build.sh
./ambient --version
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full monorepo build.

## Quickstart

```sh
# 1. Scaffold a config in your project
ambient init                 # writes ambient.config.yaml

# 2. Edit ambient.config.yaml for your adapter (see examples/ below)

# 3. Run the visual check: capture + compare against baselines
ambient test --config ambient.config.yaml

# 4. If a change is intentional, bless the new captures
ambient accept
```

A minimal `ambient.config.yaml`:

```yaml
adapters:
  - platform: react-native
    storybookStaticDir: ./storybook-static
    # command: [ambient-rn-capture]   # defaults to the binary on PATH

storage:
  backend: local
  path: .ambient/baselines

compare:
  threshold: 0.1

variants: [light, dark]
```

Runnable end-to-end examples live in
[`examples/flutter-previews`](examples/flutter-previews) and
[`examples/rn-storybook`](examples/rn-storybook).

## CLI commands

| Command | Purpose |
| --- | --- |
| `ambient init` | Scaffold an `ambient.config.yaml`. |
| `ambient capture` | Run the configured capture adapters and emit a run directory. |
| `ambient test` | Capture, then compare against accepted baselines and emit a report. |
| `ambient accept` | Accept the current captures as blessed baselines. |

## CI / PR visual gate

`.github/workflows/ambient.yml` is a reusable workflow that runs `ambient test`
inside a pinned canonical container, fails the check on any unaccepted visual
change, posts a sticky report comment on the PR, and uploads the HTML report +
diffs. See [docs/ci-action.md](docs/ci-action.md) for the full PR loop.

## Storage backends

- **`local`** — baselines committed in your repo under `.ambient/baselines/`.
- **`s3`** — any S3-compatible store (AWS S3, MinIO, …). Credentials are read
  **only** from environment variables (default `AMBIENT_S3_ACCESS_KEY` /
  `AMBIENT_S3_SECRET_KEY`) — never from the config file. See [SECURITY.md](SECURITY.md).

## Documentation

- [docs/contracts.md](docs/contracts.md) — manifest & config contracts
- [docs/ci-action.md](docs/ci-action.md) — the CI / PR gate
- [schemas/](schemas) — versioned JSON Schemas for the manifest and config

## Contributing

Bug reports and pull requests are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md)
for the repo layout, build, and test workflows. Security issues: please follow
[SECURITY.md](SECURITY.md).

## License

[Apache-2.0](LICENSE). Provided "as is", without warranty of any kind — see
[SECURITY.md](SECURITY.md#disclaimer-of-warranty-and-liability).

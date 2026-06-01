# Canonical capture-env images

Visual snapshots are only meaningful if the environment that renders them is
fixed. These two images are the **canonical capture environments** for the two
adapters (backlog T6.1):

| Adapter | Image | Contents |
| --- | --- | --- |
| Flutter (`ambient_flutter`) | [`flutter/Dockerfile`](flutter/Dockerfile) | Pinned Flutter SDK (`3.44.0`) + a bundled, deterministic font set |
| React Native (`ambientvrt` npm) | [`rn/Dockerfile`](rn/Dockerfile) | `node:20-bookworm` + pinned Playwright (`1.60.0`) Chromium and system deps |

## How the fingerprint flows

Each image bakes a self-identifying value into the `AMBIENT_CAPTURE_ENV`
environment variable:

1. **The adapter stamps reality.** When capturing, each adapter resolves the
   `envFingerprint` it writes into `manifest.json` as, in priority order:
   1. `AMBIENT_CAPTURE_ENV` (set by these images) — authoritative for in-image
      captures;
   2. an explicit `--canonical-env` override (rarely needed);
   3. a best-effort toolchain fingerprint (e.g. `flutter:3.44.0|…`) so captures
      taken outside any canonical image are still distinguishable.
2. **The config declares the expectation.** `ambient.config.yaml`'s
   `canonicalEnv` is the value a canonical capture *should* carry.
3. **The core enforces it.** `compareRun` compares each entry's
   `envFingerprint` against the configured `canonicalEnv`. Mismatches are
   surfaced as **non-canonical captures**: a non-blocking warning on the CLI, a
   banner in the HTML report, and `CompareRunResult.nonCanonicalCaptures` for
   programmatic use. Verdicts and exit codes are unaffected.

So a capture run inside the image matches `canonicalEnv` and is silent; a run on
a developer laptop stamps the toolchain fallback, does not match, and is flagged.

## Building

```sh
# Local / human-readable tag (the Dockerfile default):
docker build -t ambient-capture-env-flutter:3.44.0 docker/capture-env/flutter
docker build -t ambient-capture-env-rn:node20-pw1.60.0 docker/capture-env/rn
```

## Making the fingerprint a true digest (CI)

A content digest is only known *after* a push, so stamping the real digest is a
two-pass build:

```sh
# 1. Build and push once to learn the digest.
docker buildx build --push -t $REGISTRY/ambient-capture-env-rn:latest docker/capture-env/rn
DIGEST=$(docker buildx imagetools inspect $REGISTRY/ambient-capture-env-rn:latest \
           --format '{{.Manifest.Digest}}')

# 2. Re-build stamping the digest into AMBIENT_CAPTURE_ENV, then push the final.
docker buildx build --push \
  --build-arg CAPTURE_ENV_FINGERPRINT="$REGISTRY/ambient-capture-env-rn@${DIGEST}" \
  -t $REGISTRY/ambient-capture-env-rn@${DIGEST} docker/capture-env/rn
```

Set `canonicalEnv` in `ambient.config.yaml` to exactly that
`$REGISTRY/...@sha256:...` reference, and run captures inside that image. The
default tag baked in for local builds is enough to exercise the mechanism (and
is what the `act`-validated workflow checks).

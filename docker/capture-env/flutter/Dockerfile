# Canonical Flutter capture-env image (backlog T6.1).
#
# This is the reproducible environment the Flutter capture adapter
# (`ambient_flutter`) is meant to run inside. Pinning the Flutter SDK and
# bundling a fixed set of fonts makes golden renders byte-stable across
# machines. The image self-identifies via AMBIENT_CAPTURE_ENV, which the
# adapter stamps onto every manifest entry's `envFingerprint`; the core then
# flags any capture whose fingerprint differs from the project's configured
# `canonicalEnv`.
#
# Keep the SDK pin in sync with docker/dart-toolchain/Dockerfile and the
# `container:` images in .github/workflows/.
FROM ghcr.io/cirruslabs/flutter:3.44.0

# Bundle a deterministic font set so text renders identically regardless of the
# host. Without this, captures drift between machines with different system
# fonts. `fc-cache` rebuilds the font cache so the new fonts are discoverable.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      fonts-dejavu-core \
      fonts-liberation2 \
      fonts-noto-core \
      fonts-noto-cjk \
      fonts-noto-color-emoji \
 && rm -rf /var/lib/apt/lists/* \
 && fc-cache -f

# Warm the Flutter tool caches so the first `flutter test` is fast.
RUN flutter --version && flutter precache --universal

# Self-identifying fingerprint stamped into every manifest entry captured inside
# this image. CI overrides CAPTURE_ENV_FINGERPRINT with the pushed image digest
# (see docker/capture-env/README.md); the default is a human-readable tag for
# local builds and `act` validation.
ARG CAPTURE_ENV_FINGERPRINT=ambient-capture-env-flutter:3.44.0
ENV AMBIENT_CAPTURE_ENV=${CAPTURE_ENV_FINGERPRINT}

WORKDIR /workspace

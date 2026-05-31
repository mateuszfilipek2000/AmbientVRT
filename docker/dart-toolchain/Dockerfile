# AmbientVRT Dart/Flutter toolchain image.
#
# This is the canonical, pinned toolchain the CI Dart job runs inside. It is
# based on the official cirruslabs Flutter image, which bundles a matching
# Dart SDK, so a single pin (the Flutter version) fixes both toolchains.
#
# CI references the pinned base tag directly via `container:` in
# .github/workflows/ci.yml (GitHub Actions cannot build a Dockerfile for the
# `container:` key). This image is the place to add anything the base lacks —
# pinned fonts, melos pre-activation, etc. — and is what later phases publish
# to a registry as the canonical capture environment (backlog T6.1) and then
# reference by digest. Keep the FROM tag below in sync with the `container:`
# image in ci.yml.
FROM ghcr.io/cirruslabs/flutter:3.44.0

# Pre-activate melos so workspace bootstrap/analyze/test scripts are available
# without a network round-trip on every job.
RUN dart pub global activate melos 7.8.0
ENV PATH="$PATH:/root/.pub-cache/bin"

# Warm the Flutter tool caches so the first analyze/test in CI is fast.
RUN flutter --version && flutter precache --universal

WORKDIR /workspace

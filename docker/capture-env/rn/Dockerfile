# Canonical React Native capture-env image (backlog T6.1).
#
# This is the reproducible environment the RN capture adapter (the npm
# `ambientvrt` package's `ambient-rn-capture`) is meant to run inside: Node on
# Debian bookworm plus a pinned Playwright with its Chromium and the system
# libraries Chromium needs. The image self-identifies via AMBIENT_CAPTURE_ENV,
# which the adapter stamps onto every manifest entry's `envFingerprint`; the
# core then flags any capture whose fingerprint differs from the project's
# configured `canonicalEnv`.
#
# Keep PLAYWRIGHT_VERSION in sync with the `playwright` range in js/package.json.
FROM node:20-bookworm

# Pin Playwright and install its Chromium build together with the apt packages
# Chromium needs (`--with-deps`). Installing the matching CLI globally lets the
# browser download resolve the exact version the adapter expects.
ENV PLAYWRIGHT_VERSION=1.60.0
RUN npm install -g "playwright@${PLAYWRIGHT_VERSION}" \
 && npx --yes "playwright@${PLAYWRIGHT_VERSION}" install --with-deps chromium

# Self-identifying fingerprint stamped into every manifest entry captured inside
# this image. CI overrides CAPTURE_ENV_FINGERPRINT with the pushed image digest
# (see docker/capture-env/README.md); the default is a human-readable tag for
# local builds and `act` validation.
ARG CAPTURE_ENV_FINGERPRINT=ambient-capture-env-rn:node20-pw1.60.0
ENV AMBIENT_CAPTURE_ENV=${CAPTURE_ENV_FINGERPRINT}

WORKDIR /workspace

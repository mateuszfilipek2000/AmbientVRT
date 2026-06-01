const assert = require('node:assert/strict');
const test = require('node:test');

const {
  resolveEnvFingerprint,
  CAPTURE_ENV_VARIABLE,
} = require('../dist/rn-adapter/emit/fingerprint.js');

function withoutCaptureEnv(run) {
  const previous = process.env[CAPTURE_ENV_VARIABLE];
  delete process.env[CAPTURE_ENV_VARIABLE];
  try {
    return run();
  } finally {
    if (previous === undefined) {
      delete process.env[CAPTURE_ENV_VARIABLE];
    } else {
      process.env[CAPTURE_ENV_VARIABLE] = previous;
    }
  }
}

test('AMBIENT_CAPTURE_ENV (the real image) wins over an explicit override', () => {
  const previous = process.env[CAPTURE_ENV_VARIABLE];
  process.env[CAPTURE_ENV_VARIABLE] = 'ambient/capture-env@sha256:real ';
  try {
    assert.equal(resolveEnvFingerprint('ignored-override'), 'ambient/capture-env@sha256:real');
  } finally {
    if (previous === undefined) {
      delete process.env[CAPTURE_ENV_VARIABLE];
    } else {
      process.env[CAPTURE_ENV_VARIABLE] = previous;
    }
  }
});

test('an explicit override is used when no image env var is set', () => {
  withoutCaptureEnv(() => {
    assert.equal(resolveEnvFingerprint('manual-override'), 'manual-override');
  });
});

test('falls back to a toolchain fingerprint outside the canonical image', () => {
  withoutCaptureEnv(() => {
    const fingerprint = resolveEnvFingerprint();
    assert.match(fingerprint, /^node:\d+\|playwright:.+\|chromium$/);
  });
});

const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const { rmSync } = require('node:fs');
const { join } = require('node:path');
const test = require('node:test');

const { EXAMPLE_DIR, ensureExampleBuild } = require('./helpers.cjs');

// The shared core binary is built by CI (or `tool/build.sh`) and passed in.
// Skip locally when it isn't available so `npm run test:e2e` still runs the
// pure-capture tests without a Dart toolchain.
const AMBIENT_BIN = process.env.AMBIENT_BIN;

function ambient(subcommand) {
  return spawnSync(AMBIENT_BIN, [subcommand, '--config', 'ambient.config.yaml'], {
    cwd: EXAMPLE_DIR,
    encoding: 'utf8',
  });
}

test(
  'full ambient test loop over the RN example using the shared core',
  { skip: AMBIENT_BIN ? false : 'set AMBIENT_BIN to the ambient binary to run' },
  async () => {
    ensureExampleBuild();
    rmSync(join(EXAMPLE_DIR, '.ambient'), { recursive: true, force: true });

    // 1. First run: every snapshot is new and un-accepted => nonzero exit.
    const firstRun = ambient('test');
    assert.notEqual(firstRun.status, 0, firstRun.stderr);
    assert.match(firstRun.stdout, /new=10/);

    // 2. Accept blesses the captures as baselines.
    const accept = ambient('accept');
    assert.equal(accept.status, 0, accept.stderr);

    // 3. Re-run: deterministic re-capture matches baselines => all pass, exit 0.
    const secondRun = ambient('test');
    assert.equal(secondRun.status, 0, `${secondRun.stdout}\n${secondRun.stderr}`);
    assert.match(secondRun.stdout, /passed=10/);
    assert.match(secondRun.stdout, /changed=0/);
  },
);

const assert = require('node:assert/strict');
const { mkdtemp, readFile, rm } = require('node:fs/promises');
const { tmpdir } = require('node:os');
const { join } = require('node:path');
const test = require('node:test');

const { captureRnStories } = require('../../dist/rn-adapter/capture/capture-all.js');
const { ensureExampleBuild, validateManifest } = require('./helpers.cjs');

const VARIANTS = ['light', 'dark'];
const EXPECTED_STORIES = 5;

async function captureInto(staticDir) {
  const outDir = await mkdtemp(join(tmpdir(), 'ambient-rn-cap-'));
  const manifest = await captureRnStories({
    staticDir,
    outDir,
    variants: VARIANTS,
    canonicalEnv: 'ambient-rn-test',
    dpr: 1,
  });
  return { outDir, manifest };
}

test('captures every story x variant, emits a schema-valid manifest', async () => {
  const staticDir = ensureExampleBuild();
  const { outDir, manifest } = await captureInto(staticDir);
  try {
    // One entry per story x variant.
    assert.equal(manifest.entries.length, EXPECTED_STORIES * VARIANTS.length);
    assert.equal(manifest.manifestVersion, '1.0');

    // Distinct, correctly-suffixed ids per variant.
    const ids = manifest.entries.map((e) => e.id);
    assert.equal(new Set(ids).size, ids.length, 'ids are unique');
    assert.ok(ids.includes('components-button--primary::react-native::brightness=light'));
    assert.ok(ids.includes('components-button--primary::react-native::brightness=dark'));

    // Every entry points at a real PNG under the out dir.
    for (const entry of manifest.entries) {
      assert.match(entry.imagePath, /^captures\/.*\.png$/);
      assert.match(entry.contentHash, /^[a-f0-9]{64}$/);
      assert.equal(entry.platform, 'react-native');
      const bytes = await readFile(join(outDir, entry.imagePath));
      assert.equal(bytes.subarray(0, 8).toString('hex'), '89504e470d0a1a0a');
    }

    // Validate against the real JSON Schema.
    const { valid, errors } = await validateManifest(manifest);
    assert.ok(valid, `manifest should validate: ${JSON.stringify(errors)}`);
  } finally {
    await rm(outDir, { recursive: true, force: true });
  }
});

test('variants driven by globals produce distinct captures', async () => {
  const staticDir = ensureExampleBuild();
  const { outDir, manifest } = await captureInto(staticDir);
  try {
    const byId = new Map(manifest.entries.map((e) => [e.id, e]));
    const light = byId.get('components-card--default::react-native::brightness=light');
    const dark = byId.get('components-card--default::react-native::brightness=dark');
    assert.ok(light && dark);
    // Dark vs light theme renders differently => different content hashes.
    assert.notEqual(light.contentHash, dark.contentHash);
  } finally {
    await rm(outDir, { recursive: true, force: true });
  }
});

test('re-capture is deterministic (per-id content hashes are stable)', async () => {
  const staticDir = ensureExampleBuild();
  const first = await captureInto(staticDir);
  const second = await captureInto(staticDir);
  try {
    const firstHashes = new Map(first.manifest.entries.map((e) => [e.id, e.contentHash]));
    for (const entry of second.manifest.entries) {
      assert.equal(entry.contentHash, firstHashes.get(entry.id), `stable hash for ${entry.id}`);
    }
  } finally {
    await rm(first.outDir, { recursive: true, force: true });
    await rm(second.outDir, { recursive: true, force: true });
  }
});

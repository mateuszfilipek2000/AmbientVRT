const assert = require('node:assert/strict');
const { createHash } = require('node:crypto');
const test = require('node:test');

const { serveStorybook } = require('../../dist/rn-adapter/storybook/server.js');
const {
  captureStory,
  launchCaptureBrowser,
} = require('../../dist/rn-adapter/capture/capture-story.js');
const { ensureExampleBuild } = require('./helpers.cjs');

const STORY_ID = 'components-button--primary';

function sha256(buffer) {
  return createHash('sha256').update(buffer).digest('hex');
}

// T5.3a: prove the Playwright capture mechanism end-to-end against the real
// example build, and prove it is byte-stable across re-runs.
test('captureStory renders a story and is byte-identical on re-run', async () => {
  const staticDir = ensureExampleBuild();
  const server = await serveStorybook(staticDir);
  const { browser, close } = await launchCaptureBrowser();
  try {
    const first = await captureStory(browser, {
      baseUrl: server.baseUrl,
      id: STORY_ID,
      dpr: 1,
    });
    const second = await captureStory(browser, {
      baseUrl: server.baseUrl,
      id: STORY_ID,
      dpr: 1,
    });

    // Valid, non-empty PNG with real dimensions.
    assert.equal(first.png.subarray(0, 8).toString('hex'), '89504e470d0a1a0a');
    assert.ok(first.width > 0 && first.height > 0, 'capture has real dimensions');
    assert.ok(first.png.length > 1000, 'capture is a non-trivial PNG');

    // Determinism: identical content hashes across runs.
    assert.equal(sha256(first.png), sha256(second.png));
  } finally {
    await close();
    await server.close();
  }
});

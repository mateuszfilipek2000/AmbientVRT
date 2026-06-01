const assert = require('node:assert/strict');
const { join } = require('node:path');
const test = require('node:test');

const { enumerateStories } = require('../dist/rn-adapter/storybook/enumerate.js');
const { serveStorybook } = require('../dist/rn-adapter/storybook/server.js');

const FIXTURE_DIR = join(__dirname, 'fixtures', 'storybook-static');

test('enumerateStories returns only type:story entries, sorted by id', async () => {
  const stories = await enumerateStories(FIXTURE_DIR);
  const ids = stories.map((s) => s.id);

  assert.deepEqual(ids, [
    'components-button--disabled',
    'components-button--primary',
    'components-button--secondary',
    'components-card--default',
    'foundations-typography--greetings',
  ]);

  const primary = stories.find((s) => s.id === 'components-button--primary');
  assert.deepEqual(primary, {
    id: 'components-button--primary',
    title: 'Components/Button',
    name: 'Primary',
  });
});

test('enumerateStories throws a helpful error when index.json is missing', async () => {
  await assert.rejects(
    () => enumerateStories(join(__dirname, 'fixtures', 'nope')),
    /storybook build/i,
  );
});

test('serveStorybook serves iframe.html ignoring query strings', async () => {
  const server = await serveStorybook(FIXTURE_DIR);
  try {
    const res = await fetch(
      `${server.baseUrl}/iframe.html?id=components-button--primary&viewMode=story`,
    );
    assert.equal(res.status, 200);
    assert.match(res.headers.get('content-type') ?? '', /text\/html/);
    const body = await res.text();
    assert.ok(body.length > 0);
  } finally {
    await server.close();
  }
});

test('serveStorybook serves index.json as application/json', async () => {
  const server = await serveStorybook(FIXTURE_DIR);
  try {
    const res = await fetch(`${server.baseUrl}/index.json`);
    assert.equal(res.status, 200);
    assert.match(res.headers.get('content-type') ?? '', /application\/json/);
    const json = await res.json();
    assert.equal(json.v, 5);
  } finally {
    await server.close();
  }
});

test('serveStorybook rejects path traversal', async () => {
  const server = await serveStorybook(FIXTURE_DIR);
  try {
    const res = await fetch(`${server.baseUrl}/../../package.json`);
    // Either normalized away (404) or refused (403); never 200 with escape.
    assert.notEqual(res.status, 200);
  } finally {
    await server.close();
  }
});

const assert = require('node:assert/strict');
const test = require('node:test');

const {
  reactNativeSnapshotId,
  variantIdSegments,
  plannedImagePath,
} = require('../dist/rn-adapter/snapshot-id.js');
const { resolveVariants, resolveVariant } = require('../dist/rn-adapter/variants.js');

test('story id is preserved verbatim as the base, suffixed by platform', () => {
  assert.equal(
    reactNativeSnapshotId({ storyId: 'components-button--primary' }),
    'components-button--primary::react-native',
  );
});

test('explicit override replaces the base and is rename-proof', () => {
  assert.equal(
    reactNativeSnapshotId({ storyId: 'old-id', idOverride: 'stable-id' }),
    'stable-id::react-native',
  );
});

test('variant segments are canonical (sorted by key) and order-independent', () => {
  // Same set of dimensions => same id regardless of declaration order.
  const a = reactNativeSnapshotId({
    storyId: 's',
    variant: { theme: 'corp', brightness: 'dark' },
  });
  const b = reactNativeSnapshotId({
    storyId: 's',
    variant: { brightness: 'dark', theme: 'corp' },
  });
  assert.equal(a, b);
  assert.equal(a, 's::react-native::brightness=dark::theme=corp');
});

test('variantIdSegments returns [] for undefined', () => {
  assert.deepEqual(variantIdSegments(undefined), []);
});

test('dark variant resolves to a theme global + brightness dimension', () => {
  assert.deepEqual(resolveVariant('dark'), {
    name: 'dark',
    globals: { theme: 'dark' },
    dimensions: { brightness: 'dark' },
  });
});

test('no configured variants yields a single default variant', () => {
  assert.deepEqual(resolveVariants([]), [{ name: null, globals: {}, dimensions: {} }]);
});

test('plannedImagePath is deterministic, slugged, and under captures/', () => {
  const id = 'components-button--primary::react-native::brightness=dark';
  const path = plannedImagePath(id);
  assert.equal(path, plannedImagePath(id));
  assert.match(
    path,
    /^captures\/components_button_primary_react_native_brightness_dark-[a-f0-9]{12}\.png$/,
  );
});

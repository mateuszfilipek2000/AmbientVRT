import { createHash } from 'node:crypto';

import type { VariantDimensions } from './types';

/**
 * Snapshot-ID derivation for React Native, mirroring
 * `ambient_core/lib/src/baseline/id.dart`. This logic is **frozen-by-default**:
 * it must produce byte-identical ids to the Dart core, because both feed the
 * same baseline store. Extend additively; never change an existing input's
 * output.
 */

/** Separator between snapshot-ID segments (matches `idSegmentSeparator`). */
export const ID_SEGMENT_SEPARATOR = '::';

/** Platform wire name for React Native captures. */
export const REACT_NATIVE_PLATFORM = 'react-native';

/**
 * Canonical, order-independent variant `key=value` segments. Keys are sorted so
 * the result depends only on the set of dimensions, never insertion order —
 * matching `variantIdSegments` in the Dart core.
 */
export function variantIdSegments(variant?: VariantDimensions): string[] {
  if (variant === undefined) {
    return [];
  }
  const dims: Record<string, string> = {};
  if (variant.brightness !== undefined) dims.brightness = variant.brightness;
  if (variant.locale !== undefined) dims.locale = variant.locale;
  if (variant.sizeName !== undefined) dims.sizeName = variant.sizeName;
  if (variant.theme !== undefined) dims.theme = variant.theme;
  return Object.keys(dims)
    .sort()
    .map((key) => `${key}=${dims[key]}`);
}

/**
 * Full snapshot ID for a React Native story: the Storybook story id verbatim
 * (or an explicit override), then `::react-native`, then canonical variant
 * segments.
 */
export function reactNativeSnapshotId(options: {
  storyId: string;
  variant?: VariantDimensions;
  idOverride?: string;
}): string {
  const override = options.idOverride?.trim();
  const base = override !== undefined && override.length > 0 ? override : options.storyId;
  if (base.trim().length === 0) {
    throw new Error('storyId (or idOverride) must not be blank');
  }
  return [base, REACT_NATIVE_PLATFORM, ...variantIdSegments(options.variant)].join(
    ID_SEGMENT_SEPARATOR,
  );
}

/**
 * Deterministic, filesystem-safe relative image path for a snapshot id,
 * mirroring `plannedImagePathForSnapshotId` in the Flutter adapter so both
 * adapters lay captures out identically: `captures/<slug>-<sha12>.png`.
 */
export function plannedImagePath(snapshotId: string): string {
  const slug = snapshotId
    .replace(/[^A-Za-z0-9]+/g, '_')
    .replace(/_+/g, '_')
    .replace(/^_|_$/g, '')
    .toLowerCase();
  const digest = createHash('sha256').update(snapshotId, 'utf8').digest('hex').slice(0, 12);
  return `captures/${slug}-${digest}.png`;
}

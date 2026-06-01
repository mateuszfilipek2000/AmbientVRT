import type { Variant } from './types';

/** The default, no-globals variant captured when none are configured. */
export const DEFAULT_VARIANT: Variant = { name: null, globals: {}, dimensions: {} };

/**
 * Resolves a configured variant name into the Storybook globals that drive it
 * and the structured dimensions recorded on the manifest.
 *
 * Convention (matching the example's `theme` global): a variant sets the
 * `theme` global to its name. `light`/`dark` are recorded on the semantic
 * `brightness` axis (mirroring the Flutter adapter, where dark previews carry
 * `brightness: dark`); any other name is recorded on the `theme` axis.
 */
export function resolveVariant(name: string): Variant {
  if (name === 'light' || name === 'dark') {
    return { name, globals: { theme: name }, dimensions: { brightness: name } };
  }
  return { name, globals: { theme: name }, dimensions: { theme: name } };
}

/**
 * Resolves the configured variant names into a list of {@link Variant}s. With
 * no names configured, a single default (no-globals) variant is captured.
 */
export function resolveVariants(names: readonly string[]): Variant[] {
  if (names.length === 0) {
    return [DEFAULT_VARIANT];
  }
  return names.map(resolveVariant);
}

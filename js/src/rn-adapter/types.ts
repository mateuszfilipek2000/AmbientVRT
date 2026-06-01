/** A single Storybook story discovered from a built `index.json`. */
export interface Story {
  /** Storybook story id, e.g. `components-button--primary`. Used verbatim as the snapshot base id. */
  id: string;
  /** Grouping title, e.g. `Components/Button`. */
  title: string;
  /** Story export name, e.g. `Primary`. */
  name: string;
}

/**
 * A capture variant: a named set of Storybook globals applied via the
 * `globals` URL param, plus the structured dimensions recorded on the manifest.
 *
 * The default (no globals) variant is represented by `name: null`.
 */
export interface Variant {
  /** Variant name as configured (e.g. `dark`), or `null` for the default. */
  name: string | null;
  /** Storybook globals to apply, e.g. `{ theme: 'dark' }`. */
  globals: Record<string, string>;
  /** Structured variant dimensions recorded on the manifest entry. */
  dimensions: VariantDimensions;
}

/** Structured variant dimensions mirrored onto the manifest entry. */
export interface VariantDimensions {
  theme?: string;
  brightness?: 'light' | 'dark';
  locale?: string;
  sizeName?: string;
}

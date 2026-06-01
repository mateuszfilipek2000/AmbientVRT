import type { VariantDimensions } from '../types';

/** Manifest major.minor this adapter emits. Mirrors `ManifestVersion.current`. */
export const MANIFEST_VERSION = '1.0';

/** One captured snapshot, matching `schemas/manifest.schema.json` entry shape. */
export interface ManifestEntry {
  id: string;
  platform: 'react-native';
  variant?: VariantDimensions;
  width: number;
  height: number;
  dpr: number;
  contentHash: string;
  envFingerprint: string;
  imagePath: string;
}

/** Top-level manifest, matching `schemas/manifest.schema.json`. */
export interface Manifest {
  manifestVersion: string;
  entries: ManifestEntry[];
}

/** True when no variant dimension is set (so the key is omitted from the entry). */
export function isEmptyVariant(variant: VariantDimensions): boolean {
  return (
    variant.theme === undefined &&
    variant.brightness === undefined &&
    variant.locale === undefined &&
    variant.sizeName === undefined
  );
}

/** Assembles a manifest from entries, sorting them by id for determinism. */
export function buildManifest(entries: ManifestEntry[]): Manifest {
  const sorted = [...entries].sort((a, b) => a.id.localeCompare(b.id));
  return { manifestVersion: MANIFEST_VERSION, entries: sorted };
}

/** Serializes a manifest to the same 2-space-indented JSON the core uses. */
export function serializeManifest(manifest: Manifest): string {
  return `${JSON.stringify(manifest, null, 2)}\n`;
}

import { createHash } from 'node:crypto';
import { mkdir, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';

import { resolveEnvFingerprint } from '../emit/fingerprint';
import {
  buildManifest,
  isEmptyVariant,
  serializeManifest,
  type Manifest,
  type ManifestEntry,
} from '../emit/manifest';
import { plannedImagePath, reactNativeSnapshotId } from '../snapshot-id';
import { enumerateStories } from '../storybook/enumerate';
import { serveStorybook } from '../storybook/server';
import type { VariantDimensions } from '../types';
import { resolveVariants } from '../variants';
import { captureStory, DEFAULT_VIEWPORT, launchCaptureBrowser } from './capture-story';

/** Default device pixel ratio for RN captures (the contract has no `--dpr`). */
export const DEFAULT_RN_DPR = 2;

export interface CaptureRnOptions {
  /** Built Storybook static dir (contains `index.json` + `iframe.html`). */
  staticDir: string;
  /** Directory to write PNGs + `manifest.json` into (the contract `--out-dir`). */
  outDir: string;
  /** Configured variant names (the repeated `--variant` flags). */
  variants?: readonly string[];
  /** Canonical capture-env reference, stamped as `envFingerprint`. */
  canonicalEnv?: string;
  /** Device pixel ratio. */
  dpr?: number;
  /** Logical viewport. */
  viewport?: { width: number; height: number };
  /** Progress sink (defaults to no-op). */
  log?: (message: string) => void;
}

function dimensionsOrUndefined(variant: VariantDimensions): VariantDimensions | undefined {
  return isEmptyVariant(variant) ? undefined : variant;
}

/**
 * Captures every story × configured variant from a built Storybook into
 * `outDir`, then writes a schema-valid `manifest.json`. One PNG per
 * story/variant pair, named by its derived snapshot id; entries are sorted by
 * id for deterministic output.
 */
export async function captureRnStories(options: CaptureRnOptions): Promise<Manifest> {
  const dpr = options.dpr ?? DEFAULT_RN_DPR;
  const viewport = options.viewport ?? DEFAULT_VIEWPORT;
  const log = options.log ?? (() => {});

  const stories = await enumerateStories(options.staticDir);
  const variants = resolveVariants(options.variants ?? []);
  const envFingerprint = resolveEnvFingerprint(options.canonicalEnv);

  await mkdir(options.outDir, { recursive: true });
  const server = await serveStorybook(options.staticDir);
  const { browser, close } = await launchCaptureBrowser();
  const entries: ManifestEntry[] = [];

  try {
    for (const story of stories) {
      for (const variant of variants) {
        const dimensions = dimensionsOrUndefined(variant.dimensions);
        const id = reactNativeSnapshotId({ storyId: story.id, variant: dimensions });
        const imagePath = plannedImagePath(id);

        const result = await captureStory(browser, {
          baseUrl: server.baseUrl,
          id: story.id,
          globals: variant.globals,
          dpr,
          viewport,
        });

        const absolutePath = join(options.outDir, imagePath);
        await mkdir(dirname(absolutePath), { recursive: true });
        await writeFile(absolutePath, result.png);

        entries.push({
          id,
          platform: 'react-native',
          ...(dimensions !== undefined ? { variant: dimensions } : {}),
          width: result.width,
          height: result.height,
          dpr,
          contentHash: createHash('sha256').update(result.png).digest('hex'),
          envFingerprint,
          imagePath,
        });
        log(`captured ${id}`);
      }
    }
  } finally {
    await close();
    await server.close();
  }

  const manifest = buildManifest(entries);
  await writeFile(join(options.outDir, 'manifest.json'), serializeManifest(manifest));
  return manifest;
}

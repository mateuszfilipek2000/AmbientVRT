import { chromium, type Browser, type BrowserContext, type Page } from 'playwright';

import { buildStoryUrl } from './story-url';

/** Default logical viewport. Stories render top-left aligned within it. */
export const DEFAULT_VIEWPORT = { width: 800, height: 600 } as const;

export interface CaptureBrowser {
  browser: Browser;
  close: () => Promise<void>;
}

/**
 * Launches a headless Chromium tuned for deterministic captures: no GPU
 * variance, reduced motion. One browser is reused across all stories/variants.
 */
export async function launchCaptureBrowser(): Promise<CaptureBrowser> {
  const browser = await chromium.launch({
    headless: true,
    args: ['--disable-lcd-text', '--force-color-profile=srgb'],
  });
  return { browser, close: () => browser.close() };
}

export interface CaptureStoryOptions {
  /** Base URL of the served Storybook build (no trailing slash needed). */
  baseUrl: string;
  /** Storybook story id. */
  id: string;
  /** Storybook globals for this variant (e.g. `{ theme: 'dark' }`). */
  globals?: Record<string, string>;
  /** Device pixel ratio to render at. */
  dpr: number;
  /** Logical viewport size. */
  viewport?: { width: number; height: number };
}

export interface CaptureResult {
  /** Encoded PNG bytes of the `#storybook-root` element. */
  png: Buffer;
  /** Physical pixel width of the captured image. */
  width: number;
  /** Physical pixel height of the captured image. */
  height: number;
}

/** PNG signature + IHDR parsing for width/height (avoids an image dependency). */
function readPngSize(png: Buffer): { width: number; height: number } {
  // IHDR width/height are big-endian uint32 at byte offsets 16 and 20.
  return { width: png.readUInt32BE(16), height: png.readUInt32BE(20) };
}

/**
 * Opens a single story in isolation and screenshots the `#storybook-root`
 * element to a PNG. Waits for fonts, network idle, and the root element so the
 * capture is stable; disables animations so re-runs are byte-identical.
 *
 * The caller owns the {@link Browser} (via {@link launchCaptureBrowser}); this
 * creates and disposes a fresh context per call to isolate state.
 */
export async function captureStory(
  browser: Browser,
  options: CaptureStoryOptions,
): Promise<CaptureResult> {
  const { baseUrl, id, globals = {}, dpr } = options;
  const viewport = options.viewport ?? DEFAULT_VIEWPORT;

  const context: BrowserContext = await browser.newContext({
    viewport,
    deviceScaleFactor: dpr,
    reducedMotion: 'reduce',
  });
  const page: Page = await context.newPage();
  try {
    await page.goto(buildStoryUrl(baseUrl, id, globals), {
      waitUntil: 'networkidle',
    });

    const root = page.locator('#storybook-root');
    await root.waitFor({ state: 'visible' });
    // String expressions (not closures) so the browser globals these touch
    // don't require pulling the DOM lib into this node-only package's types.
    await page.evaluate('document.fonts.ready');
    // Settle one more frame after fonts resolve, then freeze animations.
    await page.evaluate('new Promise((resolve) => requestAnimationFrame(() => resolve(true)))');

    const png = await root.screenshot({ animations: 'disabled', type: 'png' });
    const { width, height } = readPngSize(png);
    return { png, width, height };
  } finally {
    await context.close();
  }
}

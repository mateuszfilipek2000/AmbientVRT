import { createRequire } from 'node:module';

const requireFromHere = createRequire(__filename);

/**
 * Resolves the capture-environment fingerprint stamped onto every manifest
 * entry. Prefers the configured `canonicalEnv` (the canonical capture-env image
 * digest). Otherwise derives a best-effort, deterministic fingerprint from the
 * Node + Playwright toolchain so non-canonical captures are at least
 * distinguishable.
 */
export function resolveEnvFingerprint(canonicalEnv?: string): string {
  if (canonicalEnv !== undefined && canonicalEnv.trim().length > 0) {
    return canonicalEnv;
  }
  let playwrightVersion = 'unknown';
  try {
    playwrightVersion = (requireFromHere('playwright/package.json') as { version: string }).version;
  } catch {
    // Best-effort only.
  }
  const nodeMajor = process.versions.node.split('.')[0];
  return `node:${nodeMajor}|playwright:${playwrightVersion}|chromium`;
}

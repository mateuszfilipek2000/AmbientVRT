import { createRequire } from 'node:module';

const requireFromHere = createRequire(__filename);

/**
 * Environment variable the canonical capture-env image bakes in to identify
 * itself (its digest or reference). See `docker/capture-env/`.
 */
export const CAPTURE_ENV_VARIABLE = 'AMBIENT_CAPTURE_ENV';

/**
 * Resolves the capture-environment fingerprint stamped onto every manifest
 * entry, recording the *actual* environment the capture ran in so the core can
 * flag captures taken outside the canonical image.
 *
 * Priority:
 * 1. The `AMBIENT_CAPTURE_ENV` env var, set by the canonical capture-env image
 *    — authoritative for in-image captures.
 * 2. An explicit `--canonical-env` override (rarely needed; for callers that
 *    cannot set the env var).
 * 3. A best-effort, deterministic Node + Playwright toolchain fingerprint, so
 *    non-canonical captures are still distinguishable.
 */
export function resolveEnvFingerprint(canonicalEnv?: string): string {
  const fromImage = process.env[CAPTURE_ENV_VARIABLE];
  if (fromImage !== undefined && fromImage.trim().length > 0) {
    return fromImage.trim();
  }
  if (canonicalEnv !== undefined && canonicalEnv.trim().length > 0) {
    return canonicalEnv.trim();
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

import { parseArgs } from 'node:util';
import { resolve } from 'node:path';

import { captureRnStories } from './capture/capture-all';

/**
 * Entry point for the `ambient-rn-capture` adapter, conforming to the
 * AmbientVRT capture subprocess contract (see `docs/contracts.md`). The
 * orchestrator appends `--out-dir`, `--storybook-static-dir`, `--variant`
 * (repeated), and `--canonical-env`. Returns the process exit code.
 */
export async function runRnCapture(
  argv: readonly string[],
  stderr: Pick<NodeJS.WriteStream, 'write'> = process.stderr,
  stdout: Pick<NodeJS.WriteStream, 'write'> = process.stdout,
): Promise<number> {
  let parsed;
  try {
    parsed = parseArgs({
      args: [...argv],
      options: {
        'out-dir': { type: 'string' },
        'storybook-static-dir': { type: 'string' },
        variant: { type: 'string', multiple: true },
        'canonical-env': { type: 'string' },
        dpr: { type: 'string' },
      },
      allowPositionals: false,
    });
  } catch (error) {
    stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
    return 64;
  }

  const { values } = parsed;
  const outDir = values['out-dir'];
  const staticDir = values['storybook-static-dir'];

  if (outDir === undefined) {
    stderr.write('Missing required --out-dir.\n');
    return 64;
  }
  if (staticDir === undefined) {
    stderr.write('Missing required --storybook-static-dir.\n');
    return 64;
  }

  const dpr = values.dpr !== undefined ? Number.parseFloat(values.dpr) : undefined;
  if (dpr !== undefined && (!Number.isFinite(dpr) || dpr <= 0)) {
    stderr.write(`Invalid --dpr value: ${values.dpr}\n`);
    return 64;
  }

  try {
    const manifest = await captureRnStories({
      staticDir: resolve(staticDir),
      outDir: resolve(outDir),
      variants: values.variant ?? [],
      canonicalEnv: values['canonical-env'],
      dpr,
      log: (message) => stdout.write(`${message}\n`),
    });
    stdout.write(`Captured ${manifest.entries.length} React Native snapshots.\n`);
    return 0;
  } catch (error) {
    stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
    return 1;
  }
}

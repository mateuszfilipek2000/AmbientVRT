import { readFileSync } from 'node:fs';
import { join } from 'node:path';

/**
 * Reads the package version from the published `package.json`.
 *
 * The compiled entrypoint lives at `dist/index.js`, so `package.json` sits one
 * directory up regardless of whether we run from source or the built output.
 */
export function getVersion(): string {
  const pkgPath = join(__dirname, '..', 'package.json');
  const pkg = JSON.parse(readFileSync(pkgPath, 'utf8')) as { version: string };
  return pkg.version;
}

/**
 * Placeholder CLI entrypoint.
 *
 * For now this only answers `--version`. The real `ambient` command ships as a
 * native binary; this npm package will grow into the thin wrapper that resolves
 * and forwards to it (backlog T3.4) plus the React Native capture adapter.
 *
 * @returns the process exit code.
 */
export function run(argv: string[]): number {
  if (argv.includes('--version') || argv.includes('-v')) {
    process.stdout.write(`${getVersion()}\n`);
    return 0;
  }

  process.stdout.write(
    'ambient (ambientvrt) — placeholder CLI.\n' +
      'The real command ships as a native binary that this package will wrap.\n' +
      'Try `ambient --version`.\n',
  );
  return 0;
}

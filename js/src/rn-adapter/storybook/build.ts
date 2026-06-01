import { spawn } from 'node:child_process';
import { access } from 'node:fs/promises';
import { join } from 'node:path';

export interface BuildStorybookOptions {
  /** Project root containing `.storybook/` and the `storybook` dependency. */
  projectPath: string;
  /** Output directory for the static build (passed to `storybook build -o`). */
  outputDir: string;
  /** Override the storybook executable/argv prefix. Defaults to `npx storybook`. */
  command?: readonly string[];
  /** Stream forwarded child stdout/stderr to. Defaults to the parent process. */
  stdio?: 'inherit' | 'ignore';
}

/**
 * Runs `storybook build` for `projectPath`, emitting the static site (incl.
 * `index.json`) into `outputDir`. Resolves once the build exits 0; rejects
 * otherwise.
 *
 * Used by the example/test harness to (re)produce a static build. At capture
 * time the adapter is normally handed an already-built `--storybook-static-dir`.
 */
export async function buildStorybook(options: BuildStorybookOptions): Promise<string> {
  const { projectPath, outputDir, stdio = 'inherit' } = options;
  const command = options.command ?? ['npx', 'storybook', 'build'];
  const [executable, ...prefix] = command;
  const args = [...prefix, '--output-dir', outputDir];

  await new Promise<void>((resolve, reject) => {
    const child = spawn(executable, args, {
      cwd: projectPath,
      stdio,
      shell: false,
    });
    child.once('error', reject);
    child.once('close', (code) => {
      if (code === 0) {
        resolve();
      } else {
        reject(new Error(`\`${command.join(' ')}\` exited with code ${code ?? 'null'}.`));
      }
    });
  });

  try {
    await access(join(outputDir, 'index.json'));
  } catch (cause) {
    throw new Error(`Storybook build completed but ${join(outputDir, 'index.json')} is missing.`, {
      cause,
    });
  }

  return outputDir;
}

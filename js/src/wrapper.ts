import { spawnSync, type SpawnSyncReturns } from 'node:child_process';
import { existsSync } from 'node:fs';
import { constants as osConstants } from 'node:os';
import { join, resolve } from 'node:path';

const LOCAL_BINARY_DIRECTORY = 'vendor';
const LOCAL_BINARY_NAMES = {
  arm64: 'ambient-linux-arm64',
  x64: 'ambient-linux-x64',
} as const;

type SupportedArch = keyof typeof LOCAL_BINARY_NAMES;
type SignalNumbers = Partial<Record<NodeJS.Signals, number>>;
type Writable = Pick<NodeJS.WriteStream, 'write'>;

interface ResolveBinaryPathOptions {
  env?: NodeJS.ProcessEnv;
  platform?: NodeJS.Platform;
  arch?: string;
  dirname?: string;
}

interface RunOptions extends ResolveBinaryPathOptions {
  spawn?: typeof spawnSync;
  reemitSignal?: (signal: NodeJS.Signals) => void;
  signalNumbers?: SignalNumbers;
  stderr?: Writable;
}

function isSupportedArch(arch: string): arch is SupportedArch {
  return arch === 'arm64' || arch === 'x64';
}

function getOverrideBinaryPath(env: NodeJS.ProcessEnv): string | null {
  const override = env.AMBIENT_BINARY_PATH;
  return override ? resolve(override) : null;
}

function formatError(error: unknown): string {
  if (error instanceof Error) {
    return error.message;
  }

  return String(error);
}

function signalExitCode(signal: NodeJS.Signals, signalNumbers: SignalNumbers): number {
  const signalNumber = signalNumbers[signal];
  return typeof signalNumber === 'number' ? 128 + signalNumber : 1;
}

export function resolveBinaryPath(options: ResolveBinaryPathOptions = {}): string {
  const env = options.env ?? process.env;
  const overrideBinaryPath = getOverrideBinaryPath(env);

  if (overrideBinaryPath !== null) {
    return overrideBinaryPath;
  }

  const platform = options.platform ?? process.platform;
  const arch = options.arch ?? process.arch;

  if (platform !== 'linux') {
    throw new Error(
      `ambientvrt currently provides prebuilt binaries only for Linux (got ${platform}-${arch}). Set AMBIENT_BINARY_PATH to use a custom binary.`,
    );
  }

  if (!isSupportedArch(arch)) {
    throw new Error(
      `ambientvrt currently provides Linux binaries for x64 and arm64 only (got linux-${arch}).`,
    );
  }

  const dirname = options.dirname ?? __dirname;
  const binaryPath = join(dirname, '..', LOCAL_BINARY_DIRECTORY, LOCAL_BINARY_NAMES[arch]);

  if (!existsSync(binaryPath)) {
    throw new Error(
      `The Ambient binary is not installed at ${binaryPath}. Reinstall ambientvrt or set AMBIENT_BINARY_PATH.`,
    );
  }

  return binaryPath;
}

export function run(argv: readonly string[], options: RunOptions = {}): number {
  const spawn = options.spawn ?? spawnSync;
  const stderr = options.stderr ?? process.stderr;
  const reemitSignal =
    options.reemitSignal ??
    ((signal: NodeJS.Signals) => {
      process.kill(process.pid, signal);
    });
  const signalNumbers = options.signalNumbers ?? (osConstants.signals as SignalNumbers);

  try {
    const binaryPath = resolveBinaryPath(options);
    const result = spawn(binaryPath, [...argv], {
      stdio: 'inherit',
    }) as SpawnSyncReturns<Buffer>;

    if (result.error !== undefined) {
      throw result.error;
    }

    if (result.signal !== null) {
      reemitSignal(result.signal);
      return signalExitCode(result.signal, signalNumbers);
    }

    if (result.status !== null) {
      return result.status;
    }

    throw new Error('The Ambient binary exited without a status code.');
  } catch (error) {
    stderr.write(`${formatError(error)}\n`);
    return 1;
  }
}

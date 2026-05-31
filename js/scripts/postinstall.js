const { createWriteStream, promises: fs } = require('node:fs');
const { dirname, join, resolve } = require('node:path');
const { Readable } = require('node:stream');
const { finished } = require('node:stream/promises');

const DEFAULT_RELEASE_BASE_URL =
  'https://github.com/mateuszfilipek2000/AmbientVRT/releases/download';
const LOCAL_BINARY_DIRECTORY = 'vendor';
const LOCAL_BINARY_NAMES = {
  arm64: 'ambient-linux-arm64',
  x64: 'ambient-linux-x64',
};

function getLocalBinaryName(arch) {
  return LOCAL_BINARY_NAMES[arch] ?? `ambient-linux-${arch}`;
}

function trimTrailingSlashes(value) {
  return value.replace(/\/+$/, '');
}

async function readPackageVersion(packageRoot) {
  const packageJsonPath = join(packageRoot, 'package.json');
  const packageJson = JSON.parse(await fs.readFile(packageJsonPath, 'utf8'));
  return packageJson.version;
}

async function copyBinary(sourcePath, targetPath) {
  await fs.mkdir(dirname(targetPath), { recursive: true });
  await fs.copyFile(resolve(sourcePath), targetPath);
  await fs.chmod(targetPath, 0o755);
}

async function downloadBinary(url, targetPath) {
  const tempPath = `${targetPath}.tmp`;

  await fs.mkdir(dirname(targetPath), { recursive: true });
  await fs.rm(tempPath, { force: true });

  try {
    const response = await fetch(url, {
      headers: {
        'user-agent': 'ambientvrt-postinstall',
      },
    });

    if (!response.ok) {
      throw new Error(`Download failed with ${response.status} ${response.statusText}.`);
    }

    if (response.body === null) {
      throw new Error('Download succeeded but returned no response body.');
    }

    const fileStream = createWriteStream(tempPath, { mode: 0o755 });
    await finished(Readable.fromWeb(response.body).pipe(fileStream));
    await fs.chmod(tempPath, 0o755);
    await fs.rename(tempPath, targetPath);
  } catch (error) {
    await fs.rm(tempPath, { force: true });
    throw error;
  }
}

async function main() {
  const packageRoot = resolve(__dirname, '..');
  const binaryFileName = getLocalBinaryName(process.arch);
  const targetPath = join(packageRoot, LOCAL_BINARY_DIRECTORY, binaryFileName);
  const overrideBinaryPath = process.env.AMBIENT_BINARY_PATH;

  if (overrideBinaryPath) {
    await copyBinary(overrideBinaryPath, targetPath);
    console.log(`Installed Ambient binary from ${resolve(overrideBinaryPath)}.`);
    return;
  }

  if (process.platform !== 'linux') {
    console.warn(
      `Skipping Ambient binary download on ${process.platform}-${process.arch}; the published ambientvrt binary is Linux-only. Set AMBIENT_BINARY_PATH to vendor a custom binary for local development.`,
    );
    return;
  }

  if (!(process.arch in LOCAL_BINARY_NAMES)) {
    throw new Error(
      `ambientvrt currently publishes Linux binaries for x64 and arm64 only (got linux-${process.arch}).`,
    );
  }

  const version = await readPackageVersion(packageRoot);
  const tagName = `v${version}`;
  const assetName = `ambient-v${version}-linux-${process.arch}`;
  const releaseBaseUrl = trimTrailingSlashes(
    process.env.AMBIENT_RELEASE_BASE_URL ?? DEFAULT_RELEASE_BASE_URL,
  );
  const downloadUrl = `${releaseBaseUrl}/${tagName}/${assetName}`;

  await downloadBinary(downloadUrl, targetPath);
  console.log(`Installed Ambient binary from ${downloadUrl}.`);
}

main().catch((error) => {
  const message = error instanceof Error ? error.message : String(error);
  console.error(`ambientvrt postinstall failed: ${message}`);
  process.exitCode = 1;
});

const { spawnSync } = require('node:child_process');
const { createRequire } = require('node:module');
const { existsSync, readFileSync } = require('node:fs');
const { join, resolve } = require('node:path');
const { pathToFileURL } = require('node:url');

const REPO_ROOT = resolve(__dirname, '..', '..', '..');
const EXAMPLE_DIR = join(REPO_ROOT, 'examples', 'rn-storybook');
const STATIC_DIR = join(EXAMPLE_DIR, 'storybook-static');
const SCHEMAS_DIR = join(REPO_ROOT, 'schemas');

/**
 * Ensures the rn-storybook example has a static build, building it once if
 * missing. Returns the absolute `storybook-static` path.
 */
function ensureExampleBuild() {
  if (existsSync(join(STATIC_DIR, 'index.json'))) {
    return STATIC_DIR;
  }
  if (!existsSync(join(EXAMPLE_DIR, 'node_modules'))) {
    const install = spawnSync('npm', ['install'], { cwd: EXAMPLE_DIR, stdio: 'inherit' });
    if (install.status !== 0) {
      throw new Error('Failed to install the rn-storybook example dependencies.');
    }
  }
  const build = spawnSync('npm', ['run', 'build-storybook'], {
    cwd: EXAMPLE_DIR,
    stdio: 'inherit',
  });
  if (build.status !== 0) {
    throw new Error('Failed to build the rn-storybook example.');
  }
  return STATIC_DIR;
}

/**
 * Validates a manifest object against `schemas/manifest.schema.json` using the
 * exact ajv setup the schemas package uses. Returns `{ valid, errors }`.
 */
async function validateManifest(manifest) {
  const requireFromSchemas = createRequire(join(SCHEMAS_DIR, 'package.json'));
  const { default: Ajv } = await import(
    pathToFileURL(requireFromSchemas.resolve('ajv/dist/2020.js')).href
  );
  const addFormatsModule = await import(
    pathToFileURL(requireFromSchemas.resolve('ajv-formats')).href
  );
  const addFormats = addFormatsModule.default ?? addFormatsModule;

  const ajv = new Ajv({ allErrors: true, strict: true, strictRequired: false });
  addFormats(ajv);
  const schema = JSON.parse(readFileSync(join(SCHEMAS_DIR, 'manifest.schema.json'), 'utf8'));
  const validate = ajv.compile(schema);
  const valid = validate(manifest);
  return { valid, errors: validate.errors };
}

module.exports = { EXAMPLE_DIR, STATIC_DIR, SCHEMAS_DIR, ensureExampleBuild, validateManifest };

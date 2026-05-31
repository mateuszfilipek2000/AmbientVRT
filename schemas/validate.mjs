// Validates the AmbientVRT JSON Schemas and their fixtures.
//
//   - both schemas compile (i.e. are themselves valid JSON Schema), and
//   - every `*.valid.json` fixture validates, and
//   - every `*.invalid.json` fixture fails validation (with located errors).
//
// Exits nonzero on the first surprise. Run with `npm test` from this dir.

import { readFileSync, readdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import Ajv from "ajv/dist/2020.js";
import addFormats from "ajv-formats";

const here = dirname(fileURLToPath(import.meta.url));
const fixturesDir = join(here, "fixtures");

const readJson = (p) => JSON.parse(readFileSync(p, "utf8"));

// strictRequired off: our if/then branches `required` a property that's
// declared on the sibling adapter schema, not inline — valid, but ajv's
// strict mode would otherwise flag it.
const ajv = new Ajv({ allErrors: true, strict: true, strictRequired: false });
addFormats(ajv);

// schema basename (sans `.schema.json`) -> compiled validator
const validators = new Map();
for (const file of ["manifest", "config"]) {
  const schema = readJson(join(here, `${file}.schema.json`));
  try {
    validators.set(file, ajv.compile(schema));
  } catch (err) {
    console.error(`✗ ${file}.schema.json is not a valid JSON Schema:\n  ${err.message}`);
    process.exit(1);
  }
  console.log(`✓ ${file}.schema.json compiles`);
}

const fmtErrors = (errors) =>
  (errors ?? [])
    .map((e) => `    ${e.instancePath || "(root)"} ${e.message}`)
    .join("\n");

let failures = 0;

for (const fixture of readdirSync(fixturesDir).sort()) {
  if (!fixture.endsWith(".json")) continue;

  const match = fixture.match(/^(manifest|config)\.(valid|invalid)\.json$/);
  if (!match) {
    console.error(`✗ ${fixture} does not match <schema>.<valid|invalid>.json`);
    failures++;
    continue;
  }
  const [, schemaName, expectation] = match;
  const validate = validators.get(schemaName);
  const ok = validate(readJson(join(fixturesDir, fixture)));

  if (expectation === "valid" && !ok) {
    console.error(`✗ ${fixture} should validate but did not:\n${fmtErrors(validate.errors)}`);
    failures++;
  } else if (expectation === "invalid" && ok) {
    console.error(`✗ ${fixture} should have failed validation but passed`);
    failures++;
  } else {
    const detail =
      expectation === "invalid"
        ? ` (rejected with ${validate.errors.length} error(s), as expected)`
        : "";
    console.log(`✓ ${fixture} ${expectation}${detail}`);
  }
}

if (failures > 0) {
  console.error(`\n${failures} fixture check(s) failed.`);
  process.exit(1);
}
console.log("\nAll schemas and fixtures behave as expected.");

#!/usr/bin/env node
'use strict';

// Thin shim: delegate to the compiled RN capture entrypoint. Keeping logic out
// of the bin file means `npm run build` is the single source of truth.
const { runRnCapture } = require('../dist/rn-adapter/cli.js');

runRnCapture(process.argv.slice(2))
  .then((code) => process.exit(code))
  .catch((error) => {
    process.stderr.write(`${error && error.stack ? error.stack : String(error)}\n`);
    process.exit(1);
  });

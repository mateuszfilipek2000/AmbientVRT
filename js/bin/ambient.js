#!/usr/bin/env node
'use strict';

// Thin shim: delegate to the compiled entrypoint. Keeping logic out of the bin
// file means `npm run build` is the single source of truth for behaviour.
const { run } = require('../dist/index.js');

process.exit(run(process.argv.slice(2)));

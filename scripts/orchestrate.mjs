#!/usr/bin/env node
import { run } from './orchestrator/run.mjs';

run(process.argv.slice(2)).catch((error) => {
  console.error(`ERROR   ${error.stack || error.message}`);
  process.exit(1);
});

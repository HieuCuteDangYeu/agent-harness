#!/usr/bin/env node
import { run } from './orchestrator/run.mjs';
import { showLogs, showStatus, startDetached } from './orchestrator/lifecycle.mjs';

async function main(argv) {
  const command = argv[0];
  if (command === 'start') {
    startDetached(argv[1]);
    return;
  }
  if (command === 'status') {
    showStatus(argv[1] || 'latest');
    return;
  }
  if (command === 'logs') {
    showLogs(argv[1] || 'latest', argv[2] || '80');
    return;
  }
  await run(argv);
}

main(process.argv.slice(2)).catch((error) => {
  console.error(`ERROR   ${error.stack || error.message}`);
  process.exit(1);
});

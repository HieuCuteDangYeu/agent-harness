#!/usr/bin/env node
import { examplePlan, usage } from './orchestrator/core.mjs';
import {
  abort,
  completeTask,
  deliver,
  failTask,
  prepare,
  prepareReview,
  prepareTask,
  ready,
  recordReview,
  runAgyReview,
  runAgyTask,
  status,
} from './orchestrator/session.mjs';

async function main(argv) {
  const command = argv[0];
  if (!command || command === '--help' || command === '-h' || command === 'help') {
    usage();
    return;
  }
  if (command === 'example') {
    examplePlan();
    return;
  }
  if (command === 'prepare') {
    prepare(argv[1]);
    return;
  }
  if (command === 'ready') {
    ready(argv[1] || 'latest');
    return;
  }
  if (command === 'task') {
    prepareTask(argv[1] || 'latest', argv[2]);
    return;
  }
  if (command === 'agy') {
    await runAgyTask(argv[1] || 'latest', argv[2]);
    return;
  }
  if (command === 'complete') {
    await completeTask(argv[1] || 'latest', argv[2]);
    return;
  }
  if (command === 'fail') {
    failTask(argv[1] || 'latest', argv[2], argv.slice(3).join(' ') || 'agent failed');
    return;
  }
  if (command === 'review-task') {
    prepareReview(argv[1] || 'latest');
    return;
  }
  if (command === 'review-agy') {
    await runAgyReview(argv[1] || 'latest');
    return;
  }
  if (command === 'review') {
    recordReview(argv[1] || 'latest', argv[2]);
    return;
  }
  if (command === 'deliver') {
    deliver(argv[1] || 'latest');
    return;
  }
  if (command === 'status') {
    status(argv[1] || 'latest');
    return;
  }
  if (command === 'abort') {
    abort(argv[1] || 'latest');
    return;
  }
  throw new Error(`unknown orchestrate command: ${command}`);
}

main(process.argv.slice(2)).catch((error) => {
  console.error(`ERROR   ${error.stack || error.message}`);
  process.exit(1);
});

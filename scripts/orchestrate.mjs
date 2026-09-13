#!/usr/bin/env node

import { spawn, spawnSync } from 'node:child_process';
import { createWriteStream, existsSync, readFileSync, writeFileSync, mkdirSync, rmSync } from 'node:fs';
import { mkdtemp } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';

const TASK_ID_RE = /^[A-Za-z0-9][A-Za-z0-9._-]*$/;
const SUPPORTED_AGENTS = new Set(['codex', 'gemini']);

function die(message, code = 2) {
  console.error(`ERROR   ${message}`);
  process.exit(code);
}

function sanitize(value) {
  return String(value || 'run')
    .toLowerCase()
    .replace(/[^a-z0-9._-]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 48) || 'run';
}

function shellQuote(value) {
  return `'${String(value).replace(/'/g, `'\\''`)}'`;
}

function git(args, { cwd, allowFailure = false } = {}) {
  const result = spawnSync('git', args, {
    cwd,
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  if (result.status !== 0 && !allowFailure) {
    throw new Error(`git ${args.join(' ')} failed: ${(result.stderr || result.stdout || '').trim()}`);
  }
  return {
    status: result.status ?? 1,
    stdout: (result.stdout || '').trim(),
    stderr: (result.stderr || '').trim(),
  };
}

function commandExists(command) {
  const result = spawnSync('sh', ['-lc', `command -v ${shellQuote(command)} >/dev/null 2>&1`]);
  return result.status === 0;
}

function usage() {
  console.log(`agent-harness orchestrate <plan.json> [options]
agent-harness orchestrate example

Options:
  --dry-run             Validate and print the execution graph without running agents.
  --max-parallel <n>    Override plan.maxParallel (default 2, max 8).
  --keep-worktrees      Keep temporary worktrees for debugging.
  --allow-dirty         Allow a dirty caller worktree; uncommitted changes are NOT included.

The orchestrator creates an isolated integration branch plus one temporary Git
worktree per runnable task. Independent tasks may run in parallel; dependent
tasks start only after their dependencies have been integrated successfully.
Nothing is pushed or merged to a remote automatically.`);
}

function examplePlan() {
  console.log(JSON.stringify({
    version: 1,
    name: 'issue-142',
    goal: 'Implement the requested feature with independent backend and test work where safe.',
    base: 'HEAD',
    maxParallel: 2,
    tasks: [
      {
        id: 'backend',
        agent: 'codex',
        prompt: 'Implement the backend behavior from the issue.',
        dependsOn: [],
        acceptanceCriteria: ['Required behavior is implemented', 'Existing contracts remain compatible'],
        verify: ['pnpm test --filter backend'],
      },
      {
        id: 'tests',
        agent: 'gemini',
        prompt: 'Add focused tests for the requested behavior. Do not duplicate backend implementation.',
        dependsOn: ['backend'],
        acceptanceCriteria: ['Tests cover success and important failure paths'],
        verify: ['pnpm test --filter backend'],
      },
    ],
    review: {
      agent: 'codex',
      prompt: 'Pay special attention to architecture boundaries, security, concurrency, and missing tests.',
    },
  }, null, 2));
}

function parseArgs(argv) {
  if (argv.length === 0 || argv.includes('--help') || argv.includes('-h')) {
    usage();
    process.exit(0);
  }
  if (argv[0] === 'example') {
    examplePlan();
    process.exit(0);
  }

  const options = {
    planPath: null,
    dryRun: false,
    maxParallel: null,
    keepWorktrees: false,
    allowDirty: false,
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--dry-run') options.dryRun = true;
    else if (arg === '--keep-worktrees') options.keepWorktrees = true;
    else if (arg === '--allow-dirty') options.allowDirty = true;
    else if (arg === '--max-parallel') {
      const raw = argv[++i];
      if (!raw) die('--max-parallel requires a value');
      options.maxParallel = Number(raw);
    } else if (arg.startsWith('--')) {
      die(`unknown option: ${arg}`);
    } else if (!options.planPath) {
      options.planPath = arg;
    } else {
      die(`unexpected argument: ${arg}`);
    }
  }

  if (!options.planPath) die('plan.json is required');
  return options;
}

function loadPlan(planPath) {
  let parsed;
  try {
    parsed = JSON.parse(readFileSync(planPath, 'utf8'));
  } catch (error) {
    die(`cannot read plan ${planPath}: ${error.message}`);
  }
  return parsed;
}

function stringArray(value, field, taskId) {
  if (value === undefined) return [];
  if (!Array.isArray(value) || value.some((item) => typeof item !== 'string')) {
    die(`${taskId ? `task ${taskId} ` : ''}${field} must be an array of strings`);
  }
  return value;
}

function validatePlan(plan, overrideParallel) {
  if (!plan || typeof plan !== 'object' || Array.isArray(plan)) die('plan must be a JSON object');
  if (plan.version !== 1) die('plan.version must be 1');
  if (!Array.isArray(plan.tasks) || plan.tasks.length === 0) die('plan.tasks must contain at least one task');
  if (typeof plan.goal !== 'string' || !plan.goal.trim()) die('plan.goal is required');

  const ids = new Set();
  for (const task of plan.tasks) {
    if (!task || typeof task !== 'object') die('every task must be an object');
    if (typeof task.id !== 'string' || !TASK_ID_RE.test(task.id)) {
      die(`invalid task id: ${JSON.stringify(task.id)} (use letters, numbers, dot, underscore, dash)`);
    }
    if (ids.has(task.id)) die(`duplicate task id: ${task.id}`);
    ids.add(task.id);
    if (!SUPPORTED_AGENTS.has(task.agent)) {
      die(`task ${task.id} agent must be one of: ${[...SUPPORTED_AGENTS].join(', ')}`);
    }
    if (typeof task.prompt !== 'string' || !task.prompt.trim()) die(`task ${task.id} prompt is required`);
    task.dependsOn = stringArray(task.dependsOn, 'dependsOn', task.id);
    task.acceptanceCriteria = stringArray(task.acceptanceCriteria, 'acceptanceCriteria', task.id);
    task.constraints = stringArray(task.constraints, 'constraints', task.id);
    task.nonGoals = stringArray(task.nonGoals, 'nonGoals', task.id);
    task.verify = stringArray(task.verify, 'verify', task.id);
    if (task.model !== undefined && typeof task.model !== 'string') die(`task ${task.id} model must be a string`);
    if (task.approval !== undefined && !['auto-edit', 'yolo'].includes(task.approval)) {
      die(`task ${task.id} approval must be auto-edit or yolo`);
    }
  }

  for (const task of plan.tasks) {
    for (const dependency of task.dependsOn) {
      if (!ids.has(dependency)) die(`task ${task.id} depends on unknown task ${dependency}`);
      if (dependency === task.id) die(`task ${task.id} cannot depend on itself`);
    }
  }

  const visiting = new Set();
  const visited = new Set();
  const byId = new Map(plan.tasks.map((task) => [task.id, task]));
  const visit = (id) => {
    if (visiting.has(id)) die(`dependency cycle detected at task ${id}`);
    if (visited.has(id)) return;
    visiting.add(id);
    for (const dep of byId.get(id).dependsOn) visit(dep);
    visiting.delete(id);
    visited.add(id);
  };
  for (const task of plan.tasks) visit(task.id);

  if (plan.review !== undefined) {
    if (!plan.review || typeof plan.review !== 'object' || Array.isArray(plan.review)) die('plan.review must be an object');
    if (!SUPPORTED_AGENTS.has(plan.review.agent)) die('plan.review.agent must be codex or gemini');
    if (plan.review.prompt !== undefined && typeof plan.review.prompt !== 'string') die('plan.review.prompt must be a string');
    if (plan.review.model !== undefined && typeof plan.review.model !== 'string') die('plan.review.model must be a string');
  }

  const parallel = overrideParallel ?? plan.maxParallel ?? 2;
  if (!Number.isInteger(parallel) || parallel < 1 || parallel > 8) die('maxParallel must be an integer from 1 to 8');
  return parallel;
}

function bulletSection(title, items) {
  if (!items?.length) return '';
  return `\n${title}:\n${items.map((item) => `- ${item}`).join('\n')}\n`;
}

function buildTaskPrompt(plan, task) {
  return `You are an implementation executor launched by agent-harness.

Read AGENTS.md and only the repository skills relevant to this task before changing code.
Use existing architecture and conventions. Make the smallest complete change.
Do not push, merge, create a PR, or modify files outside this worktree.

Plan goal:
${plan.goal}

Assigned task (${task.id}):
${task.prompt}
${bulletSection('Dependencies already integrated before this task started', task.dependsOn)}${bulletSection('Acceptance criteria', task.acceptanceCriteria)}${bulletSection('Constraints', task.constraints)}${bulletSection('Non-goals', task.nonGoals)}${bulletSection('Harness verification after you finish', task.verify)}
Before completion, inspect your diff and leave the worktree in a ready-to-commit state. You may commit changes yourself, but it is not required.`;
}

function buildReviewPrompt(plan, baseRef) {
  const taskSummary = plan.tasks.map((task) => `- ${task.id}: ${task.prompt}`).join('\n');
  const extra = plan.review?.prompt ? `\nAdditional review focus:\n${plan.review.prompt}\n` : '';
  return `Act as the final reviewer for an automatically integrated multi-agent change.

DO NOT modify any files. Review the current branch against base ${baseRef}.
Inspect the actual diff and relevant tests. Check correctness, architecture consistency, security,
concurrency/data-integrity risks, compatibility, and meaningful test coverage.

Plan goal:
${plan.goal}

Executed tasks:
${taskSummary}
${extra}
End your response with exactly one of:
VERDICT: PASS
VERDICT: BLOCK

Use BLOCK only for a concrete issue that should prevent the branch from being merged.`;
}

async function runProcess(command, args, { cwd, input = null, env = {}, logFile, label }) {
  mkdirSync(path.dirname(logFile), { recursive: true });
  const log = createWriteStream(logFile, { flags: 'a' });
  log.write(`$ ${command} ${args.map(shellQuote).join(' ')}\n`);

  return await new Promise((resolve) => {
    let settled = false;
    const child = spawn(command, args, {
      cwd,
      env: { ...process.env, ...env },
      stdio: ['pipe', 'pipe', 'pipe'],
    });

    const forward = (stream, destination) => {
      let buffered = '';
      stream.on('data', (chunk) => {
        const text = chunk.toString();
        log.write(text);
        buffered += text;
        const lines = buffered.split(/\r?\n/);
        buffered = lines.pop() || '';
        for (const line of lines) destination.write(`[${label}] ${line}\n`);
      });
      stream.on('end', () => {
        if (buffered) destination.write(`[${label}] ${buffered}\n`);
      });
    };

    forward(child.stdout, process.stdout);
    forward(child.stderr, process.stderr);

    child.on('error', (error) => {
      if (settled) return;
      settled = true;
      log.write(`\nspawn error: ${error.message}\n`);
      log.end();
      resolve({ code: 127, error: error.message });
    });
    child.on('close', (code, signal) => {
      if (settled) return;
      settled = true;
      log.write(`\nexit=${code ?? 1} signal=${signal ?? ''}\n`);
      log.end();
      resolve({ code: code ?? 1, signal });
    });

    if (input !== null) child.stdin.end(input);
    else child.stdin.end();
  });
}

async function invokeAgent(agent, { cwd, prompt, model, approval, logFile, resultFile, taskId }) {
  if (!commandExists(agent)) {
    return { code: 127, error: `${agent} command not found` };
  }

  if (agent === 'codex') {
    const args = ['exec', '--approve-for-me', '-C', cwd, '--output-last-message', resultFile];
    if (model) args.push('--model', model);
    args.push('-');
    return await runProcess('codex', args, {
      cwd,
      input: prompt,
      logFile,
      label: taskId,
      env: { AGENT_HARNESS_TASK_ID: taskId },
    });
  }

  const approvalMode = approval === 'yolo' ? 'yolo' : 'auto_edit';
  const args = ['--approval-mode', approvalMode, '--output-format', 'text'];
  if (model) args.push('--model', model);
  args.push('--prompt', prompt);
  return await runProcess('gemini', args, {
    cwd,
    logFile,
    label: taskId,
    env: { AGENT_HARNESS_TASK_ID: taskId },
  });
}

async function runVerification(commands, cwd, logFile, taskId) {
  for (const command of commands) {
    const result = await runProcess('bash', ['-lc', command], {
      cwd,
      logFile,
      label: `${taskId}:verify`,
    });
    if (result.code !== 0) return { ok: false, command, code: result.code };
  }
  return { ok: true };
}

function saveFailureDiff(worktree, outputPath) {
  try {
    git(['-C', worktree, 'add', '-N', '.'], { allowFailure: true });
    const result = spawnSync('git', ['-C', worktree, 'diff', '--binary'], { encoding: 'utf8' });
    writeFileSync(outputPath, result.stdout || '', 'utf8');
    git(['-C', worktree, 'reset'], { allowFailure: true });
  } catch {
    // Best-effort diagnostic only.
  }
}

function autoCommit(worktree, taskId) {
  const status = git(['-C', worktree, 'status', '--porcelain']).stdout;
  if (status) {
    git(['-C', worktree, 'add', '-A']);
    git([
      '-C', worktree,
      '-c', 'user.name=agent-harness',
      '-c', 'user.email=agent-harness@local',
      'commit', '-m', `agent(${taskId}): automated task`,
    ]);
  }
  return git(['-C', worktree, 'rev-parse', 'HEAD']).stdout;
}

async function runTask({ plan, task, baseSha, repoRoot, worktreeRoot, stateRoot, runId, keepWorktrees }) {
  const branch = `agent/orchestrate/${runId}/${sanitize(task.id)}`;
  const worktree = path.join(worktreeRoot, `task-${sanitize(task.id)}`);
  const logFile = path.join(stateRoot, `${task.id}.log`);
  const resultFile = path.join(stateRoot, `${task.id}.last-message.txt`);
  const diffFile = path.join(stateRoot, `${task.id}.failure.diff`);

  console.log(`START   ${task.id} -> ${task.agent}`);
  git(['-C', repoRoot, 'worktree', 'add', '-b', branch, worktree, baseSha]);

  let result;
  try {
    result = await invokeAgent(task.agent, {
      cwd: worktree,
      prompt: buildTaskPrompt(plan, task),
      model: task.model,
      approval: task.approval,
      logFile,
      resultFile,
      taskId: task.id,
    });

    if (result.code !== 0) {
      saveFailureDiff(worktree, diffFile);
      return { id: task.id, status: 'failed', phase: 'agent', code: result.code, branch, logFile, diffFile };
    }

    const verification = await runVerification(task.verify, worktree, logFile, task.id);
    if (!verification.ok) {
      saveFailureDiff(worktree, diffFile);
      return {
        id: task.id,
        status: 'failed',
        phase: 'verification',
        code: verification.code,
        command: verification.command,
        branch,
        logFile,
        diffFile,
      };
    }

    const headSha = autoCommit(worktree, task.id);
    const ancestry = git(['-C', worktree, 'merge-base', '--is-ancestor', baseSha, headSha], { allowFailure: true });
    if (ancestry.status !== 0) {
      return { id: task.id, status: 'failed', phase: 'git-history', branch, logFile, error: 'task rewrote history outside its assigned base' };
    }

    return { id: task.id, status: 'ready', branch, baseSha, headSha, logFile, resultFile };
  } finally {
    if (!keepWorktrees && existsSync(worktree)) {
      git(['-C', repoRoot, 'worktree', 'remove', '--force', worktree], { allowFailure: true });
    } else if (keepWorktrees) {
      console.log(`KEEP    ${task.id} worktree ${worktree}`);
    }
  }
}

function integrateTask(outcome, integrationDir) {
  if (outcome.status !== 'ready') return outcome;
  const commitCount = Number(git(['-C', integrationDir, 'rev-list', '--count', `${outcome.baseSha}..${outcome.headSha}`]).stdout || '0');
  if (commitCount === 0) {
    return { ...outcome, status: 'success', noChanges: true };
  }

  const merged = spawnSync('git', [
    '-C', integrationDir,
    '-c', 'user.name=agent-harness',
    '-c', 'user.email=agent-harness@local',
    'merge', '--no-ff', '--no-edit', outcome.headSha,
  ], { encoding: 'utf8' });

  if (merged.status !== 0) {
    git(['-C', integrationDir, 'merge', '--abort'], { allowFailure: true });
    return {
      ...outcome,
      status: 'failed',
      phase: 'integration',
      error: (merged.stderr || merged.stdout || 'merge conflict').trim(),
    };
  }

  return {
    ...outcome,
    status: 'success',
    integratedSha: git(['-C', integrationDir, 'rev-parse', 'HEAD']).stdout,
  };
}

function writeStatus(stateRoot, data) {
  writeFileSync(path.join(stateRoot, 'status.json'), `${JSON.stringify(data, null, 2)}\n`, 'utf8');
}

async function runReview(plan, integrationDir, stateRoot, baseRef) {
  if (!plan.review) return { status: 'skipped' };
  const logFile = path.join(stateRoot, 'review.log');
  const resultFile = path.join(stateRoot, 'review.last-message.txt');
  const before = git(['-C', integrationDir, 'status', '--porcelain']).stdout;
  const result = await invokeAgent(plan.review.agent, {
    cwd: integrationDir,
    prompt: buildReviewPrompt(plan, baseRef),
    model: plan.review.model,
    approval: plan.review.approval,
    logFile,
    resultFile,
    taskId: 'review',
  });

  const after = git(['-C', integrationDir, 'status', '--porcelain']).stdout;
  let mutationReverted = false;
  if (after !== before) {
    mutationReverted = true;
    writeFileSync(path.join(stateRoot, 'review-mutation.diff'), spawnSync('git', ['-C', integrationDir, 'diff', '--binary'], { encoding: 'utf8' }).stdout || '');
    git(['-C', integrationDir, 'reset', '--hard', 'HEAD'], { allowFailure: true });
    git(['-C', integrationDir, 'clean', '-fd'], { allowFailure: true });
  }

  let text = '';
  if (existsSync(resultFile)) text = readFileSync(resultFile, 'utf8');
  if (!text && existsSync(logFile)) text = readFileSync(logFile, 'utf8');
  const blocked = /VERDICT:\s*BLOCK\b/i.test(text);
  const passed = /VERDICT:\s*PASS\b/i.test(text);

  return {
    status: result.code === 0 ? (blocked ? 'blocked' : 'success') : 'failed',
    code: result.code,
    verdict: blocked ? 'BLOCK' : passed ? 'PASS' : 'UNKNOWN',
    mutationReverted,
    logFile,
    resultFile,
  };
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  const planPath = path.resolve(options.planPath);
  const plan = loadPlan(planPath);
  const maxParallel = validatePlan(plan, options.maxParallel);

  let repoRoot;
  try {
    repoRoot = git(['rev-parse', '--show-toplevel'], { cwd: process.cwd() }).stdout;
  } catch {
    die('orchestrate must be run inside a Git repository');
  }

  const dirty = git(['-C', repoRoot, 'status', '--porcelain']).stdout;
  if (dirty && !options.allowDirty) {
    die('caller worktree is dirty; commit/stash changes first or pass --allow-dirty (dirty changes will not be included)');
  }

  const baseRef = plan.base || 'HEAD';
  let baseSha;
  try {
    baseSha = git(['-C', repoRoot, 'rev-parse', `${baseRef}^{commit}`]).stdout;
  } catch (error) {
    die(`cannot resolve plan base ${baseRef}: ${error.message}`);
  }

  console.log(`PLAN    ${plan.name || 'unnamed'}`);
  console.log(`GOAL    ${plan.goal}`);
  console.log(`BASE    ${baseRef} (${baseSha.slice(0, 12)})`);
  console.log(`PARALLEL ${maxParallel}`);
  for (const task of plan.tasks) {
    console.log(`TASK    ${task.id} -> ${task.agent} deps=[${task.dependsOn.join(', ')}]`);
  }
  if (plan.review) console.log(`REVIEW  ${plan.review.agent}`);

  if (options.dryRun) {
    console.log('DRY-RUN plan is valid; no branches, worktrees, or agents were started.');
    return;
  }

  for (const agent of new Set([...plan.tasks.map((task) => task.agent), ...(plan.review ? [plan.review.agent] : [])])) {
    if (!commandExists(agent)) die(`${agent} command is required by this plan but was not found on PATH`);
  }

  const commonDirRaw = git(['-C', repoRoot, 'rev-parse', '--git-common-dir']).stdout;
  const commonGitDir = path.resolve(repoRoot, commonDirRaw);
  const stamp = new Date().toISOString().replace(/[-:TZ.]/g, '').slice(0, 14);
  const runId = `${sanitize(plan.name || 'run')}-${stamp}-${Math.random().toString(36).slice(2, 6)}`;
  const stateRoot = path.join(commonGitDir, 'agent-harness', 'runs', runId);
  mkdirSync(stateRoot, { recursive: true });
  writeFileSync(path.join(stateRoot, 'plan.json'), `${JSON.stringify(plan, null, 2)}\n`, 'utf8');

  const worktreeRoot = await mkdtemp(path.join(os.tmpdir(), `agent-harness-${sanitize(path.basename(repoRoot))}-${runId}-`));
  const integrationDir = path.join(worktreeRoot, 'integration');
  const integrationBranch = `agent/orchestrate/${runId}`;
  git(['-C', repoRoot, 'worktree', 'add', '-b', integrationBranch, integrationDir, baseSha]);

  const states = new Map(plan.tasks.map((task) => [task.id, { id: task.id, status: 'pending' }]));
  const tasksById = new Map(plan.tasks.map((task) => [task.id, task]));
  const running = new Map();

  const snapshot = () => ({
    runId,
    plan: plan.name || null,
    goal: plan.goal,
    baseRef,
    baseSha,
    integrationBranch,
    stateRoot,
    tasks: [...states.values()],
  });
  writeStatus(stateRoot, snapshot());

  try {
    while (true) {
      let changed = false;
      for (const task of plan.tasks) {
        const current = states.get(task.id);
        if (current.status !== 'pending') continue;
        const depStates = task.dependsOn.map((dep) => states.get(dep).status);
        if (depStates.some((status) => ['failed', 'blocked'].includes(status))) {
          states.set(task.id, { id: task.id, status: 'blocked', reason: 'dependency failed' });
          changed = true;
        }
      }

      const ready = plan.tasks.filter((task) => {
        const current = states.get(task.id);
        return current.status === 'pending' && task.dependsOn.every((dep) => states.get(dep).status === 'success');
      });

      while (running.size < maxParallel && ready.length > 0) {
        const task = ready.shift();
        const taskBase = git(['-C', integrationDir, 'rev-parse', 'HEAD']).stdout;
        states.set(task.id, { id: task.id, status: 'running', agent: task.agent, baseSha: taskBase });
        const promise = runTask({
          plan,
          task,
          baseSha: taskBase,
          repoRoot,
          worktreeRoot,
          stateRoot,
          runId,
          keepWorktrees: options.keepWorktrees,
        }).then((outcome) => ({ taskId: task.id, outcome }));
        running.set(task.id, promise);
        changed = true;
      }

      if (changed) writeStatus(stateRoot, snapshot());

      if (running.size === 0) {
        const pending = [...states.values()].filter((state) => state.status === 'pending');
        if (pending.length > 0) {
          for (const state of pending) states.set(state.id, { ...state, status: 'blocked', reason: 'dependency graph could not make progress' });
        }
        break;
      }

      const completed = await Promise.race([...running.values()]);
      running.delete(completed.taskId);
      const integrated = integrateTask(completed.outcome, integrationDir);
      states.set(completed.taskId, integrated);
      console.log(`${integrated.status === 'success' ? 'DONE' : 'FAIL'}    ${completed.taskId}${integrated.phase ? ` phase=${integrated.phase}` : ''}`);
      writeStatus(stateRoot, snapshot());
    }

    const taskResults = [...states.values()];
    const taskFailed = taskResults.some((state) => state.status !== 'success');
    let review = { status: 'skipped' };
    if (!taskFailed) {
      review = await runReview(plan, integrationDir, stateRoot, baseRef);
      if (plan.review) console.log(`REVIEW  ${review.status} verdict=${review.verdict}`);
    }

    const finalHead = git(['-C', integrationDir, 'rev-parse', 'HEAD']).stdout;
    const success = !taskFailed && !['failed', 'blocked'].includes(review.status);
    const summary = {
      ...snapshot(),
      status: success ? 'success' : 'failed',
      finalHead,
      review,
      completedAt: new Date().toISOString(),
    };
    writeFileSync(path.join(stateRoot, 'summary.json'), `${JSON.stringify(summary, null, 2)}\n`, 'utf8');
    writeStatus(stateRoot, summary);

    console.log('');
    console.log(`RESULT  ${summary.status}`);
    console.log(`BRANCH  ${integrationBranch}`);
    console.log(`STATE   ${stateRoot}`);
    console.log(`DIFF    git diff ${shellQuote(baseRef)}...${shellQuote(integrationBranch)}`);
    console.log(`LOG     git log --oneline ${shellQuote(baseRef)}..${shellQuote(integrationBranch)}`);
    console.log(`PUSH    git push -u origin ${shellQuote(integrationBranch)}`);

    if (!success) process.exitCode = 1;
  } finally {
    if (!options.keepWorktrees && existsSync(integrationDir)) {
      git(['-C', repoRoot, 'worktree', 'remove', '--force', integrationDir], { allowFailure: true });
    }
    if (!options.keepWorktrees) {
      rmSync(worktreeRoot, { recursive: true, force: true });
      git(['-C', repoRoot, 'worktree', 'prune'], { allowFailure: true });
    } else {
      console.log(`KEEP    worktrees ${worktreeRoot}`);
    }
  }
}

main().catch((error) => {
  console.error(`ERROR   ${error.stack || error.message}`);
  process.exit(1);
});

import { spawn, spawnSync } from 'node:child_process';
import { createWriteStream, mkdirSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { agyRunnerStatus, getAgyJob, submitAgyJob } from './agy-client.mjs';

export const TASK_ID_RE = /^[A-Za-z0-9][A-Za-z0-9._-]*$/;
export const SUPPORTED_AGENTS = new Set(['codex', 'agy']);

export function die(message, code = 2) {
  console.error(`ERROR   ${message}`);
  process.exit(code);
}

export function sanitize(value) {
  return String(value || 'run').toLowerCase().replace(/[^a-z0-9._-]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 48) || 'run';
}

export function shellQuote(value) {
  return `'${String(value).replace(/'/g, `'\\''`)}'`;
}

export function git(args, { cwd, allowFailure = false, env = {} } = {}) {
  const result = spawnSync('git', args, {
    cwd,
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
    env: { ...process.env, ...env },
    maxBuffer: 64 * 1024 * 1024,
  });
  if (result.status !== 0 && !allowFailure) {
    throw new Error(`git ${args.join(' ')} failed: ${(result.stderr || result.stdout || '').trim()}`);
  }
  return { status: result.status ?? 1, stdout: (result.stdout || '').trim(), stderr: (result.stderr || '').trim() };
}

export function commandExists(command) {
  if (command === 'agy' && agyRunnerStatus().ready) return true;
  const result = spawnSync('sh', ['-c', `command -v ${shellQuote(command)} >/dev/null 2>&1`], { env: process.env });
  return result.status === 0;
}

export function usage() {
  console.log(`agent-harness orchestrate prepare <plan.json>\nagent-harness orchestrate ready [run-id|latest]\nagent-harness orchestrate task <run-id|latest> <task-id>\nagent-harness orchestrate agy <run-id|latest> <task-id>\nagent-harness orchestrate complete <run-id|latest> <task-id>\nagent-harness orchestrate fail <run-id|latest> <task-id> [reason]\nagent-harness orchestrate review-task <run-id|latest>\nagent-harness orchestrate review-agy <run-id|latest>\nagent-harness orchestrate review <run-id|latest> <PASS|BLOCK>\nagent-harness orchestrate deliver <run-id|latest>\nagent-harness orchestrate status [run-id|latest]\nagent-harness orchestrate abort [run-id|latest]\nagent-harness orchestrate example\n\nNormal use is driven by the repository-orchestrator skill. Codex tasks are spawned with\nCodex's native subagent tools. Antigravity tasks are submitted to the host-side agy runner\nstarted from the user's normal terminal. The helper manages temporary shadow repositories,\nworktrees, deterministic verification, integration, review state, and delivery. It never\nlaunches a nested codex CLI process and never runs agy directly inside the Codex/Web sandbox.`);
}

export function examplePlan() {
  console.log(JSON.stringify({
    version: 1,
    name: 'feature-change',
    goal: 'Implement the requested feature with independent work where safe.',
    maxParallel: 2,
    tasks: [
      { id: 'implementation', agent: 'codex', prompt: 'Implement the requested behavior.', dependsOn: [], acceptanceCriteria: ['Required behavior is implemented'], verify: ['pnpm test'] },
      { id: 'tests', agent: 'agy', prompt: 'Add focused tests for the requested behavior.', dependsOn: ['implementation'], acceptanceCriteria: ['Tests cover important paths'], approval: 'yolo', verify: ['pnpm test'] },
    ],
    review: { agent: 'codex', prompt: 'Focus on correctness, architecture, security, concurrency, and missing tests.' },
  }, null, 2));
}

export function loadPlan(planPath) {
  try { return JSON.parse(readFileSync(planPath, 'utf8')); }
  catch (error) { die(`cannot read plan ${planPath}: ${error.message}`); }
}

function stringArray(value, field, taskId) {
  if (value === undefined) return [];
  if (!Array.isArray(value) || value.some((item) => typeof item !== 'string')) {
    die(`${taskId ? `task ${taskId} ` : ''}${field} must be an array of strings`);
  }
  return value;
}

export function validatePlan(plan) {
  if (!plan || typeof plan !== 'object' || Array.isArray(plan)) die('plan must be a JSON object');
  if (plan.version !== 1) die('plan.version must be 1');
  if (typeof plan.goal !== 'string' || !plan.goal.trim()) die('plan.goal is required');
  if (!Array.isArray(plan.tasks) || plan.tasks.length === 0) die('plan.tasks must contain at least one task');

  const ids = new Set();
  for (const task of plan.tasks) {
    if (!task || typeof task !== 'object' || Array.isArray(task)) die('every task must be an object');
    if (typeof task.id !== 'string' || !TASK_ID_RE.test(task.id)) die(`invalid task id: ${JSON.stringify(task.id)}`);
    if (ids.has(task.id)) die(`duplicate task id: ${task.id}`);
    ids.add(task.id);
    if (!SUPPORTED_AGENTS.has(task.agent)) die(`task ${task.id} agent must be codex or agy`);
    if (typeof task.prompt !== 'string' || !task.prompt.trim()) die(`task ${task.id} prompt is required`);
    task.dependsOn = stringArray(task.dependsOn, 'dependsOn', task.id);
    task.acceptanceCriteria = stringArray(task.acceptanceCriteria, 'acceptanceCriteria', task.id);
    task.constraints = stringArray(task.constraints, 'constraints', task.id);
    task.nonGoals = stringArray(task.nonGoals, 'nonGoals', task.id);
    task.verify = stringArray(task.verify, 'verify', task.id);
    if (task.model !== undefined && typeof task.model !== 'string') die(`task ${task.id} model must be a string`);
    if (task.approval !== undefined && !['auto-edit', 'yolo'].includes(task.approval)) die(`task ${task.id} approval must be auto-edit or yolo`);
  }

  for (const task of plan.tasks) for (const dep of task.dependsOn) {
    if (!ids.has(dep)) die(`task ${task.id} depends on unknown task ${dep}`);
    if (dep === task.id) die(`task ${task.id} cannot depend on itself`);
  }

  const byId = new Map(plan.tasks.map((task) => [task.id, task]));
  const visiting = new Set();
  const visited = new Set();
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
    if (!SUPPORTED_AGENTS.has(plan.review.agent)) die('plan.review.agent must be codex or agy');
    if (plan.review.prompt !== undefined && typeof plan.review.prompt !== 'string') die('plan.review.prompt must be a string');
    if (plan.review.model !== undefined && typeof plan.review.model !== 'string') die('plan.review.model must be a string');
    if (plan.review.approval !== undefined && !['auto-edit', 'yolo'].includes(plan.review.approval)) die('plan.review.approval must be auto-edit or yolo');
  }

  const maxParallel = plan.maxParallel ?? 2;
  if (!Number.isInteger(maxParallel) || maxParallel < 1 || maxParallel > 8) die('maxParallel must be an integer from 1 to 8');
  return maxParallel;
}

function section(title, items) {
  if (!items?.length) return '';
  return `\n${title}:\n${items.map((item) => `- ${item}`).join('\n')}\n`;
}

export function taskPrompt(plan, task, worktree) {
  return `You are a repository task executor coordinated by agent-harness.\n\nYour isolated worktree is:\n${worktree}\n\nWork only inside that worktree. The parent session may be open in another checkout, so use the absolute worktree path for repository reads, shell commands, and edits. Read that worktree's AGENTS.md and only relevant repository skills before editing. Follow existing architecture and conventions. Make the smallest complete change.\n\nDo not create or delegate to additional agents. Do not push, merge, create a PR, or edit the caller checkout. Do not change harness infrastructure to work around task problems.\n\nPlan goal:\n${plan.goal}\n\nAssigned task (${task.id}):\n${task.prompt}\n${section('Dependencies already integrated', task.dependsOn)}${section('Acceptance criteria', task.acceptanceCriteria)}${section('Constraints', task.constraints)}${section('Non-goals', task.nonGoals)}${section('Harness verification after you finish', task.verify)}\nInspect your diff before completion and leave the worktree ready for deterministic verification. You may commit, but it is not required.`;
}

export function reviewPrompt(plan, worktree) {
  const tasks = plan.tasks.map((task) => `- ${task.id}: ${task.prompt}`).join('\n');
  const extra = plan.review?.prompt ? `\nAdditional review focus:\n${plan.review.prompt}\n` : '';
  return `Act as the final reviewer for an integrated multi-agent change.\n\nThe disposable review worktree is:\n${worktree}\n\nReview only that worktree. Do not modify files, create commits, or delegate to more agents. Inspect the actual diff and relevant tests. Check correctness, architecture, security, concurrency/data integrity, compatibility, and meaningful test coverage.\n\nPlan goal:\n${plan.goal}\n\nExecuted tasks:\n${tasks}\n${extra}\nEnd with exactly one line:\nVERDICT: PASS\nor\nVERDICT: BLOCK\n\nUse BLOCK only for a concrete merge-blocking issue.`;
}

export async function runProcess(command, args, { cwd, input = null, env = {}, logFile, label, displayCommand = null }) {
  mkdirSync(path.dirname(logFile), { recursive: true });
  const log = createWriteStream(logFile, { flags: 'a' });
  log.write(`$ ${displayCommand || `${command} ${args.map(shellQuote).join(' ')}`}\n`);
  return await new Promise((resolve) => {
    let settled = false;
    let stdout = '';
    let stderr = '';
    const child = spawn(command, args, { cwd, env: { ...process.env, ...env }, stdio: ['pipe', 'pipe', 'pipe'] });
    const forward = (stream, destination, capture) => {
      let buffered = '';
      stream.on('data', (chunk) => {
        const text = chunk.toString();
        log.write(text);
        capture(text);
        buffered += text;
        const lines = buffered.split(/\r?\n/);
        buffered = lines.pop() || '';
        for (const line of lines) destination.write(`[${label}] ${line}\n`);
      });
      stream.on('end', () => { if (buffered) destination.write(`[${label}] ${buffered}\n`); });
    };
    forward(child.stdout, process.stdout, (text) => { stdout += text; });
    forward(child.stderr, process.stderr, (text) => { stderr += text; });
    child.on('error', (error) => {
      if (settled) return;
      settled = true;
      log.end();
      resolve({ code: 127, error: error.message, stdout, stderr });
    });
    child.on('close', (code, signal) => {
      if (settled) return;
      settled = true;
      log.write(`\nexit=${code ?? 1} signal=${signal ?? ''}\n`);
      log.end();
      resolve({ code: code ?? 1, signal, stdout, stderr });
    });
    child.stdin.end(input ?? undefined);
  });
}

export async function invokeAgy({ cwd, prompt, model, approval, logFile, taskId }) {
  const runner = agyRunnerStatus();
  if (!runner.ready) {
    return { code: 127, error: `agy host runner unavailable: ${runner.reason}. Start it from a normal terminal with: agent-harness agy start`, stdout: '', stderr: '' };
  }

  let submitted;
  try {
    submitted = submitAgyJob({
      cwd,
      prompt,
      model,
      approval,
      timeout: '15m',
      taskId,
      idempotencyKey: `${cwd}\u0000${taskId}`,
    });
  } catch (error) {
    return { code: 127, error: error.message, stdout: '', stderr: '' };
  }

  const log = createWriteStream(logFile, { flags: 'a' });
  log.write(`agy-host-job=${submitted.id}${submitted.reused ? ' reused' : ' submitted'}\n`);
  log.end();
  console.log(`[${taskId}] AGY_HOST_JOB ${submitted.id}${submitted.reused ? ' reused' : ''}`);

  while (true) {
    const state = getAgyJob(submitted.id);
    if (state.state === 'complete') {
      const result = state.result;
      return {
        code: result.status === 'success' ? 0 : (result.code ?? 1),
        error: result.status === 'success' ? null : (result.error || `agy host job failed (${result.agyStatus || result.code || 'unknown'})`),
        stdout: result.response || result.stdoutTail || '',
        stderr: result.stderrTail || '',
      };
    }
    if (state.state === 'missing') {
      return { code: 1, error: `agy host job disappeared: ${submitted.id}`, stdout: '', stderr: '' };
    }
    const health = agyRunnerStatus();
    if (!health.ready) {
      return { code: 1, error: `agy host runner stopped while job ${submitted.id} was ${state.state}`, stdout: '', stderr: '' };
    }
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
}

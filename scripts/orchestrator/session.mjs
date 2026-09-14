import { createHash } from 'node:crypto';
import { cpSync, existsSync, mkdirSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import os from 'node:os';
import path from 'node:path';
import {
  commandExists,
  git,
  invokeAgy,
  loadPlan,
  reviewPrompt,
  runProcess,
  sanitize,
  taskPrompt,
  validatePlan,
} from './core.mjs';

function repoRoot() {
  return git(['rev-parse', '--show-toplevel'], { cwd: process.cwd() }).stdout;
}

function stateBase() {
  return process.env.AGENT_HARNESS_STATE_DIR || path.join(os.tmpdir(), 'agent-harness-state');
}

function repoKey(root) {
  const digest = createHash('sha1').update(path.resolve(root)).digest('hex').slice(0, 10);
  return `${sanitize(path.basename(root))}-${digest}`;
}

function runsRoot(root) {
  return path.join(stateBase(), repoKey(root), 'runs');
}

function newRunId(plan) {
  const stamp = new Date().toISOString().replace(/[-:TZ.]/g, '').slice(0, 14);
  return `${sanitize(plan.name || 'run')}-${stamp}-${Math.random().toString(36).slice(2, 6)}`;
}

function readJson(file) {
  return JSON.parse(readFileSync(file, 'utf8'));
}

function writeJson(file, value) {
  writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`, 'utf8');
}

function resolveRun(root, token = 'latest') {
  const base = runsRoot(root);
  if (!existsSync(base)) throw new Error('no orchestrator runs found');
  if (token && token !== 'latest') {
    const exact = path.join(base, token);
    if (!existsSync(exact)) throw new Error(`orchestrator run not found: ${token}`);
    return { runId: token, stateRoot: exact };
  }
  const entries = readdirSync(base, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => ({ name: entry.name, mtime: statSync(path.join(base, entry.name)).mtimeMs }))
    .sort((a, b) => b.mtime - a.mtime);
  if (!entries.length) throw new Error('no orchestrator runs found');
  return { runId: entries[0].name, stateRoot: path.join(base, entries[0].name) };
}

function loadRun(token = 'latest') {
  const root = repoRoot();
  const resolved = resolveRun(root, token);
  return { ...resolved, state: readJson(path.join(resolved.stateRoot, 'state.json')) };
}

function saveRun(stateRoot, state) {
  state.updatedAt = new Date().toISOString();
  writeJson(path.join(stateRoot, 'state.json'), state);
}

function nulList(text) {
  return String(text || '').split('\0').filter(Boolean);
}

function syncWorkingTree(sourceRoot, shadowRoot) {
  const tracked = nulList(git(['-C', sourceRoot, 'ls-files', '-z']).stdout);
  const untracked = nulList(git(['-C', sourceRoot, 'ls-files', '--others', '--exclude-standard', '-z']).stdout);
  for (const rel of new Set([...tracked, ...untracked])) {
    const source = path.join(sourceRoot, rel);
    const target = path.join(shadowRoot, rel);
    if (!existsSync(source)) {
      rmSync(target, { recursive: true, force: true });
      continue;
    }
    mkdirSync(path.dirname(target), { recursive: true });
    rmSync(target, { recursive: true, force: true });
    cpSync(source, target, { recursive: true, force: true, dereference: false, preserveTimestamps: true });
  }
}

function taskDef(state, taskId) {
  const task = state.plan.tasks.find((item) => item.id === taskId);
  if (!task) throw new Error(`unknown task: ${taskId}`);
  return task;
}

function taskState(state, taskId) {
  const task = state.tasks.find((item) => item.id === taskId);
  if (!task) throw new Error(`unknown task state: ${taskId}`);
  return task;
}

function cleanupWorktree(state, worktree) {
  if (!worktree || !existsSync(worktree)) return;
  git(['-C', state.shadowRoot, 'worktree', 'remove', '--force', worktree], { allowFailure: true });
  git(['-C', state.shadowRoot, 'worktree', 'prune'], { allowFailure: true });
}

function propagateBlocked(state) {
  let changed = true;
  while (changed) {
    changed = false;
    for (const current of state.tasks) {
      if (current.status !== 'pending') continue;
      const task = taskDef(state, current.id);
      const deps = task.dependsOn.map((dep) => taskState(state, dep).status);
      if (deps.some((status) => status === 'failed' || status === 'blocked')) {
        current.status = 'blocked';
        current.reason = 'dependency failed';
        changed = true;
      }
    }
  }
}

function refreshStatus(state) {
  propagateBlocked(state);
  if (state.status === 'success' || state.status === 'aborted') return;
  if (state.tasks.some((task) => task.status === 'failed' || task.status === 'blocked')) {
    const active = state.tasks.some((task) => task.status === 'pending' || task.status === 'running');
    state.status = active ? 'running' : 'failed';
    return;
  }
  if (state.tasks.every((task) => task.status === 'success')) {
    if (!state.plan.review) state.status = 'ready_to_deliver';
    else if (state.review?.verdict === 'PASS') state.status = 'ready_to_deliver';
    else if (state.review?.verdict === 'BLOCK') state.status = 'failed';
    else state.status = 'review_pending';
    return;
  }
  state.status = 'running';
}

function ensureTaskWorktree(stateRoot, state, taskId) {
  const definition = taskDef(state, taskId);
  const current = taskState(state, taskId);
  if (current.status === 'running' && current.worktree && existsSync(current.worktree)) return current;
  if (current.status !== 'pending') throw new Error(`task ${taskId} is ${current.status}, not pending`);
  const depStates = definition.dependsOn.map((dep) => taskState(state, dep).status);
  if (!depStates.every((status) => status === 'success')) throw new Error(`task ${taskId} dependencies are not complete`);

  const baseSha = git(['-C', state.shadowRoot, 'rev-parse', 'HEAD']).stdout;
  const worktreeRoot = path.join(stateRoot, 'worktrees');
  const worktree = path.join(worktreeRoot, `task-${sanitize(taskId)}`);
  const branch = `agent/task-${state.runId}-${sanitize(taskId)}`;
  mkdirSync(worktreeRoot, { recursive: true });
  git(['-C', state.shadowRoot, 'worktree', 'add', '-b', branch, worktree, baseSha]);

  const promptFile = path.join(stateRoot, `${sanitize(taskId)}.prompt.txt`);
  writeFileSync(promptFile, taskPrompt(state.plan, definition, worktree), 'utf8');
  Object.assign(current, { status: 'running', agent: definition.agent, baseSha, branch, worktree, promptFile, startedAt: new Date().toISOString() });
  saveRun(stateRoot, state);
  return current;
}

async function verifyTask(stateRoot, state, definition, current) {
  const logFile = path.join(stateRoot, `${sanitize(definition.id)}.log`);
  for (const command of definition.verify) {
    const result = await runProcess('bash', ['-lc', command], { cwd: current.worktree, logFile, label: `${definition.id}:verify` });
    if (result.code !== 0) return { ok: false, command, code: result.code, logFile };
  }
  return { ok: true, logFile };
}

function failureDiff(stateRoot, taskId, worktree) {
  const output = path.join(stateRoot, `${sanitize(taskId)}.failure.diff`);
  try {
    git(['-C', worktree, 'add', '-N', '.'], { allowFailure: true });
    const result = spawnSync('git', ['-C', worktree, 'diff', '--binary'], { encoding: 'utf8' });
    writeFileSync(output, result.stdout || '', 'utf8');
    git(['-C', worktree, 'reset'], { allowFailure: true });
  } catch { /* best effort */ }
  return output;
}

function autoCommit(worktree, taskId) {
  if (git(['-C', worktree, 'status', '--porcelain']).stdout) {
    git(['-C', worktree, 'add', '-A']);
    git(['-C', worktree, '-c', 'user.name=agent-harness', '-c', 'user.email=agent-harness@local', 'commit', '-m', `agent(${taskId}): automated task`]);
  }
  return git(['-C', worktree, 'rev-parse', 'HEAD']).stdout;
}

export function prepare(planArg) {
  if (!planArg) throw new Error('prepare requires a plan.json path');
  const sourceRoot = repoRoot();
  const planPath = path.resolve(process.cwd(), planArg);
  const plan = loadPlan(planPath);
  validatePlan(plan);

  const runId = newRunId(plan);
  const stateRoot = path.join(runsRoot(sourceRoot), runId);
  const shadowRoot = path.join(stateRoot, 'repo');
  mkdirSync(stateRoot, { recursive: true });

  const baseRef = plan.base || 'HEAD';
  const sourceBaseSha = git(['-C', sourceRoot, 'rev-parse', `${baseRef}^{commit}`]).stdout;
  git(['clone', '--quiet', '--no-hardlinks', sourceRoot, shadowRoot]);
  git(['-C', shadowRoot, 'checkout', '--quiet', '--detach', sourceBaseSha]);
  syncWorkingTree(sourceRoot, shadowRoot);
  git(['-C', shadowRoot, 'add', '-A']);
  const callerDirty = Boolean(git(['-C', shadowRoot, 'status', '--porcelain']).stdout);
  if (callerDirty) {
    git(['-C', shadowRoot, '-c', 'user.name=agent-harness', '-c', 'user.email=agent-harness@local', 'commit', '--quiet', '-m', 'agent-harness: caller worktree baseline']);
  }
  const baselineSha = git(['-C', shadowRoot, 'rev-parse', 'HEAD']).stdout;
  const integrationBranch = `agent/orchestrate-${runId}`;
  git(['-C', shadowRoot, 'checkout', '-b', integrationBranch]);

  const state = {
    version: 2,
    runId,
    status: 'running',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    sourceRoot,
    stateRoot,
    shadowRoot,
    sourceBaseSha,
    baselineSha,
    callerDirty,
    integrationBranch,
    plan,
    tasks: plan.tasks.map((task) => ({ id: task.id, status: 'pending' })),
    review: plan.review ? { status: 'pending', agent: plan.review.agent, verdict: null } : null,
    delivery: null,
  };
  writeJson(path.join(stateRoot, 'plan.json'), plan);
  saveRun(stateRoot, state);

  console.log(`RUN     ${runId}`);
  console.log('STATUS  running');
  console.log(`BASELINE ${callerDirty ? 'caller-worktree' : 'committed-head'} ${baselineSha.slice(0, 12)}`);
  console.log(`STATE   ${stateRoot}`);
  console.log(`NEXT    agent-harness orchestrate ready ${runId}`);
  return runId;
}

export function ready(token = 'latest') {
  const { runId, stateRoot, state } = loadRun(token);
  refreshStatus(state);
  saveRun(stateRoot, state);
  const readyTasks = state.plan.tasks.filter((task) => {
    const current = taskState(state, task.id);
    return current.status === 'pending' && task.dependsOn.every((dep) => taskState(state, dep).status === 'success');
  });
  console.log(`RUN     ${runId}`);
  console.log(`STATUS  ${state.status}`);
  if (!readyTasks.length) console.log('READY   none');
  for (const task of readyTasks) console.log(`READY   ${task.id} agent=${task.agent}`);
  return readyTasks;
}

export function prepareTask(token, taskId) {
  if (!taskId) throw new Error('task requires a task id');
  const { runId, stateRoot, state } = loadRun(token);
  const current = ensureTaskWorktree(stateRoot, state, taskId);
  const definition = taskDef(state, taskId);
  const prompt = readFileSync(current.promptFile, 'utf8');
  console.log(`RUN     ${runId}`);
  console.log(`TASK    ${taskId}`);
  console.log(`AGENT   ${definition.agent}`);
  console.log(`WORKTREE ${current.worktree}`);
  if (definition.model) console.log(`MODEL   ${definition.model}`);
  console.log(`PROMPT_FILE ${current.promptFile}`);
  console.log('PROMPT_BEGIN');
  console.log(prompt);
  console.log('PROMPT_END');
  return { state, current, definition, prompt };
}

export async function completeTask(token, taskId) {
  if (!taskId) throw new Error('complete requires a task id');
  const { runId, stateRoot, state } = loadRun(token);
  const definition = taskDef(state, taskId);
  const current = taskState(state, taskId);
  if (current.status !== 'running' || !current.worktree || !existsSync(current.worktree)) throw new Error(`task ${taskId} has no active worktree`);

  const checked = await verifyTask(stateRoot, state, definition, current);
  if (!checked.ok) {
    current.status = 'failed';
    current.phase = 'verification';
    current.command = checked.command;
    current.code = checked.code;
    current.logFile = checked.logFile;
    current.diffFile = failureDiff(stateRoot, taskId, current.worktree);
    cleanupWorktree(state, current.worktree);
    refreshStatus(state);
    saveRun(stateRoot, state);
    console.log(`FAIL    ${taskId} phase=verification command=${checked.command}`);
    return current;
  }

  const headSha = autoCommit(current.worktree, taskId);
  if (git(['-C', current.worktree, 'merge-base', '--is-ancestor', current.baseSha, headSha], { allowFailure: true }).status !== 0) {
    current.status = 'failed';
    current.phase = 'git-history';
    current.error = 'task rewrote history outside its assigned base';
    cleanupWorktree(state, current.worktree);
    refreshStatus(state);
    saveRun(stateRoot, state);
    console.log(`FAIL    ${taskId} phase=git-history`);
    return current;
  }

  const count = Number(git(['-C', state.shadowRoot, 'rev-list', '--count', `${current.baseSha}..${headSha}`]).stdout || '0');
  if (count > 0) {
    const merged = spawnSync('git', ['-C', state.shadowRoot, '-c', 'user.name=agent-harness', '-c', 'user.email=agent-harness@local', 'merge', '--no-ff', '--no-edit', headSha], { encoding: 'utf8' });
    if (merged.status !== 0) {
      git(['-C', state.shadowRoot, 'merge', '--abort'], { allowFailure: true });
      current.status = 'failed';
      current.phase = 'integration';
      current.error = (merged.stderr || merged.stdout || 'merge conflict').trim();
      current.diffFile = failureDiff(stateRoot, taskId, current.worktree);
      cleanupWorktree(state, current.worktree);
      refreshStatus(state);
      saveRun(stateRoot, state);
      console.log(`FAIL    ${taskId} phase=integration`);
      return current;
    }
  }

  current.status = 'success';
  current.phase = 'complete';
  current.headSha = headSha;
  current.integratedSha = git(['-C', state.shadowRoot, 'rev-parse', 'HEAD']).stdout;
  current.logFile = checked.logFile;
  current.completedAt = new Date().toISOString();
  cleanupWorktree(state, current.worktree);
  delete current.worktree;
  refreshStatus(state);
  saveRun(stateRoot, state);
  console.log(`DONE    ${taskId}`);
  console.log(`STATUS  ${state.status}`);
  return current;
}

export function failTask(token, taskId, reason = 'agent failed') {
  if (!taskId) throw new Error('fail requires a task id');
  const { stateRoot, state } = loadRun(token);
  const current = taskState(state, taskId);
  if (current.worktree) cleanupWorktree(state, current.worktree);
  current.status = 'failed';
  current.phase = 'agent';
  current.reason = reason;
  current.completedAt = new Date().toISOString();
  delete current.worktree;
  refreshStatus(state);
  saveRun(stateRoot, state);
  console.log(`FAIL    ${taskId} reason=${reason}`);
  return current;
}

export async function runAgyTask(token, taskId) {
  const prepared = prepareTask(token, taskId);
  if (prepared.definition.agent !== 'agy') throw new Error(`task ${taskId} is assigned to ${prepared.definition.agent}, not agy`);
  if (!commandExists('agy')) {
    failTask(token, taskId, 'agy command not found');
    return;
  }
  const logFile = path.join(prepared.state.stateRoot, `${sanitize(taskId)}.log`);
  const result = await invokeAgy({
    cwd: prepared.current.worktree,
    prompt: prepared.prompt,
    model: prepared.definition.model,
    approval: prepared.definition.approval,
    logFile,
    taskId,
  });
  if (result.code !== 0) {
    failTask(token, taskId, result.error || `agy exited ${result.code}`);
    return;
  }
  await completeTask(token, taskId);
}

function ensureReviewWorktree(stateRoot, state) {
  if (!state.plan.review) throw new Error('plan has no final review');
  if (!state.tasks.every((task) => task.status === 'success')) throw new Error('all tasks must succeed before final review');
  if (state.review?.status === 'running' && state.review.worktree && existsSync(state.review.worktree)) return state.review;
  if (state.review?.verdict) throw new Error(`review already completed with ${state.review.verdict}`);

  const reviewRoot = path.join(stateRoot, 'worktrees');
  const worktree = path.join(reviewRoot, 'review');
  mkdirSync(reviewRoot, { recursive: true });
  git(['-C', state.shadowRoot, 'worktree', 'add', '--detach', worktree, 'HEAD']);
  const promptFile = path.join(stateRoot, 'review.prompt.txt');
  writeFileSync(promptFile, reviewPrompt(state.plan, worktree), 'utf8');
  state.review = { status: 'running', agent: state.plan.review.agent, verdict: null, worktree, promptFile, startedAt: new Date().toISOString() };
  state.status = 'review_running';
  saveRun(stateRoot, state);
  return state.review;
}

export function prepareReview(token = 'latest') {
  const { runId, stateRoot, state } = loadRun(token);
  refreshStatus(state);
  const review = ensureReviewWorktree(stateRoot, state);
  const prompt = readFileSync(review.promptFile, 'utf8');
  console.log(`RUN     ${runId}`);
  console.log(`REVIEW  agent=${state.plan.review.agent}`);
  console.log(`WORKTREE ${review.worktree}`);
  if (state.plan.review.model) console.log(`MODEL   ${state.plan.review.model}`);
  console.log(`PROMPT_FILE ${review.promptFile}`);
  console.log('PROMPT_BEGIN');
  console.log(prompt);
  console.log('PROMPT_END');
  return { state, review, prompt };
}

export function recordReview(token, rawVerdict) {
  const verdict = String(rawVerdict || '').toUpperCase();
  if (!['PASS', 'BLOCK'].includes(verdict)) throw new Error('review verdict must be PASS or BLOCK');
  const { stateRoot, state } = loadRun(token);
  if (!state.review?.worktree) throw new Error('no active review worktree');
  cleanupWorktree(state, state.review.worktree);
  state.review.status = verdict === 'PASS' ? 'success' : 'blocked';
  state.review.verdict = verdict;
  state.review.completedAt = new Date().toISOString();
  delete state.review.worktree;
  refreshStatus(state);
  saveRun(stateRoot, state);
  console.log(`REVIEW  ${state.review.status} verdict=${verdict}`);
  console.log(`STATUS  ${state.status}`);
  return state.review;
}

export async function runAgyReview(token = 'latest') {
  const prepared = prepareReview(token);
  if (prepared.state.plan.review.agent !== 'agy') throw new Error(`review is assigned to ${prepared.state.plan.review.agent}, not agy`);
  if (!commandExists('agy')) throw new Error('agy command not found');
  const logFile = path.join(prepared.state.stateRoot, 'review.log');
  const result = await invokeAgy({
    cwd: prepared.review.worktree,
    prompt: prepared.prompt,
    model: prepared.state.plan.review.model,
    approval: prepared.state.plan.review.approval,
    logFile,
    taskId: 'review',
  });
  if (result.code !== 0) {
    recordReview(token, 'BLOCK');
    return;
  }
  const matches = [...String(result.stdout || '').matchAll(/VERDICT:\s*(PASS|BLOCK)\b/gi)];
  const verdict = matches.length ? matches.at(-1)[1].toUpperCase() : 'BLOCK';
  recordReview(token, verdict);
}

export function deliver(token = 'latest') {
  const { runId, stateRoot, state } = loadRun(token);
  refreshStatus(state);
  if (!state.tasks.every((task) => task.status === 'success')) throw new Error('all tasks must succeed before delivery');
  if (state.plan.review && state.review?.verdict !== 'PASS') throw new Error('final review must return PASS before delivery');

  const finalHead = git(['-C', state.shadowRoot, 'rev-parse', 'HEAD']).stdout;
  const patchFile = path.join(stateRoot, 'result.patch');
  const diff = spawnSync('git', ['-C', state.shadowRoot, 'diff', '--binary', `${state.baselineSha}..${finalHead}`], { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
  if (diff.status !== 0) throw new Error((diff.stderr || diff.stdout || 'could not create result patch').trim());
  writeFileSync(patchFile, diff.stdout || '', 'utf8');

  let delivery;
  if (!diff.stdout) {
    delivery = { applied: true, patchFile, noChanges: true };
  } else {
    const checked = spawnSync('git', ['-C', state.sourceRoot, 'apply', '--check', '--binary', patchFile], { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
    if (checked.status !== 0) {
      delivery = { applied: false, patchFile, error: (checked.stderr || checked.stdout || 'result patch no longer applies cleanly').trim() };
    } else {
      const applied = spawnSync('git', ['-C', state.sourceRoot, 'apply', '--binary', patchFile], { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
      delivery = applied.status === 0
        ? { applied: true, patchFile, noChanges: false }
        : { applied: false, patchFile, error: (applied.stderr || applied.stdout || 'could not apply result patch').trim() };
    }
  }

  state.delivery = delivery;
  state.finalHead = finalHead;
  state.status = delivery.applied ? 'success' : 'failed';
  state.completedAt = new Date().toISOString();
  saveRun(stateRoot, state);
  console.log(`RUN     ${runId}`);
  console.log(`STATUS  ${state.status}`);
  console.log(`APPLIED ${delivery.applied ? 'yes' : 'no'}`);
  console.log(`PATCH   ${patchFile}`);
  if (delivery.error) console.log(`ERROR   ${delivery.error}`);
  return delivery;
}

export function status(token = 'latest') {
  const { runId, stateRoot, state } = loadRun(token);
  refreshStatus(state);
  saveRun(stateRoot, state);
  console.log(`RUN     ${runId}`);
  console.log(`STATUS  ${state.status}`);
  for (const task of state.tasks) {
    const definition = taskDef(state, task.id);
    console.log(`TASK    ${task.id} ${task.status} agent=${definition.agent}${task.phase ? ` phase=${task.phase}` : ''}`);
  }
  if (state.review) console.log(`REVIEW  ${state.review.status} agent=${state.review.agent} verdict=${state.review.verdict || 'UNKNOWN'}`);
  if (state.delivery) console.log(`APPLIED ${state.delivery.applied ? 'yes' : 'no'}`);
  console.log(`STATE   ${stateRoot}`);
  return state;
}

export function abort(token = 'latest') {
  const { runId, stateRoot, state } = loadRun(token);
  for (const task of state.tasks) if (task.worktree) cleanupWorktree(state, task.worktree);
  if (state.review?.worktree) cleanupWorktree(state, state.review.worktree);
  state.status = 'aborted';
  state.completedAt = new Date().toISOString();
  saveRun(stateRoot, state);
  console.log(`RUN     ${runId}`);
  console.log('STATUS  aborted');
}

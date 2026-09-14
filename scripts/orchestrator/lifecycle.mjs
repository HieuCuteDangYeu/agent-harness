import {
  closeSync,
  cpSync,
  existsSync,
  mkdirSync,
  openSync,
  readFileSync,
  readdirSync,
  rmSync,
  statSync,
  writeFileSync,
} from 'node:fs';
import { spawn } from 'node:child_process';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import os from 'node:os';
import path from 'node:path';
import { git, loadPlan, sanitize, validatePlan } from './core.mjs';

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
  if (!existsSync(file)) return null;
  try { return JSON.parse(readFileSync(file, 'utf8')); }
  catch { return null; }
}

function processAlive(pid) {
  if (!Number.isInteger(pid) || pid <= 0) return false;
  try { process.kill(pid, 0); return true; }
  catch { return false; }
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

function nulList(text) {
  return String(text || '').split('\0').filter(Boolean);
}

function syncWorkingTree(sourceRoot, shadowRoot) {
  const tracked = nulList(git(['-C', sourceRoot, 'ls-files', '-z']).stdout);
  const untracked = nulList(git(['-C', sourceRoot, 'ls-files', '--others', '--exclude-standard', '-z']).stdout);
  const paths = new Set([...tracked, ...untracked]);

  for (const rel of paths) {
    const source = path.join(sourceRoot, rel);
    const target = path.join(shadowRoot, rel);
    if (!existsSync(source)) {
      rmSync(target, { recursive: true, force: true });
      continue;
    }
    mkdirSync(path.dirname(target), { recursive: true });
    rmSync(target, { recursive: true, force: true });
    cpSync(source, target, {
      recursive: true,
      force: true,
      dereference: false,
      preserveTimestamps: true,
    });
  }
}

function prepareShadowRepo(sourceRoot, stateRoot, plan) {
  const baseRef = plan.base || 'HEAD';
  const baseSha = git(['-C', sourceRoot, 'rev-parse', `${baseRef}^{commit}`]).stdout;
  const shadowRoot = path.join(stateRoot, 'repo');

  git(['clone', '--quiet', '--no-hardlinks', sourceRoot, shadowRoot]);
  git(['-C', shadowRoot, 'checkout', '--quiet', '--detach', baseSha]);
  syncWorkingTree(sourceRoot, shadowRoot);
  git(['-C', shadowRoot, 'add', '-A']);

  const dirty = Boolean(git(['-C', shadowRoot, 'status', '--porcelain']).stdout);
  if (dirty) {
    git([
      '-C', shadowRoot,
      '-c', 'user.name=agent-harness',
      '-c', 'user.email=agent-harness@local',
      'commit', '--quiet', '-m', 'agent-harness: caller worktree baseline',
    ]);
  }

  const baselineSha = git(['-C', shadowRoot, 'rev-parse', 'HEAD']).stdout;
  const effectivePlan = { ...plan, base: 'HEAD' };
  const effectivePlanPath = path.join(stateRoot, 'plan.effective.json');
  writeFileSync(path.join(stateRoot, 'plan.original.json'), `${JSON.stringify(plan, null, 2)}\n`, 'utf8');
  writeFileSync(effectivePlanPath, `${JSON.stringify(effectivePlan, null, 2)}\n`, 'utf8');

  return { baseRef, baseSha, baselineSha, dirty, shadowRoot, effectivePlanPath };
}

export function startDetached(planArg) {
  if (!planArg) throw new Error('start requires a plan.json path');
  const sourceRoot = repoRoot();
  const planPath = path.resolve(process.cwd(), planArg);
  const plan = loadPlan(planPath);
  validatePlan(plan, null);

  const runId = newRunId(plan);
  const stateRoot = path.join(runsRoot(sourceRoot), runId);
  const logFile = path.join(stateRoot, 'orchestrator.log');
  mkdirSync(stateRoot, { recursive: true });

  const baseline = prepareShadowRepo(sourceRoot, stateRoot, plan);
  writeFileSync(path.join(stateRoot, 'status.json'), `${JSON.stringify({
    runId,
    status: 'starting',
    plan: plan.name || null,
    goal: plan.goal,
    stateRoot,
    sourceRoot,
    shadowRoot: baseline.shadowRoot,
    baselineSha: baseline.baselineSha,
    callerDirty: baseline.dirty,
    tasks: plan.tasks.map((task) => ({ id: task.id, status: 'pending' })),
  }, null, 2)}\n`, 'utf8');

  const logFd = openSync(logFile, 'a');
  const script = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', 'orchestrate.mjs');
  const child = spawn(process.execPath, [script, baseline.effectivePlanPath], {
    cwd: baseline.shadowRoot,
    env: {
      ...process.env,
      AGENT_HARNESS_RUN_ID: runId,
      AGENT_HARNESS_STATE_ROOT: stateRoot,
      AGENT_HARNESS_SOURCE_REPO: sourceRoot,
      AGENT_HARNESS_SHADOW_REPO: baseline.shadowRoot,
      AGENT_HARNESS_CALLER_BASE_SHA: baseline.baselineSha,
    },
    detached: true,
    stdio: ['ignore', logFd, logFd],
  });
  child.unref();
  closeSync(logFd);

  writeFileSync(path.join(stateRoot, 'process.json'), `${JSON.stringify({
    runId,
    pid: child.pid,
    originalPlanPath: planPath,
    effectivePlanPath: baseline.effectivePlanPath,
    sourceRoot,
    shadowRoot: baseline.shadowRoot,
    baselineSha: baseline.baselineSha,
    callerDirty: baseline.dirty,
    stateRoot,
    logFile,
    startedAt: new Date().toISOString(),
  }, null, 2)}\n`, 'utf8');

  console.log(`RUN     ${runId}`);
  console.log('STATUS  started');
  console.log(`PID     ${child.pid}`);
  console.log(`BASELINE ${baseline.dirty ? 'caller-worktree' : 'committed-head'} ${baseline.baselineSha.slice(0, 12)}`);
  console.log(`STATE   ${stateRoot}`);
  console.log(`LOG     ${logFile}`);
  console.log(`WATCH   agent-harness orchestrate status ${runId}`);
  return runId;
}

export function showStatus(token = 'latest') {
  const root = repoRoot();
  const { runId, stateRoot } = resolveRun(root, token);
  const status = readJson(path.join(stateRoot, 'status.json'));
  const summary = readJson(path.join(stateRoot, 'summary.json'));
  const proc = readJson(path.join(stateRoot, 'process.json'));
  let phase = summary?.status || status?.status || 'running';
  if (!summary && phase !== 'starting') phase = 'running';
  if (!summary && proc && !processAlive(proc.pid)) phase = 'failed';

  console.log(`RUN     ${runId}`);
  console.log(`STATUS  ${phase}`);
  if (proc?.pid) console.log(`PID     ${proc.pid}${processAlive(proc.pid) ? ' running' : ' exited'}`);
  const branch = summary?.integrationBranch || status?.integrationBranch;
  if (branch) console.log(`BRANCH  ${branch}`);
  if (summary?.delivery) {
    console.log(`APPLIED ${summary.delivery.applied ? 'yes' : 'no'}`);
    if (summary.delivery.patchFile) console.log(`PATCH   ${summary.delivery.patchFile}`);
  }
  console.log(`STATE   ${stateRoot}`);
  if (status?.tasks) {
    for (const task of status.tasks) {
      const agent = task.agent ? ` agent=${task.agent}` : '';
      console.log(`TASK    ${task.id} ${task.status}${agent}${task.phase ? ` phase=${task.phase}` : ''}`);
    }
  }
  if (summary?.review) console.log(`REVIEW  ${summary.review.status} verdict=${summary.review.verdict}`);
  return { runId, stateRoot, status: phase, summary, snapshot: status };
}

export function showLogs(token = 'latest', rawLines = '80') {
  const root = repoRoot();
  const { runId, stateRoot } = resolveRun(root, token);
  const logFile = path.join(stateRoot, 'orchestrator.log');
  const lines = Number(rawLines);
  if (!Number.isInteger(lines) || lines < 1 || lines > 5000) throw new Error('log line count must be an integer from 1 to 5000');
  console.log(`RUN     ${runId}`);
  console.log(`LOG     ${logFile}`);
  if (!existsSync(logFile)) return;
  const content = readFileSync(logFile, 'utf8').split(/\r?\n/);
  console.log(content.slice(-lines).join('\n'));
}

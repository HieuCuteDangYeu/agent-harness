import { closeSync, existsSync, mkdirSync, openSync, readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { git, loadPlan, sanitize, validatePlan } from './core.mjs';

function repoRoot() {
  return git(['rev-parse', '--show-toplevel'], { cwd: process.cwd() }).stdout;
}

function commonGitDir(root) {
  const common = git(['-C', root, 'rev-parse', '--git-common-dir']).stdout;
  return path.resolve(root, common);
}

function runsRoot(root) {
  return path.join(commonGitDir(root), 'agent-harness', 'runs');
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

export function startDetached(planArg) {
  if (!planArg) throw new Error('start requires a plan.json path');
  const root = repoRoot();
  const planPath = path.resolve(process.cwd(), planArg);
  const plan = loadPlan(planPath);
  validatePlan(plan, null);
  if (git(['-C', root, 'status', '--porcelain']).stdout) {
    throw new Error('caller worktree is dirty; commit/stash before orchestration');
  }

  const runId = newRunId(plan);
  const stateRoot = path.join(runsRoot(root), runId);
  const logFile = path.join(stateRoot, 'orchestrator.log');
  mkdirSync(stateRoot, { recursive: true });
  writeFileSync(path.join(stateRoot, 'status.json'), `${JSON.stringify({
    runId,
    status: 'starting',
    plan: plan.name || null,
    goal: plan.goal,
    stateRoot,
    tasks: plan.tasks.map((task) => ({ id: task.id, status: 'pending' })),
  }, null, 2)}\n`, 'utf8');

  const logFd = openSync(logFile, 'a');
  const script = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', 'orchestrate.mjs');
  const child = spawn(process.execPath, [script, planPath], {
    cwd: root,
    env: { ...process.env, AGENT_HARNESS_RUN_ID: runId },
    detached: true,
    stdio: ['ignore', logFd, logFd],
  });
  child.unref();
  closeSync(logFd);

  writeFileSync(path.join(stateRoot, 'process.json'), `${JSON.stringify({
    runId,
    pid: child.pid,
    planPath,
    stateRoot,
    logFile,
    startedAt: new Date().toISOString(),
  }, null, 2)}\n`, 'utf8');

  console.log(`RUN     ${runId}`);
  console.log(`STATUS  started`);
  console.log(`PID     ${child.pid}`);
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
  console.log(`STATE   ${stateRoot}`);
  if (status?.tasks) {
    for (const task of status.tasks) console.log(`TASK    ${task.id} ${task.status}${task.phase ? ` phase=${task.phase}` : ''}`);
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

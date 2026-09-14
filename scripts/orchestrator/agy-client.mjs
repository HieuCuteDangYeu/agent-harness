import { createHash, randomBytes } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, realpathSync, renameSync, statSync, writeFileSync } from 'node:fs';
import path from 'node:path';

function uid() {
  return typeof process.getuid === 'function' ? process.getuid() : 'user';
}

export function agyQueueRoot() {
  return process.env.AGENT_HARNESS_AGY_QUEUE_DIR || path.join('/tmp', `agent-harness-agy-${uid()}`);
}

export function harnessStateRoot() {
  return path.resolve(process.env.AGENT_HARNESS_STATE_DIR || path.join('/tmp', 'agent-harness-state'));
}

function queuePath(...parts) {
  return path.join(agyQueueRoot(), ...parts);
}

function ensureQueue() {
  mkdirSync(agyQueueRoot(), { recursive: true, mode: 0o700 });
  for (const dir of ['pending', 'running', 'results', 'logs']) {
    mkdirSync(queuePath(dir), { recursive: true, mode: 0o700 });
  }
}

function readJson(file) {
  return JSON.parse(readFileSync(file, 'utf8'));
}

function isInside(root, candidate) {
  const rel = path.relative(root, candidate);
  return rel && !rel.startsWith('..') && !path.isAbsolute(rel);
}

export function validateAgyCwd(cwd, taskId = 'agy-task') {
  if (!path.isAbsolute(cwd)) throw new Error('agy job cwd must be an absolute path');
  if (!existsSync(cwd)) throw new Error(`agy job cwd does not exist: ${cwd}`);

  const resolved = realpathSync(cwd);
  const stateRoot = harnessStateRoot();
  if (!isInside(stateRoot, resolved)) {
    throw new Error(`agy host jobs may run only inside agent-harness state: ${stateRoot}`);
  }

  const rel = path.relative(stateRoot, resolved);
  const parts = rel.split(path.sep);
  if (taskId === 'doctor') {
    if (parts[0] !== 'agy-doctor') throw new Error('agy doctor cwd is outside the dedicated doctor area');
    return resolved;
  }

  const worktreesIndex = parts.indexOf('worktrees');
  const runsIndex = parts.indexOf('runs');
  if (runsIndex < 1 || worktreesIndex !== runsIndex + 2 || worktreesIndex === parts.length - 1) {
    throw new Error('agy host jobs may run only inside orchestrator task/review worktrees');
  }
  if (!existsSync(path.join(resolved, '.git'))) {
    throw new Error('agy host job cwd is not an orchestrator Git worktree');
  }
  return resolved;
}

export function agyRunnerStatus({ maxAgeMs = 10000 } = {}) {
  const heartbeat = queuePath('runner.json');
  if (!existsSync(heartbeat)) return { ready: false, reason: 'host runner heartbeat missing' };
  try {
    const data = readJson(heartbeat);
    const mtime = statSync(heartbeat).mtimeMs;
    if (Date.now() - mtime > maxAgeMs) return { ready: false, reason: 'host runner heartbeat is stale', ...data };
    return { ready: true, ...data };
  } catch (error) {
    return { ready: false, reason: `invalid host runner heartbeat: ${error.message}` };
  }
}

function stableJobId(idempotencyKey) {
  if (!idempotencyKey) return `${Date.now()}-${randomBytes(4).toString('hex')}`;
  return `job-${createHash('sha256').update(idempotencyKey).digest('hex').slice(0, 24)}`;
}

export function getAgyJob(id) {
  if (!id) throw new Error('agy job id is required');
  const resultFile = queuePath('results', `${id}.json`);
  if (existsSync(resultFile)) return { state: 'complete', result: readJson(resultFile), resultFile };
  if (existsSync(queuePath('running', `${id}.json`))) return { state: 'running' };
  if (existsSync(queuePath('pending', `${id}.json`))) return { state: 'pending' };
  return { state: 'missing' };
}

export function submitAgyJob({ cwd, prompt, model = null, approval = null, timeout = '15m', taskId = 'agy-task', idempotencyKey = null }) {
  const runner = agyRunnerStatus();
  if (!runner.ready) {
    throw new Error(`agy host runner unavailable: ${runner.reason}. Start it from a normal terminal with: agent-harness agy start`);
  }
  const safeCwd = validateAgyCwd(cwd, taskId);
  if (typeof prompt !== 'string' || !prompt.trim()) throw new Error('agy job prompt is required');
  if (approval === 'yolo' && process.env.AGENT_HARNESS_AGY_ALLOW_YOLO !== '1') {
    throw new Error('agy yolo mode is disabled; explicitly opt in when starting the host runner with AGENT_HARNESS_AGY_ALLOW_YOLO=1');
  }
  ensureQueue();

  const id = stableJobId(idempotencyKey);
  const existing = getAgyJob(id);
  if (existing.state !== 'missing') return { id, reused: true, state: existing.state };

  const job = {
    version: 1,
    id,
    cwd: safeCwd,
    prompt,
    model,
    approval,
    timeout,
    taskId,
    submittedAt: new Date().toISOString(),
  };
  const temp = queuePath('pending', `.${id}.tmp`);
  const target = queuePath('pending', `${id}.json`);
  writeFileSync(temp, `${JSON.stringify(job, null, 2)}\n`, { encoding: 'utf8', mode: 0o600 });
  renameSync(temp, target);
  return { id, reused: false, state: 'pending' };
}

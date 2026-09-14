import { randomBytes } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, renameSync, statSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';

function uid() {
  return typeof process.getuid === 'function' ? process.getuid() : 'user';
}

export function agyQueueRoot() {
  return process.env.AGENT_HARNESS_AGY_QUEUE_DIR || path.join(os.tmpdir(), `agent-harness-agy-${uid()}`);
}

function queuePath(...parts) {
  return path.join(agyQueueRoot(), ...parts);
}

function ensureQueue() {
  for (const dir of ['pending', 'running', 'results', 'logs']) {
    mkdirSync(queuePath(dir), { recursive: true, mode: 0o700 });
  }
}

function readJson(file) {
  return JSON.parse(readFileSync(file, 'utf8'));
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

export function submitAgyJob({ cwd, prompt, model = null, approval = null, timeout = '15m', taskId = 'agy-task' }) {
  const runner = agyRunnerStatus();
  if (!runner.ready) {
    throw new Error(`agy host runner unavailable: ${runner.reason}. Start it from a normal terminal with: agent-harness agy start`);
  }
  if (!path.isAbsolute(cwd)) throw new Error('agy job cwd must be an absolute path');
  if (!existsSync(cwd)) throw new Error(`agy job cwd does not exist: ${cwd}`);
  if (typeof prompt !== 'string' || !prompt.trim()) throw new Error('agy job prompt is required');
  ensureQueue();

  const id = `${Date.now()}-${randomBytes(4).toString('hex')}`;
  const job = {
    version: 1,
    id,
    cwd,
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
  return { id, job };
}

export function getAgyJob(id) {
  if (!id) throw new Error('agy job id is required');
  const resultFile = queuePath('results', `${id}.json`);
  if (existsSync(resultFile)) return { state: 'complete', result: readJson(resultFile), resultFile };
  if (existsSync(queuePath('running', `${id}.json`))) return { state: 'running' };
  if (existsSync(queuePath('pending', `${id}.json`))) return { state: 'pending' };
  return { state: 'missing' };
}

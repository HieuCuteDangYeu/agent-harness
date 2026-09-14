#!/usr/bin/env node
import { spawn } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, readdirSync, renameSync, rmSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { agyQueueRoot, harnessStateRoot, validateAgyCwd } from './orchestrator/agy-client.mjs';

const queueRoot = agyQueueRoot();
const dirs = Object.fromEntries(['pending', 'running', 'results', 'logs'].map((name) => [name, path.join(queueRoot, name)]));
let stopping = false;
let activeChild = null;

function ensureDirs() {
  mkdirSync(queueRoot, { recursive: true, mode: 0o700 });
  for (const dir of Object.values(dirs)) mkdirSync(dir, { recursive: true, mode: 0o700 });
}

function recoverInterruptedJobs() {
  for (const name of readdirSync(dirs.running).filter((entry) => entry.endsWith('.json'))) {
    const resultFile = path.join(dirs.results, name);
    const runningFile = path.join(dirs.running, name);
    if (existsSync(resultFile)) rmSync(runningFile, { force: true });
    else renameSync(runningFile, path.join(dirs.pending, name));
  }
}

function writeHeartbeat() {
  const file = path.join(queueRoot, 'runner.json');
  writeFileSync(file, `${JSON.stringify({
    pid: process.pid,
    host: os.hostname(),
    startedBy: process.env.USER || null,
    stateRoot: harnessStateRoot(),
    allowYolo: process.env.AGENT_HARNESS_AGY_ALLOW_YOLO === '1',
    updatedAt: new Date().toISOString(),
  }, null, 2)}\n`, { encoding: 'utf8', mode: 0o600 });
}

function readJson(file) {
  return JSON.parse(readFileSync(file, 'utf8'));
}

function safeJson(line) {
  try { return JSON.parse(line); }
  catch { return null; }
}

function writeRejectedResult(job, resultFile, error, startedAt) {
  writeFileSync(resultFile, `${JSON.stringify({
    version: 1,
    id: job.id || null,
    taskId: job.taskId || null,
    status: 'failed',
    code: 2,
    signal: null,
    error,
    agyStatus: null,
    response: null,
    stderrTail: '',
    stdoutTail: '',
    logFile: null,
    startedAt,
    finishedAt: new Date().toISOString(),
  }, null, 2)}\n`, { encoding: 'utf8', mode: 0o600 });
}

async function runJob(jobFile) {
  const name = path.basename(jobFile);
  const runningFile = path.join(dirs.running, name);
  try { renameSync(jobFile, runningFile); }
  catch { return; }

  const job = readJson(runningFile);
  const logFile = path.join(dirs.logs, `${job.id}.log`);
  const resultFile = path.join(dirs.results, `${job.id}.json`);
  const startedAt = new Date().toISOString();

  let safeCwd;
  try {
    safeCwd = validateAgyCwd(job.cwd, job.taskId || 'agy-task');
    if (job.approval === 'yolo' && process.env.AGENT_HARNESS_AGY_ALLOW_YOLO !== '1') {
      throw new Error('agy yolo mode is disabled on this host runner');
    }
  } catch (error) {
    writeRejectedResult(job, resultFile, error.message, startedAt);
    rmSync(runningFile, { force: true });
    return;
  }

  const args = ['--print', job.prompt, '--print-timeout', job.timeout || '15m', '--output-format', 'stream-json'];
  if (job.model) args.push('--model', job.model);
  if (job.approval === 'yolo') args.push('--dangerously-skip-permissions');

  let stdoutBuffer = '';
  let stderrTail = '';
  let finalEvent = null;

  const result = await new Promise((resolve) => {
    let settled = false;
    let streamBuffer = '';
    const child = spawn('agy', args, {
      cwd: safeCwd,
      env: { ...process.env, AGENT_HARNESS_TASK_ID: job.taskId || 'agy-task' },
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    activeChild = child;

    const appendLog = (text) => {
      writeFileSync(logFile, text, { encoding: 'utf8', flag: 'a', mode: 0o600 });
    };
    const parseLine = (line) => {
      const parsed = safeJson(line);
      if (parsed?.event === 'result' && parsed.result) finalEvent = parsed.result;
    };

    appendLog(`$ agy --print '[task packet omitted]' --print-timeout ${job.timeout || '15m'} --output-format stream-json${job.model ? ` --model ${job.model}` : ''}${job.approval === 'yolo' ? ' --dangerously-skip-permissions' : ''}\n`);

    child.stdout.on('data', (chunk) => {
      const text = chunk.toString();
      appendLog(text);
      stdoutBuffer = `${stdoutBuffer}${text}`.slice(-1024 * 1024);
      streamBuffer += text;
      const lines = streamBuffer.split(/\r?\n/);
      streamBuffer = lines.pop() || '';
      for (const line of lines) parseLine(line);
    });
    child.stderr.on('data', (chunk) => {
      const text = chunk.toString();
      appendLog(text);
      stderrTail = `${stderrTail}${text}`.slice(-16384);
    });
    child.on('error', (error) => {
      if (settled) return;
      settled = true;
      activeChild = null;
      resolve({ code: 127, error: error.message });
    });
    child.on('close', (code, signal) => {
      if (settled) return;
      settled = true;
      if (streamBuffer.trim()) parseLine(streamBuffer.trim());
      activeChild = null;
      resolve({ code: code ?? 1, signal });
    });
  });

  const permissionDenied = /permission|auto-denied|cannot prompt/i.test(stderrTail) && !String(finalEvent?.response || '').trim();
  const ok = result.code === 0 && finalEvent?.status === 'SUCCESS' && !permissionDenied;
  writeFileSync(resultFile, `${JSON.stringify({
    version: 1,
    id: job.id,
    taskId: job.taskId,
    status: ok ? 'success' : 'failed',
    code: result.code,
    signal: result.signal || null,
    error: result.error || (permissionDenied ? 'agy headless permission was denied' : null),
    agyStatus: finalEvent?.status || null,
    response: finalEvent?.response || null,
    stderrTail,
    stdoutTail: stdoutBuffer.slice(-16384),
    logFile,
    startedAt,
    finishedAt: new Date().toISOString(),
  }, null, 2)}\n`, { encoding: 'utf8', mode: 0o600 });
  rmSync(runningFile, { force: true });
}

function requestStop() {
  stopping = true;
  if (activeChild && !activeChild.killed) activeChild.kill('SIGTERM');
}

async function loop() {
  ensureDirs();
  recoverInterruptedJobs();
  writeHeartbeat();
  const heartbeat = setInterval(writeHeartbeat, 2000);
  heartbeat.unref();

  process.on('SIGTERM', requestStop);
  process.on('SIGINT', requestStop);

  while (!stopping) {
    const jobs = readdirSync(dirs.pending)
      .filter((name) => name.endsWith('.json'))
      .sort();
    if (jobs.length) await runJob(path.join(dirs.pending, jobs[0]));
    else await new Promise((resolve) => setTimeout(resolve, 250));
  }
  rmSync(path.join(queueRoot, 'runner.json'), { force: true });
}

if (process.argv[2] !== 'serve') {
  console.error('Usage: node scripts/agy-runner.mjs serve');
  process.exit(2);
}

loop().catch((error) => {
  console.error(error.stack || error.message);
  process.exit(1);
});

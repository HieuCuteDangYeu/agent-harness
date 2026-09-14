import { spawn, spawnSync } from 'node:child_process';
import { createWriteStream, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';

export const TASK_ID_RE = /^[A-Za-z0-9][A-Za-z0-9._-]*$/;
export const SUPPORTED_AGENTS = new Set(['codex', 'gemini']);

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
  const result = spawnSync('sh', ['-c', `command -v ${shellQuote(command)} >/dev/null 2>&1`], { env: process.env });
  return result.status === 0;
}

export function resolveAgent(requested) {
  if (requested === 'codex') {
    if (commandExists('codex')) return 'codex';
    if (commandExists('gemini')) return 'gemini';
    if (commandExists('agy')) return 'agy';
  }
  if (requested === 'gemini') {
    if (commandExists('gemini')) return 'gemini';
    if (commandExists('agy')) return 'agy';
    if (commandExists('codex')) return 'codex';
  }
  return null;
}

export function usage() {
  console.log(`agent-harness orchestrate start <plan.json>\nagent-harness orchestrate status [run-id|latest]\nagent-harness orchestrate logs [run-id|latest] [lines]\nagent-harness orchestrate <plan.json> [options]\nagent-harness orchestrate example\n\nNormal orchestrator use:\n  start                   Snapshot the current worktree into an isolated temporary repo and run detached.\n                          Existing committed, modified, deleted, and untracked non-ignored files become the baseline.\n                          The final verified patch is applied back to the caller worktree without writing caller .git metadata.\n  status                  Read durable run state without waiting on the agent process.\n  logs                    Tail the dispatcher log.\n\nForeground/debug options:\n  --dry-run               Validate and print the graph without running agents.\n  --max-parallel <n>      Override plan.maxParallel (default 2, max 8).\n  --keep-worktrees        Keep temporary worktrees for debugging.\n  --allow-dirty           Foreground only: ignore caller-worktree changes; they are NOT included.\n\nLogical agent roles are codex and gemini. At runtime the dispatcher prefers the requested\nexecutor, uses Antigravity (agy) for the gemini role when available, and falls back to the\nother installed executor when necessary.\n\nExecution is local-only. Detached mode avoids caller .git writes, runs agents in isolated\nworktrees, verifies tasks, integrates successful work, performs final review, and applies\nonly the verified result patch back to the caller worktree. It never pushes or merges remotely.`);
}

export function examplePlan() {
  console.log(JSON.stringify({
    version: 1,
    name: 'feature-change',
    goal: 'Implement the requested feature with independent work where safe.',
    base: 'HEAD',
    maxParallel: 2,
    tasks: [
      { id: 'implementation', agent: 'codex', prompt: 'Implement the requested behavior.', dependsOn: [], acceptanceCriteria: ['Required behavior is implemented'], verify: ['pnpm test'] },
      { id: 'tests', agent: 'gemini', prompt: 'Add focused tests for the requested behavior.', dependsOn: ['implementation'], acceptanceCriteria: ['Tests cover important paths'], verify: ['pnpm test'] },
    ],
    review: { agent: 'codex', prompt: 'Focus on architecture, security, concurrency, and missing tests.' },
  }, null, 2));
}

export function parseArgs(argv) {
  if (argv.length === 0 || argv.includes('--help') || argv.includes('-h')) { usage(); process.exit(0); }
  if (argv[0] === 'example') { examplePlan(); process.exit(0); }
  const options = { planPath: null, dryRun: false, maxParallel: null, keepWorktrees: false, allowDirty: false };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--dry-run') options.dryRun = true;
    else if (arg === '--keep-worktrees') options.keepWorktrees = true;
    else if (arg === '--allow-dirty') options.allowDirty = true;
    else if (arg === '--max-parallel') {
      const raw = argv[++i];
      if (!raw) die('--max-parallel requires a value');
      options.maxParallel = Number(raw);
    } else if (arg.startsWith('--')) die(`unknown option: ${arg}`);
    else if (!options.planPath) options.planPath = arg;
    else die(`unexpected argument: ${arg}`);
  }
  if (!options.planPath) die('plan.json is required');
  return options;
}

export function loadPlan(planPath) {
  try { return JSON.parse(readFileSync(planPath, 'utf8')); }
  catch (error) { die(`cannot read plan ${planPath}: ${error.message}`); }
}

function stringArray(value, field, taskId) {
  if (value === undefined) return [];
  if (!Array.isArray(value) || value.some((item) => typeof item !== 'string')) die(`${taskId ? `task ${taskId} ` : ''}${field} must be an array of strings`);
  return value;
}

export function validatePlan(plan, overrideParallel) {
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
    if (!SUPPORTED_AGENTS.has(task.agent)) die(`task ${task.id} agent must be codex or gemini`);
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
    if (!SUPPORTED_AGENTS.has(plan.review.agent)) die('plan.review.agent must be codex or gemini');
    if (plan.review.prompt !== undefined && typeof plan.review.prompt !== 'string') die('plan.review.prompt must be a string');
    if (plan.review.model !== undefined && typeof plan.review.model !== 'string') die('plan.review.model must be a string');
    if (plan.review.approval !== undefined && !['auto-edit', 'yolo'].includes(plan.review.approval)) die('plan.review.approval must be auto-edit or yolo');
  }
  const parallel = overrideParallel ?? plan.maxParallel ?? 2;
  if (!Number.isInteger(parallel) || parallel < 1 || parallel > 8) die('maxParallel must be an integer from 1 to 8');
  return parallel;
}

function section(title, items) {
  if (!items?.length) return '';
  return `\n${title}:\n${items.map((item) => `- ${item}`).join('\n')}\n`;
}

export function taskPrompt(plan, task) {
  return `You are an implementation executor launched by agent-harness.\n\nRead AGENTS.md and only repository skills relevant to this task before editing.\nFollow existing architecture and conventions. Make the smallest complete change.\nDo not create, delegate to, or wait for additional agents; you are the assigned executor.\nDo not push, merge, create a PR, or modify files outside this worktree.\n\nPlan goal:\n${plan.goal}\n\nAssigned task (${task.id}):\n${task.prompt}\n${section('Dependencies already integrated', task.dependsOn)}${section('Acceptance criteria', task.acceptanceCriteria)}${section('Constraints', task.constraints)}${section('Non-goals', task.nonGoals)}${section('Harness verification after you finish', task.verify)}\nInspect your diff before completion and leave the worktree ready to commit. You may commit, but it is not required.`;
}

export function reviewPrompt(plan, baseRef) {
  const tasks = plan.tasks.map((task) => `- ${task.id}: ${task.prompt}`).join('\n');
  const extra = plan.review?.prompt ? `\nAdditional review focus:\n${plan.review.prompt}\n` : '';
  return `Act as the final reviewer for an automatically integrated multi-agent change.\n\nDO NOT modify files. Do not create or delegate to additional agents. Review the current branch against base ${baseRef}.\nInspect the actual diff and relevant tests. Check correctness, architecture, security, concurrency/data integrity, compatibility, and meaningful test coverage.\n\nPlan goal:\n${plan.goal}\n\nExecuted tasks:\n${tasks}\n${extra}\nEnd with exactly one line:\nVERDICT: PASS\nor\nVERDICT: BLOCK\n\nUse BLOCK only for a concrete merge-blocking issue.`;
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

export async function invokeAgent(agent, { cwd, prompt, model, approval, logFile, resultFile, taskId }) {
  if (!commandExists(agent)) return { code: 127, error: `${agent} command not found`, stdout: '', stderr: '' };

  if (agent === 'codex') {
    const args = ['--ask-for-approval', 'never', 'exec', '--sandbox', 'workspace-write', '-C', cwd, '--output-last-message', resultFile];
    if (model) args.push('--model', model);
    args.push('-');
    return runProcess('codex', args, {
      cwd,
      input: prompt,
      logFile,
      label: taskId,
      env: { AGENT_HARNESS_TASK_ID: taskId },
    });
  }

  if (agent === 'agy') {
    const args = ['--print-timeout', '15m'];
    if (model) args.push('--model', model);
    if (approval === 'yolo') args.push('--dangerously-skip-permissions');
    args.push('--prompt', prompt);
    const result = await runProcess('agy', args, {
      cwd,
      logFile,
      label: taskId,
      env: { AGENT_HARNESS_TASK_ID: taskId },
      displayCommand: `agy --print-timeout 15m${model ? ` --model ${shellQuote(model)}` : ''}${approval === 'yolo' ? ' --dangerously-skip-permissions' : ''} --prompt '[task packet omitted]'`,
    });
    writeFileSync(resultFile, result.stdout || '', 'utf8');
    return result;
  }

  const mode = approval === 'yolo' ? 'yolo' : 'auto_edit';
  const args = ['--approval-mode', mode, '--output-format', 'text'];
  if (model) args.push('--model', model);
  args.push('--prompt', prompt);
  const result = await runProcess('gemini', args, {
    cwd,
    logFile,
    label: taskId,
    env: { AGENT_HARNESS_TASK_ID: taskId },
    displayCommand: `gemini --approval-mode ${mode}${model ? ` --model ${shellQuote(model)}` : ''} --output-format text --prompt '[task packet omitted]'`,
  });
  writeFileSync(resultFile, result.stdout || '', 'utf8');
  return result;
}

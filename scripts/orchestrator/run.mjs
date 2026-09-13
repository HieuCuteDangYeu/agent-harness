import { existsSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { mkdtemp } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { commandExists, die, git, loadPlan, parseArgs, sanitize, shellQuote, validatePlan } from './core.mjs';
import { integrateTask, runReview, runTask } from './executor.mjs';

function writeStatus(stateRoot, value) {
  writeFileSync(path.join(stateRoot, 'status.json'), `${JSON.stringify(value, null, 2)}\n`, 'utf8');
}

export async function run(argv) {
  const options = parseArgs(argv);
  const plan = loadPlan(path.resolve(options.planPath));
  const maxParallel = validatePlan(plan, options.maxParallel);
  let repoRoot;
  try { repoRoot = git(['rev-parse', '--show-toplevel'], { cwd: process.cwd() }).stdout; }
  catch { die('orchestrate must be run inside a Git repository'); }
  if (git(['-C', repoRoot, 'status', '--porcelain']).stdout && !options.allowDirty) {
    die('caller worktree is dirty; commit/stash first or pass --allow-dirty (dirty changes are excluded)');
  }

  const baseRef = plan.base || 'HEAD';
  let baseSha;
  try { baseSha = git(['-C', repoRoot, 'rev-parse', `${baseRef}^{commit}`]).stdout; }
  catch (error) { die(`cannot resolve plan base ${baseRef}: ${error.message}`); }

  console.log(`PLAN    ${plan.name || 'unnamed'}`);
  console.log(`GOAL    ${plan.goal}`);
  console.log(`BASE    ${baseRef} (${baseSha.slice(0, 12)})`);
  console.log(`PARALLEL ${maxParallel}`);
  for (const task of plan.tasks) console.log(`TASK    ${task.id} -> ${task.agent} deps=[${task.dependsOn.join(', ')}]`);
  if (plan.review) console.log(`REVIEW  ${plan.review.agent}`);
  if (options.dryRun) {
    console.log('DRY-RUN plan is valid; no branches, worktrees, or agents were started.');
    return;
  }

  const agents = new Set(plan.tasks.map((task) => task.agent));
  if (plan.review) agents.add(plan.review.agent);
  for (const agent of agents) if (!commandExists(agent)) die(`${agent} command is required by this plan but was not found on PATH`);

  const commonDir = git(['-C', repoRoot, 'rev-parse', '--git-common-dir']).stdout;
  const commonGitDir = path.resolve(repoRoot, commonDir);
  const stamp = new Date().toISOString().replace(/[-:TZ.]/g, '').slice(0, 14);
  const runId = `${sanitize(plan.name || 'run')}-${stamp}-${Math.random().toString(36).slice(2, 6)}`;
  const stateRoot = path.join(commonGitDir, 'agent-harness', 'runs', runId);
  mkdirSync(stateRoot, { recursive: true });
  writeFileSync(path.join(stateRoot, 'plan.json'), `${JSON.stringify(plan, null, 2)}\n`, 'utf8');

  const worktreeRoot = await mkdtemp(path.join(os.tmpdir(), `agent-harness-${sanitize(path.basename(repoRoot))}-${runId}-`));
  const integrationDir = path.join(worktreeRoot, 'integration');
  const integrationBranch = `agent/orchestrate-${runId}`;
  git(['-C', repoRoot, 'worktree', 'add', '-b', integrationBranch, integrationDir, baseSha]);

  const states = new Map(plan.tasks.map((task) => [task.id, { id: task.id, status: 'pending' }]));
  const running = new Map();
  const snapshot = () => ({ runId, plan: plan.name || null, goal: plan.goal, baseRef, baseSha, integrationBranch, stateRoot, tasks: [...states.values()] });
  writeStatus(stateRoot, snapshot());

  try {
    while (true) {
      let changed = false;
      for (const task of plan.tasks) {
        if (states.get(task.id).status !== 'pending') continue;
        const depStates = task.dependsOn.map((dep) => states.get(dep).status);
        if (depStates.some((status) => status === 'failed' || status === 'blocked')) {
          states.set(task.id, { id: task.id, status: 'blocked', reason: 'dependency failed' });
          changed = true;
        }
      }
      const ready = plan.tasks.filter((task) => states.get(task.id).status === 'pending' && task.dependsOn.every((dep) => states.get(dep).status === 'success'));
      while (running.size < maxParallel && ready.length) {
        const task = ready.shift();
        const taskBase = git(['-C', integrationDir, 'rev-parse', 'HEAD']).stdout;
        states.set(task.id, { id: task.id, status: 'running', agent: task.agent, baseSha: taskBase });
        running.set(task.id, runTask({ plan, task, baseSha: taskBase, repoRoot, worktreeRoot, stateRoot, runId, keepWorktrees: options.keepWorktrees }).then((outcome) => ({ taskId: task.id, outcome })));
        changed = true;
      }
      if (changed) writeStatus(stateRoot, snapshot());
      if (running.size === 0) {
        for (const state of [...states.values()].filter((item) => item.status === 'pending')) states.set(state.id, { ...state, status: 'blocked', reason: 'dependency graph could not make progress' });
        break;
      }
      const completed = await Promise.race([...running.values()]);
      running.delete(completed.taskId);
      const integrated = integrateTask(completed.outcome, integrationDir);
      states.set(completed.taskId, integrated);
      console.log(`${integrated.status === 'success' ? 'DONE' : 'FAIL'}    ${completed.taskId}${integrated.phase ? ` phase=${integrated.phase}` : ''}`);
      writeStatus(stateRoot, snapshot());
    }

    const taskFailed = [...states.values()].some((state) => state.status !== 'success');
    let review = { status: 'skipped', verdict: 'UNKNOWN' };
    if (!taskFailed) {
      review = await runReview(plan, integrationDir, stateRoot, baseRef);
      if (plan.review) console.log(`REVIEW  ${review.status} verdict=${review.verdict}`);
    }
    const finalHead = git(['-C', integrationDir, 'rev-parse', 'HEAD']).stdout;
    const reviewPassed = !plan.review || (review.status === 'success' && review.verdict === 'PASS');
    const success = !taskFailed && reviewPassed;
    const summary = { ...snapshot(), status: success ? 'success' : 'failed', finalHead, review, completedAt: new Date().toISOString() };
    writeFileSync(path.join(stateRoot, 'summary.json'), `${JSON.stringify(summary, null, 2)}\n`, 'utf8');
    writeStatus(stateRoot, summary);
    console.log(`\nRESULT  ${summary.status}`);
    console.log(`BRANCH  ${integrationBranch}`);
    console.log(`STATE   ${stateRoot}`);
    console.log(`DIFF    git diff ${shellQuote(baseRef)}...${shellQuote(integrationBranch)}`);
    console.log(`LOG     git log --oneline ${shellQuote(baseRef)}..${shellQuote(integrationBranch)}`);
    console.log(`PUSH    git push -u origin ${shellQuote(integrationBranch)}`);
    if (!success) process.exitCode = 1;
  } finally {
    if (!options.keepWorktrees && existsSync(integrationDir)) git(['-C', repoRoot, 'worktree', 'remove', '--force', integrationDir], { allowFailure: true });
    if (!options.keepWorktrees) {
      rmSync(worktreeRoot, { recursive: true, force: true });
      git(['-C', repoRoot, 'worktree', 'prune'], { allowFailure: true });
    } else console.log(`KEEP    worktrees ${worktreeRoot}`);
  }
}

import { spawnSync } from 'node:child_process';
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { git, invokeAgent, reviewPrompt, runProcess, sanitize, taskPrompt } from './core.mjs';

async function verify(commands, cwd, logFile, taskId) {
  for (const command of commands) {
    const result = await runProcess('bash', ['-lc', command], { cwd, logFile, label: `${taskId}:verify` });
    if (result.code !== 0) return { ok: false, command, code: result.code };
  }
  return { ok: true };
}

function failureDiff(worktree, outputPath) {
  try {
    git(['-C', worktree, 'add', '-N', '.'], { allowFailure: true });
    const result = spawnSync('git', ['-C', worktree, 'diff', '--binary'], { encoding: 'utf8' });
    writeFileSync(outputPath, result.stdout || '', 'utf8');
    git(['-C', worktree, 'reset'], { allowFailure: true });
  } catch { /* best effort */ }
}

function autoCommit(worktree, taskId) {
  if (git(['-C', worktree, 'status', '--porcelain']).stdout) {
    git(['-C', worktree, 'add', '-A']);
    git(['-C', worktree, '-c', 'user.name=agent-harness', '-c', 'user.email=agent-harness@local', 'commit', '-m', `agent(${taskId}): automated task`]);
  }
  return git(['-C', worktree, 'rev-parse', 'HEAD']).stdout;
}

export async function runTask({ plan, task, baseSha, repoRoot, worktreeRoot, stateRoot, runId, keepWorktrees }) {
  const branch = `agent/task-${runId}-${sanitize(task.id)}`;
  const worktree = path.join(worktreeRoot, `task-${sanitize(task.id)}`);
  const logFile = path.join(stateRoot, `${task.id}.log`);
  const resultFile = path.join(stateRoot, `${task.id}.last-message.txt`);
  const diffFile = path.join(stateRoot, `${task.id}.failure.diff`);
  console.log(`START   ${task.id} -> ${task.agent}`);
  git(['-C', repoRoot, 'worktree', 'add', '-b', branch, worktree, baseSha]);
  try {
    const agent = await invokeAgent(task.agent, { cwd: worktree, prompt: taskPrompt(plan, task), model: task.model, approval: task.approval, logFile, resultFile, taskId: task.id });
    if (agent.code !== 0) {
      failureDiff(worktree, diffFile);
      return { id: task.id, status: 'failed', phase: 'agent', code: agent.code, branch, logFile, diffFile };
    }
    const checked = await verify(task.verify, worktree, logFile, task.id);
    if (!checked.ok) {
      failureDiff(worktree, diffFile);
      return { id: task.id, status: 'failed', phase: 'verification', code: checked.code, command: checked.command, branch, logFile, diffFile };
    }
    const headSha = autoCommit(worktree, task.id);
    if (git(['-C', worktree, 'merge-base', '--is-ancestor', baseSha, headSha], { allowFailure: true }).status !== 0) {
      return { id: task.id, status: 'failed', phase: 'git-history', branch, logFile, error: 'task rewrote history outside its assigned base' };
    }
    return { id: task.id, status: 'ready', branch, baseSha, headSha, logFile, resultFile };
  } finally {
    if (!keepWorktrees && existsSync(worktree)) git(['-C', repoRoot, 'worktree', 'remove', '--force', worktree], { allowFailure: true });
    else if (keepWorktrees) console.log(`KEEP    ${task.id} worktree ${worktree}`);
  }
}

export function integrateTask(outcome, integrationDir) {
  if (outcome.status !== 'ready') return outcome;
  const count = Number(git(['-C', integrationDir, 'rev-list', '--count', `${outcome.baseSha}..${outcome.headSha}`]).stdout || '0');
  if (count === 0) return { ...outcome, status: 'success', noChanges: true };
  const merged = spawnSync('git', ['-C', integrationDir, '-c', 'user.name=agent-harness', '-c', 'user.email=agent-harness@local', 'merge', '--no-ff', '--no-edit', outcome.headSha], { encoding: 'utf8' });
  if (merged.status !== 0) {
    git(['-C', integrationDir, 'merge', '--abort'], { allowFailure: true });
    return { ...outcome, status: 'failed', phase: 'integration', error: (merged.stderr || merged.stdout || 'merge conflict').trim() };
  }
  return { ...outcome, status: 'success', integratedSha: git(['-C', integrationDir, 'rev-parse', 'HEAD']).stdout };
}

export async function runReview(plan, integrationDir, stateRoot, baseRef) {
  if (!plan.review) return { status: 'skipped', verdict: 'UNKNOWN' };
  const logFile = path.join(stateRoot, 'review.log');
  const resultFile = path.join(stateRoot, 'review.last-message.txt');
  const beforeHead = git(['-C', integrationDir, 'rev-parse', 'HEAD']).stdout;
  const beforeStatus = git(['-C', integrationDir, 'status', '--porcelain']).stdout;
  const result = await invokeAgent(plan.review.agent, { cwd: integrationDir, prompt: reviewPrompt(plan, baseRef), model: plan.review.model, approval: plan.review.approval, logFile, resultFile, taskId: 'review' });
  const afterHead = git(['-C', integrationDir, 'rev-parse', 'HEAD']).stdout;
  const afterStatus = git(['-C', integrationDir, 'status', '--porcelain']).stdout;
  let mutationReverted = false;
  if (afterHead !== beforeHead || afterStatus !== beforeStatus) {
    mutationReverted = true;
    const diff = spawnSync('git', ['-C', integrationDir, 'diff', '--binary', beforeHead], { encoding: 'utf8' });
    writeFileSync(path.join(stateRoot, 'review-mutation.diff'), diff.stdout || '', 'utf8');
    git(['-C', integrationDir, 'reset', '--hard', beforeHead], { allowFailure: true });
    git(['-C', integrationDir, 'clean', '-fd'], { allowFailure: true });
  }
  const text = existsSync(resultFile) ? readFileSync(resultFile, 'utf8') : (result.stdout || '');
  const verdicts = [...text.matchAll(/VERDICT:\s*(PASS|BLOCK)\b/gi)];
  const verdict = verdicts.length ? verdicts.at(-1)[1].toUpperCase() : 'UNKNOWN';
  return { status: result.code !== 0 ? 'failed' : verdict === 'BLOCK' ? 'blocked' : 'success', code: result.code, verdict, mutationReverted, logFile, resultFile };
}

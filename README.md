# agent-harness

Reusable, framework-agnostic engineering harness for orchestrating ChatGPT Web, Codex, Antigravity/Gemini, repository Agent Skills, GitHub Issues/PRs, Ponytail, and deterministic CI.

## Philosophy

- ChatGPT performs expensive research, architecture, decomposition, and final review once.
- GitHub Issues are compact execution contracts rather than research dumps.
- Codex and Antigravity read repository context directly and implement isolated tasks.
- `AGENTS.md` carries universal behavior.
- `.agents/skills/` carries specialized knowledge with progressive disclosure.
- `skill-discovery` finds maintained external skills when specialist capability already exists.
- `repo-skill-bootstrap` generates only repository-specific knowledge that should not come from a generic external skill.
- Ponytail handles implementation minimalism/YAGNI separately.
- CI verifies deterministic properties.

## Install

Clone once:

```bash
mkdir -p ~/.local/share ~/.local/bin
git clone git@github.com:HieuCuteDangYeu/agent-harness.git ~/.local/share/agent-harness
ln -sf ~/.local/share/agent-harness/bin/agent-harness ~/.local/bin/agent-harness
```

Ensure `~/.local/bin` is on `PATH`.

## Bootstrap any existing repository

```bash
cd /path/to/project
agent-harness init .
agent-harness doctor .
```

The installer is intentionally non-destructive: existing files are kept instead of overwritten.

## Two skill-discovery layers

After bootstrap, first discover useful maintained external skills:

```text
Use skill-discovery to inspect this project's stack and the current task.
Recommend only external skills that materially improve execution.
Do not install anything yet.
For each recommendation show source, compatibility, install scope, context cost,
and supply-chain/security notes.
```

For example, a frontend/mobile UI task may benefit from a maintained specialist UI/UX skill instead of generating a local generic UI skill. The discovery skill must verify the current upstream source and compatibility rather than relying on a hard-coded example.

Then discover project-specific knowledge that should become local skills:

```text
Use repo-skill-bootstrap to analyze this repository.
Do not create skills yet.
Return a proposed skill inventory with name, trigger, repository evidence,
invariants, and why it belongs in a skill instead of AGENTS.md.
Do not propose generic technology skills.
```

After review:

```text
Generate the approved project-specific skills under .agents/skills/ using the
host's built-in skill creator when available. Keep them concise, project-specific,
and validated.
```

The intended split is:

```text
skill-discovery      -> reusable external expertise
repo-skill-bootstrap -> repository-specific invariants and workflows
skill-maintenance    -> keep repository-specific skills current over time
```

## Daily execution workflow

1. ChatGPT investigates the repository and external evidence.
2. Use `skill-discovery` when the task would benefit from specialist external capability.
3. ChatGPT creates/updates a GitHub Issue task packet.
4. Create an isolated worktree for the chosen agent.
5. Codex or Antigravity implements from the issue + repository instructions.
6. CI runs deterministic checks.
7. A second model may review only where useful.
8. ChatGPT performs final requirement/architecture review.
9. After major architectural PRs, run `skill-maintenance`.

## Worktree helper

```bash
./scripts/agents/create-worktree.sh codex 142
./scripts/agents/create-worktree.sh antigravity 143
```

The helper auto-detects the remote default branch, falling back to `main`.

## Executor prompt

```text
Implement GitHub issue #142.

Read AGENTS.md and activate applicable repository skills.
Use Ponytail full when available.
Treat the issue acceptance criteria as the contract.
Inspect analogous implementations before writing code.
Run the specified verification.
Review the final diff before completion.
```

## Optional shared agent memory

A memory database can reduce repeated exploration across Codex, Antigravity, and orchestration sessions, but it is useful only when retrieval is selective. Do not inject the whole memory store into every prompt.

Keep authoritative durable knowledge in Git, Issues, `AGENTS.md`, and skills. A shared memory service should hold derived cross-session knowledge such as prior decisions, resolved failure patterns, task outcomes, and compact architecture observations. Retrieve only a small task-relevant subset and treat source-linked repository facts as higher authority than remembered summaries.

A future memory layer should expose search/write operations through a small agent tool or MCP service and use namespaces per repository/project. Start without it; add it when repeated exploration across many sessions becomes a measurable source of token usage.

## What should not become a skill

Do not generate skills for generic TypeScript, NestJS, React, Redis, PostgreSQL, Docker, or other technology knowledge the model already knows. Generate skills for repository-specific invariants such as event delivery semantics, auth rules, ownership boundaries, processing workflows, or deployment procedures.

## Development

Run the smoke test:

```bash
./scripts/test-harness.sh
```

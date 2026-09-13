# agent-harness

Reusable, framework-agnostic engineering harness for orchestrating ChatGPT Web, Codex, Antigravity/Gemini, repository Agent Skills, GitHub Issues/PRs, Ponytail, and deterministic CI.

## Philosophy

- ChatGPT performs expensive research, architecture, decomposition, and final review once.
- GitHub Issues are compact execution contracts rather than research dumps.
- Codex and Antigravity read repository context directly and implement isolated tasks.
- `AGENTS.md` carries universal behavior.
- `.agents/skills/` carries project-specific knowledge with progressive disclosure.
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

## Generated project layer

After bootstrap, ask Codex or Antigravity:

```text
Use repo-skill-bootstrap to analyze this repository.
Do not create skills yet.
Return a proposed skill inventory with name, trigger, repository evidence,
invariants, and why it belongs in a skill instead of AGENTS.md.
Do not propose generic technology skills.
```

After review:

```text
Generate the approved skills under .agents/skills/ using the host's built-in
skill creator when available. Keep them concise, project-specific, and validated.
```

## Daily execution workflow

1. ChatGPT investigates the repository and external evidence.
2. ChatGPT creates/updates a GitHub Issue task packet.
3. Create an isolated worktree for the chosen agent.
4. Codex or Antigravity implements from the issue + repository instructions.
5. CI runs deterministic checks.
6. A second model may review only where useful.
7. ChatGPT performs final requirement/architecture review.
8. After major architectural PRs, run `skill-maintenance`.

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

## What should not become a skill

Do not generate skills for generic TypeScript, NestJS, React, Redis, PostgreSQL, Docker, or other technology knowledge the model already knows. Generate skills for repository-specific invariants such as event delivery semantics, auth rules, ownership boundaries, processing workflows, or deployment procedures.

## Development

Run the smoke test:

```bash
./scripts/test-harness.sh
```

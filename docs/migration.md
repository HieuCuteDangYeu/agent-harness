# Managed template migration

`agent-harness` manages a small set of repository Markdown contracts:

- `AGENTS.md`
- `.agents/skills/repository-orchestrator/SKILL.md`
- `.agents/skills/repo-skill-bootstrap/SKILL.md`
- `.agents/skills/skill-discovery/SKILL.md`
- `.agents/skills/skill-maintenance/SKILL.md`
- `.agents/skills/shared-memory/SKILL.md`

Upgrades must treat them as one managed set.

## Safety rule

A managed file may be replaced automatically only when the harness can prove it is still untouched generated content.

The proof path is:

1. exact match with the current template -> keep it;
2. exact match with a template from the previously installed harness snapshot -> migrate it;
3. exact match with a known historical generated blob in `templates/managed-template-hashes.tsv` -> migrate it;
4. otherwise preserve it as project-owned/modified content.

This keeps project customizations safe while still repairing stale generated files left behind by older partial migration logic.

## Why both snapshot and historical hashes exist

The previous-template snapshot handles normal future upgrades without requiring another version-specific hash list. The historical hash catalog exists only to recover projects that were already skipped by older migration code before this mechanism was introduced.

Do not add heuristic overwrites based only on headings, frontmatter names, or marker text for the managed template set. Exact content identity is the safety boundary.

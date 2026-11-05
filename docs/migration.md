# Migrating from generic skill wrappers

Earlier releases generated `AGENTS.md` **and five generic skill shims**
(`repository-orchestrator`, `repo-skill-bootstrap`, `skill-discovery`,
`skill-maintenance`, `shared-memory`). Those shims duplicated Orca
skills, third-party plugins, and the project policy itself.

The current harness generates **`AGENTS.md` plus one focused
`project-learning` skill** from `templates/`. It retires redundant old
shims only when content identity proves they were untouched harness
output. Customized files and project-authored skills remain untouched.

## Exact-content safety rule

1. If the project AGENTS.md is identical to the current template, keep it.
2. If it equals the previous installed template snapshot, migrate it.
3. If it equals an exact historical generated Git blob SHA recorded in
   `templates/managed-template-hashes.tsv`, migrate it.
4. Otherwise keep the project-owned/customized file. Symlinks are never
   followed or replaced.
5. For each obsolete generic shim, delete only when its exact Git blob
   matches a known historical generated hash or the previous harness
   snapshot. Otherwise keep the file and print a review note.

**Never** delete or replace a file just because it contains a heading,
frontmatter name, or legacy marker string. Old versions did this in a
few compatibility paths; those heuristic overwrites have been removed.

The update bootstrap snapshots the previously installed template
directory before checking out the newer harness. This supports safe
future migration without requiring an endless hash registry. The
historical catalog remains for older installations that skipped updates.

Orca owns its generic skill installation and updates. The on-demand
`project-learning` template is different: it specifies how **this
boilerplate** combines verified project knowledge, memory, and skill
promotion; it does not duplicate Orca's orchestration CLI.
Ponytail and agentmemory are installed from their official sources.

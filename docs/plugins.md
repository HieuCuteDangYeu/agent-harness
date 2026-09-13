# Plugins and connectors

`agent-harness` can work alongside ChatGPT plugins/connectors, but it does not install or require them.

Use plugins when they provide authoritative context or an action the orchestrator needs before it creates the local execution plan.

## Where plugins fit

```text
project request
     │
     ▼
ChatGPT orchestrator
     │
     ├── GitHub / Drive / Figma / Neon / other connected plugins
     ├── repository + Git history
     ├── agentmemory
     └── external research when necessary
              │
              ▼
       compact task graph
              │
              ▼
agent-harness orchestrate
     ├── Codex executor
     └── Gemini executor
```

Plugins belong primarily to the **orchestration/context layer**. A spawned Codex or Gemini CLI process does not automatically inherit the ChatGPT plugin's authentication or tools.

The orchestrator should therefore pass only the task-relevant facts, IDs, paths, constraints, and acceptance criteria into executor prompts instead of copying entire plugin responses.

## Useful plugin roles

| Plugin | Best use in the harness |
|---|---|
| GitHub | repository state, issues, PRs, reviews, CI, commits, merge evidence |
| Google Drive | requirements, specifications, meeting notes, reports, shared project documents |
| Figma | design inspection, components, layout constraints, design-to-code context |
| Neon | PostgreSQL projects/branches, schema/runtime inspection, database operations when explicitly needed |
| OpenAI Platform | API-key/project setup for code that uses the OpenAI API; not required for ChatGPT Web models or keyless agentmemory |
| Files | project uploads and prior files available in ChatGPT |

Available plugins can change by account and environment. Treat this table as examples, not a hard dependency list.

## Selection rules

Use the narrowest authoritative source for the task:

```text
current code/tests
    > repository/GitHub task requirements
    > connected source documents/design/database state
    > repository skills
    > agentmemory
    > general web research
```

Examples:

- An implementation request tied to GitHub issue `#142` → read the issue and current repository first.
- A UI task tied to a Figma design → inspect the relevant Figma screen/component, then inspect the repository design system.
- A backend task based on a product specification in Drive → retrieve only that specification and extract concrete requirements.
- A database incident in Neon → inspect the relevant project/branch/log/schema only when the task actually requires live database evidence.

Do not query every connected plugin for every task.

## Security boundaries

- Never put passwords, API keys, access tokens, or raw secrets into orchestration plans or agentmemory.
- Do not give executors broader plugin-derived data than the task needs.
- Treat live database writes and external-service mutations as higher-risk actions; perform them only when explicitly required and authorized.
- Repository code/tests remain authoritative for what the current implementation actually does.
- Plugin content can become stale; verify time-sensitive requirements/state before implementation.

## GitHub after an orchestration run

The dispatcher intentionally stops at a local integration branch. It does not push or merge remotely.

After reviewing the result, GitHub can be used to:

1. push/create the working branch through the normal user-approved workflow
2. create or inspect the PR
3. inspect GitHub Actions
4. review comments/checks
5. merge only after the user approves the result

This keeps local autonomous implementation separate from remote repository changes.

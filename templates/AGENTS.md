# Engineering Agent Contract

## Instruction priority

Apply instructions in this order:

1. Explicit user/task requirements
2. Repository `AGENTS.md`
3. More specific nested `AGENTS.md` files
4. Relevant Agent Skills
5. Existing repository conventions

Never override a higher-priority instruction with a lower-priority one.

## Before changing code

Before implementation:

1. Understand the requested behavior.
2. Inspect the actual execution path.
3. Locate relevant tests.
4. Search for an analogous existing implementation.
5. Determine the smallest safe change.
6. Identify assumptions that materially affect correctness.

Do not implement solely from the issue description when the repository can answer the question.

## Implementation

Prefer:

existing implementation → existing utility → platform/native functionality → installed dependency → smallest new implementation

Rules:

- Keep changes surgical.
- Do not perform unrelated refactors.
- Preserve existing architecture and conventions.
- Reuse existing abstractions before introducing new ones.
- Do not introduce dependencies without necessity.
- Preserve public interfaces unless the task explicitly changes them.
- Follow applicable repository skills.
- Follow Ponytail simplicity guidance when available.

## Safety and correctness

Simplicity must never remove required:

- authentication
- authorization
- trust-boundary validation
- transaction safety
- concurrency protection
- idempotency guarantees
- data-integrity checks
- error handling
- security controls

## Verification

Run the narrowest meaningful checks first.

Where applicable verify:

1. relevant tests
2. typecheck
3. lint
4. integration tests
5. broader repository tests only when necessary

Never claim a command succeeded unless it was actually executed successfully.

## Scope discipline

Do not fix unrelated problems discovered during the task. Report them separately when materially important.

## Completion

Report:

1. implementation summary
2. files changed
3. verification commands
4. verification results
5. remaining risks or assumptions

Keep completion reports concise.

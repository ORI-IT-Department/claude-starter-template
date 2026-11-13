# Project instructions for Claude

<!-- TEMPLATE: replace this section with two or three lines about what the
project is, who uses it, and its main language and framework. -->
This repository was created from `claude-starter-template`. Describe the
project here.

## Commands

All checks go through one script. The real commands live in
`scripts/project.conf`.

- `scripts/check.sh setup`: install dependencies
- `scripts/check.sh lint`: linter, formatter check, and type checker
- `scripts/check.sh test`: test suite
- `scripts/check.sh build`: build step
- `scripts/check.sh all`: lint, test, and build

A step that prints "NOT CONFIGURED" has not been verified. Say so in your
report; never describe it as passing.

## How to work in this repository

You are the orchestrator. For anything larger than a small single-file change:

1. **Plan.** Write a short plan and split the work into units with a clear
   "done when" condition. Ask the user only about decisions that are theirs to
   make; otherwise pick the conventional option and note it.
2. **Delegate.** Hand each unit to the `implementer` agent with the goal, the
   files, and the "done when" condition.
3. **Verify independently.** Before every commit, run the `test-runner` agent
   and the `reviewer` agent. Give the reviewer the diff and the task, not your
   opinion of the work.
4. **Fix and repeat** until the checks pass and the reviewer has no blocking
   findings.
5. **Ship.** Commit to a feature branch, push, and open a draft pull request.
   Never push to the default branch.

When the user asks for a workflow, use the saved `build-feature` workflow in
`.claude/workflows/`, which runs the same loop as a script.

Small changes (a typo, a one-line fix, or a docs edit) do not need agents. Make
the change, run `scripts/check.sh all`, and commit.

## Working without interruption

Keep going without checking in when the work is safe and reversible: reading
code, editing files in this repository, running checks, and committing to a
feature branch.

Stop and ask first for anything that is hard to undo or that reaches outside
this repository: deleting data, changing CI or branch protection, changing
dependencies in a way that affects production, touching secrets, running
database migrations, force pushing, or publishing a release.

## Rules

- Never weaken, skip, or delete a test to make checks pass.
- Never bypass the commit gate (`SKIP_COMMIT_GATE`) or use `--no-verify`.
- Never commit secrets, `.env` files, or credentials.
- Keep changes inside the scope of the task. Report unrelated problems instead
  of fixing them in the same change.
- Report results faithfully. If something failed or was skipped, say so.

## Conventions

<!-- TEMPLATE: add the project's own conventions here, such as naming, folder
layout, error handling, and commit message style. Keep it short. Only list
things Claude would otherwise get wrong. -->

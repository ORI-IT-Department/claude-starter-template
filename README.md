# claude-starter-template

A starting point for projects built with Claude Code. It sets up an
orchestrator session that delegates to coding agents, has separate agents test
and review the work before each commit, and lets Claude run for long stretches
on safe tasks without stopping to ask.

## What is in here

| File | Purpose |
|---|---|
| `CLAUDE.md` | Instructions every session reads: commands, the orchestration loop, and what needs a person's approval |
| `scripts/project.conf` | The one file to edit per project: your setup, lint, test, and build commands |
| `scripts/check.sh` | Single entry point that runs those commands; used by agents, hooks, and CI |
| `.claude/agents/implementer.md` | Agent that writes code for one unit of work |
| `.claude/agents/test-runner.md` | Agent that runs the checks and reports results; cannot edit files |
| `.claude/agents/reviewer.md` | Agent that reviews the diff independently; cannot edit files |
| `.claude/workflows/build-feature.js` | Saved workflow: plan, implement, verify, and fix, as a script |
| `.claude/settings.json` | Permission rules (fewer prompts for safe commands) and hook registration |
| `.claude/hooks/session-start.sh` | Installs dependencies when a cloud session starts |
| `.claude/hooks/pre-commit-gate.sh` | Blocks `git commit` when the checks fail |
| `.github/workflows/ci.yml` | Runs the same checks on every pull request |
| `.github/pull_request_template.md` | Layout for pull request descriptions |

## Starting a new project

1. On GitHub, mark this repository as a template (Settings, then General, then
   "Template repository"), and choose **Use this template** to create the new
   repository.
2. Make sure the Claude GitHub App has access to the new repository:
   https://claude.ai/connect-github
3. Edit `scripts/project.conf` with your real commands.
4. Add your toolchain step to `.github/workflows/ci.yml`, and turn on
   `CHECK_STRICT` there.
5. Fill in the two `TEMPLATE` sections in `CLAUDE.md`.
6. In GitHub, protect the default branch: require a pull request and require
   the `checks` status to pass before merging.

## Using it in a session

Start a Claude Code session on the repository and describe the task. Claude
follows the loop in `CLAUDE.md`: plan, delegate to `implementer`, verify with
`test-runner` and `reviewer`, then commit and open a draft pull request.

For larger tasks, ask for the workflow by name:

> Use the build-feature workflow to add CSV export to the reports page.

Workflows only run when you ask for one, because they use more tokens than a
single session.

To let Claude run longer without prompts in a cloud session, choose **Auto**
in the permission mode dropdown next to the prompt box. That option appears
only if your organization allows it.

## Safety model

Long unattended runs are safe because of layers that do not depend on Claude
behaving well:

- **Branch protection and CI** on GitHub decide what reaches the default branch.
- **The commit gate hook** is run by the Claude Code harness, not by the model.
- **Deny rules** in `.claude/settings.json` block force pushes, hard resets,
  and reads of `.env` files.
- **Read-only agents**: the test-runner and the reviewer have no edit tools.

## Known limits

- A step left empty in `scripts/project.conf` is skipped with a warning. Until
  you fill it in, that check verifies nothing.
- `.claude/settings.json` is read by cloud sessions only when one repository is
  attached to the session.
- The commit gate runs the full check suite on each commit. If your suite is
  slow, point `TEST_CMD` at a fast subset and leave the full suite to CI.

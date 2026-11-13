#!/bin/bash
# PreToolUse hook for the Bash tool: blocks `git commit` unless the project
# checks pass. Exit code 2 blocks the tool call and shows stderr to Claude,
# which then fixes the failure and tries again.
#
# To bypass for one commit (for example a docs-only change), a person can set
# SKIP_COMMIT_GATE=1 in the environment. Agents are told not to do this.
set -uo pipefail

input="$(cat)"

# Only act on commands that contain a git commit.
if ! printf '%s' "$input" | grep -Eq 'git[^"|;&]* commit([^a-zA-Z-]|$)'; then
  exit 0
fi

if [ "${SKIP_COMMIT_GATE:-0}" = "1" ]; then
  exit 0
fi

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

if ! output="$(scripts/check.sh all 2>&1)"; then
  {
    echo "Commit blocked: project checks failed. Fix the failures, then commit again."
    echo "Do not bypass this gate and do not weaken or delete tests to pass it."
    echo
    printf '%s\n' "$output" | tail -n 60
  } >&2
  exit 2
fi

exit 0

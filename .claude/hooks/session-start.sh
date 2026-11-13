#!/bin/bash
# SessionStart hook: installs dependencies in Claude Code cloud sessions so
# that tests and linters work. Runs SETUP_CMD from scripts/project.conf.
set -euo pipefail

# Only run in cloud sessions. Local machines manage their own dependencies.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "${CLAUDE_PROJECT_DIR:-.}"

SETUP_CMD="" SETUP_INPUTS=""
source scripts/project.conf

if [ -z "$SETUP_CMD" ]; then
  exit 0
fi

# The stamp lives outside the repository, in the container's temp directory,
# so it disappears together with the container's installed packages.
stamp="${TMPDIR:-/tmp}/claude-session-start-$(pwd | sha256sum | cut -c1-16).sha256"

# Rerun setup only if this script, the config, or a setup input has changed
# since setup last succeeded.
if ! sha256sum --check --status "$stamp" 2>/dev/null; then
  rm -f "$stamp"
  scripts/check.sh setup
  # shellcheck disable=SC2086
  sha256sum .claude/hooks/session-start.sh scripts/project.conf $SETUP_INPUTS \
    2>/dev/null > "$stamp" || rm -f "$stamp"
fi

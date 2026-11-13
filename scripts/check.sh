#!/usr/bin/env bash
# Single entry point for project checks. Commands come from scripts/project.conf.
#
# Usage: scripts/check.sh [setup|lint|test|build|all]
#   all (default) runs lint, test, and build, and fails if any of them fail.
#
# Set CHECK_STRICT=1 to treat an unconfigured step as a failure.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

SETUP_CMD="" LINT_CMD="" TEST_CMD="" BUILD_CMD="" SETUP_INPUTS="" skipped=""
# shellcheck source=scripts/project.conf
source scripts/project.conf

run_step() {
  local name="$1" var="$2" cmd="$3"
  if [ -z "$cmd" ]; then
    skipped="$skipped $name"
    echo "[check] $name: NOT CONFIGURED (set $var in scripts/project.conf)" >&2
    [ "${CHECK_STRICT:-0}" = "1" ] && return 1
    return 0
  fi
  echo "[check] $name: $cmd"
  if bash -c "$cmd"; then
    echo "[check] $name: passed"
  else
    local status=$?
    echo "[check] $name: FAILED (exit $status)" >&2
    return "$status"
  fi
}

case "${1:-all}" in
  setup) run_step setup SETUP_CMD "$SETUP_CMD" ;;
  lint)  run_step lint LINT_CMD "$LINT_CMD" ;;
  test)  run_step test TEST_CMD "$TEST_CMD" ;;
  build) run_step build BUILD_CMD "$BUILD_CMD" ;;
  all)
    failed=""
    skipped=""
    run_step lint LINT_CMD "$LINT_CMD" || failed="$failed lint"
    run_step test TEST_CMD "$TEST_CMD" || failed="$failed test"
    run_step build BUILD_CMD "$BUILD_CMD" || failed="$failed build"
    if [ -n "$failed" ]; then
      echo "[check] FAILED steps:$failed" >&2
      exit 1
    fi
    if [ -n "$skipped" ]; then
      echo "[check] no failures, but these steps were NOT VERIFIED:$skipped" >&2
    else
      echo "[check] all steps passed"
    fi
    ;;
  *)
    echo "Usage: scripts/check.sh [setup|lint|test|build|all]" >&2
    exit 2
    ;;
esac

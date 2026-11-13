#!/usr/bin/env bash
# Dependency-free tests for scripts/check.sh.
#
# Each case runs a sandbox copy of check.sh against a throwaway project.conf,
# so the real scripts/project.conf is never read or modified, and the sandbox
# conf never points back at this file (no recursion via `check.sh test`).

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

mkdir -p "$SANDBOX/scripts"
cp "$REPO_ROOT/scripts/check.sh" "$SANDBOX/scripts/check.sh"

failures=0
out=""
status=0

# write_conf SETUP LINT TEST BUILD
write_conf() {
  {
    printf 'SETUP_CMD="%s"\n' "$1"
    printf 'LINT_CMD="%s"\n' "$2"
    printf 'TEST_CMD="%s"\n' "$3"
    printf 'BUILD_CMD="%s"\n' "$4"
  } > "$SANDBOX/scripts/project.conf"
}

# run_check STRICT ARGS...  (sets $out and $status)
run_check() {
  local strict="$1"
  shift
  out="$(CHECK_STRICT="$strict" bash "$SANDBOX/scripts/check.sh" "$@" 2>&1)" && status=0 || status=$?
}

# expect NAME EXPECTED_STATUS SUBSTRING  (SUBSTRING may be empty)
expect() {
  local name="$1" want="$2" needle="$3" ok=1
  if [ "$status" -ne "$want" ]; then
    ok=0
    echo "FAIL: $name (exit $status, expected $want)"
  elif [ -n "$needle" ] && ! printf '%s\n' "$out" | grep -qF -- "$needle"; then
    ok=0
    echo "FAIL: $name (output missing '$needle')"
  fi
  if [ "$ok" -eq 1 ]; then
    echo "PASS: $name"
  else
    printf '%s\n' "$out" | sed 's/^/    | /'
    failures=$((failures + 1))
  fi
}

# expect_nonzero NAME SUBSTRING
expect_nonzero() {
  local name="$1" needle="$2"
  if [ "$status" -eq 0 ]; then
    echo "FAIL: $name (exit 0, expected non-zero)"
    printf '%s\n' "$out" | sed 's/^/    | /'
    failures=$((failures + 1))
  elif [ -n "$needle" ] && ! printf '%s\n' "$out" | grep -qF -- "$needle"; then
    echo "FAIL: $name (output missing '$needle')"
    printf '%s\n' "$out" | sed 's/^/    | /'
    failures=$((failures + 1))
  else
    echo "PASS: $name"
  fi
}

# (a) unknown subcommand
write_conf "" "" "" ""
run_check 0 bogus
expect "unknown subcommand exits 2 with usage" 2 "Usage: scripts/check.sh"

# (b) unconfigured step, non-strict
write_conf "" "" "" ""
run_check 0 test
expect "unconfigured step exits 0 and prints NOT CONFIGURED" 0 "NOT CONFIGURED"

# (c) unconfigured step, strict
write_conf "" "" "" ""
run_check 1 test
expect_nonzero "CHECK_STRICT=1 fails an unconfigured step" "NOT CONFIGURED"

# (d) passing command
write_conf "" "" "true" ""
run_check 0 test
expect "configured passing command passes" 0 "test: passed"

# (e) failing command propagates its exit status
write_conf "" "" "exit 3" ""
run_check 0 test
expect "configured failing command exits 3 and prints FAILED" 3 "FAILED"

# (f) all: one failing step
write_conf "" "" "false" ""
run_check 0 all
expect "all with a failing step exits 1 and lists it" 1 "FAILED steps:"

# (g) all: everything empty
write_conf "" "" "" ""
run_check 0 all
expect "all with nothing configured exits 0 and prints NOT VERIFIED" 0 "NOT VERIFIED"

# (h) all: everything passing
write_conf "" "true" "true" "true"
run_check 0 all
expect "all with every step passing reports all steps passed" 0 "all steps passed"

if [ "$failures" -ne 0 ]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "all cases passed"
exit 0

#!/usr/bin/env bash
# Basic shell script tests for opencode-kit
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FAIL=0
PASS=0

test() {
  local name="$1"
  shift
  if "$@" &>/dev/null; then
    echo "  ✅ $name"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $name"
    FAIL=$((FAIL + 1))
  fi
}

test_exit() {
  local name="$1"
  local expected="$2"
  shift 2
  local actual=0
  "$@" &>/dev/null || actual=$?
  if [ "$actual" -eq "$expected" ]; then
    echo "  ✅ $name (exit=$expected)"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $name (expected exit=$expected, got $actual)"
    FAIL=$((FAIL + 1))
  fi
}

echo ""
echo "[opencode-kit] Shell Script Tests"
echo ""

# ---- Syntax checks ----
echo "--- Syntax ---"
for script in "$ROOT"/src/*.sh "$ROOT"/rules/validation.sh; do
  if [ -f "$script" ]; then
    rel="${script#$ROOT/}"
    test "bash -n $rel" bash -n "$script"
  fi
done

# ---- platform.sh ----
echo ""
echo "--- Platform Detection ---"
# Source platform.sh (no $0 dependency — safe to source directly)
(
  source "$ROOT/src/platform.sh"
  test "OS is detected" [ -n "$OS" ]
  test "ARCH is detected" [ -n "$ARCH" ]
  test "PYTHON_CMD is found" [ -n "$PYTHON_CMD" ]
  test "BASH_VERSION is set" [ -n "$BASH_VERSION" ]
  test "OS is valid" sh -c "case \"$OS\" in macos|linux|other) exit 0;; *) exit 1;; esac"
  test "ARCH is valid" sh -c "case \"$ARCH\" in arm64|amd64|other) exit 0;; *) exit 1;; esac"
)

# ---- global-config.sh ----
echo ""
echo "--- Config Resolution ---"
# global-config.sh uses $(dirname "$0") to set SCRIPT_DIR, so it must be
# sourced from a context where $0 resolves to the script's own path.
# We use bash -c to set $0 = src/global-config.sh for correct resolution.
(
  output=$(bash -c '
    # Set $0 to the script path so that global-config.sh can resolve
    # its own SCRIPT_DIR (uses $(dirname "$0")).
    ROOT="$1"
    source "$ROOT/src/global-config.sh"
    fails=0
    ok()    { echo "__PASS__:$1"; }
    notok() { echo "__FAIL__:$1"; fails=$((fails + 1)); }

    type resolve_config &>/dev/null && ok "resolve_config exported" || notok "resolve_config exported"
    type init_global_config &>/dev/null && ok "init_global_config exported" || notok "init_global_config exported"
    type is_plugin_active &>/dev/null && ok "is_plugin_active exported" || notok "is_plugin_active exported"
    [ -n "$GLOBAL_CONFIG_DIR" ] && ok "GLOBAL_CONFIG_DIR set" || notok "GLOBAL_CONFIG_DIR set"

    resolved="$(resolve_config contract.json)"
    [ -n "$resolved" ] && ok "resolve_config finds contract.json ($resolved)" || notok "resolve_config finds contract.json"

    resolved="$(resolve_config rules.json)"
    [ -n "$resolved" ] && ok "resolve_config finds rules.json ($resolved)" || notok "resolve_config finds rules.json"

    exit $fails
  ' "$ROOT/src/global-config.sh" "$ROOT" 2>&1)
  exit_code=$?
  # Map tagged lines to test results
  while IFS= read -r line; do
    case "$line" in
      __PASS__:*) test "${line#__PASS__:}" true ;;
      __FAIL__:*) test "${line#__FAIL__:}" false ;;
      *) echo "  $line" ;;
    esac
  done <<< "$output"
  [ "$exit_code" -eq 0 ] || test "all global-config tests" false
)

# ---- init.sh ----
echo ""
echo "--- Init ---"
TMPDIR=$(mktemp -d /tmp/opencode-test-XXXXX)
(
  cd "$TMPDIR"
  "$ROOT/src/init.sh" --force 2>/dev/null || true
)
test "init creates .opencode/" [ -d "$TMPDIR/.opencode" ]
test "init creates .opencode/orchestration/" [ -d "$TMPDIR/.opencode/orchestration" ]
test "init creates .opencode/rules/" [ -d "$TMPDIR/.opencode/rules" ]
test "init creates .opencode/agents/" [ -d "$TMPDIR/.opencode/agents" ]
test "init creates contract.json" [ -f "$TMPDIR/.opencode/orchestration/contract.json" ]
test "init creates rules.json" [ -f "$TMPDIR/.opencode/rules/rules.json" ]
test "init creates superpowers-contract.json" [ -f "$TMPDIR/.opencode/templates/superpowers-contract.json" ]
test "init creates verify.sh" [ -f "$TMPDIR/.opencode/src/verify.sh" ]
test "init creates platform.sh" [ -f "$TMPDIR/.opencode/src/platform.sh" ]
test "init creates agent files" [ -f "$TMPDIR/.opencode/agents/orchestrator.md" ]
test "init creates rules validation.sh" [ -f "$TMPDIR/.opencode/rules/validation.sh" ]
test "init makes verify.sh executable" [ -x "$TMPDIR/.opencode/src/verify.sh" ]
test "init makes platform.sh executable" [ -x "$TMPDIR/.opencode/src/platform.sh" ]

# verify.sh should pass on a fresh init
test "verify.sh passes on init" "$TMPDIR/.opencode/src/verify.sh"

rm -rf "$TMPDIR"

# ---- verify.sh ----
echo ""
echo "--- Verify (no project) ---"
# Should fail when no .opencode/ exists
TMPDIR2=$(mktemp -d /tmp/opencode-test-XXXXX)
(
  cd "$TMPDIR2"
  test_exit "verify.sh fails without .opencode/" 1 "$ROOT/src/verify.sh"
  test "git init works" git init
  "$ROOT/src/init.sh" --force 2>/dev/null
  test "verify.sh passes after init" "$ROOT/src/verify.sh"
)
rm -rf "$TMPDIR2"

# ---- doctor.sh ----
echo ""
echo "--- Doctor ---"
TMPDIR3=$(mktemp -d /tmp/opencode-test-XXXXX)
(
  cd "$TMPDIR3"
  # Should succeed (no issues) on a clean init
  "$ROOT/src/init.sh" --force 2>/dev/null
  test_exit "doctor.sh passes on clean init" 0 "$ROOT/src/doctor.sh"
)
rm -rf "$TMPDIR3"

# ---- status.sh ----
echo ""
echo "--- Status ---"
TMPDIR4=$(mktemp -d /tmp/opencode-test-XXXXX)
(
  cd "$TMPDIR4"
  "$ROOT/src/init.sh" --force 2>/dev/null
  test "status.sh runs" "$ROOT/src/status.sh"
)
rm -rf "$TMPDIR4"

# ---- new-skill.sh ----
echo ""
echo "--- New Skill ---"
TMPDIR5=$(mktemp -d /tmp/opencode-test-XXXXX)
(
  cd "$TMPDIR5"
  "$ROOT/src/init.sh" --force 2>/dev/null
  test "new-skill.sh creates skill dir" "$ROOT/src/new-skill.sh" my-custom-skill "Test skill"
  test "skill SKILL.md exists" [ -f ".opencode/skills/my-custom-skill/SKILL.md" ]
  test "skill SKILL.md has description" grep -q "Test skill" .opencode/skills/my-custom-skill/SKILL.md
  # Running again with same name should fail
  test_exit "new-skill.sh fails on duplicate" 1 "$ROOT/src/new-skill.sh" my-custom-skill
  # Running without name should fail
  test_exit "new-skill.sh fails without args" 1 "$ROOT/src/new-skill.sh"
)
rm -rf "$TMPDIR5"

# ---- preflight.sh / postflight.sh ----
echo ""
echo "--- Preflight / Postflight ---"
TMPDIR6=$(mktemp -d /tmp/opencode-test-XXXXX)
(
  cd "$TMPDIR6"
  git init 2>/dev/null
  "$ROOT/src/init.sh" --force 2>/dev/null
  # Preflight should run without error in a valid project
  test "preflight.sh runs" "$ROOT/src/preflight.sh" 2>/dev/null || true
  # Postflight should run without error in a valid project
  test "postflight.sh runs" "$ROOT/src/postflight.sh" 2>/dev/null || true
)
rm -rf "$TMPDIR6"

# ---- adr.sh ----
echo ""
echo "--- ADR ---"
TMPDIR7=$(mktemp -d /tmp/opencode-test-XXXXX)
(
  cd "$TMPDIR7"
  # ADR without init should fail
  test_exit "adr.sh fails without init" 1 "$ROOT/src/adr.sh" "Test Decision"
  "$ROOT/src/init.sh" --force 2>/dev/null
  # ADR with title should create a markdown file
  # Pipe empty input since adr.sh is interactive
  echo "" | "$ROOT/src/adr.sh" "Use Hexagonal Architecture" 2>/dev/null || true
  test "adr.sh creates ADR file" ls .opencode/adr-*.md &>/dev/null || [ -f .opencode/architecture/decisions/adr-*.md ] || true
)
rm -rf "$TMPDIR7"

# ---- diff.sh ----
echo ""
echo "--- Diff ---"
TMPDIR8=$(mktemp -d /tmp/opencode-test-XXXXX)
(
  cd "$TMPDIR8"
  git init 2>/dev/null
  git config user.email "test@test.com"
  git config user.name "Test"
  "$ROOT/src/init.sh" --force 2>/dev/null
  git add -A 2>/dev/null
  git commit -m "initial" 2>/dev/null
  # diff should run (no contract diff = empty output, but no crash)
  test "diff.sh runs on single branch" "$ROOT/src/diff.sh" 2>/dev/null || true
)
rm -rf "$TMPDIR8"

# ---- Summary ----
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1

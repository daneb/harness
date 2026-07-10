# shellcheck shell=bash
# tests/helpers.sh — plain-shell test kit, no dependencies. Sourced by run.sh.

HROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export HARNESS_HOME="$HROOT"
export PATH="$HROOT/bin:$PATH"
# shellcheck disable=SC2034  # used by the sourced test-*.sh files
G="$HROOT/gates"
# shellcheck disable=SC2034  # used by the sourced test-*.sh files
A="$HROOT/adapters"
PASS=0; FAIL=0; T=""; OUT=""; RC=0; TESTTMP=""

t() { T="$1"; TESTTMP="$(mktemp -d "${TMPDIR:-/tmp}/harness-test.XXXXXX")"; }

# fresh git repo with a Makefile toolchain (pass "notool" to omit), cd into it
mkrepo() {
  cd "$TESTTMP" || exit 1
  rm -rf repo; mkdir repo; cd repo || exit 1
  git init -q -b main .
  git config user.email t@t; git config user.name t; git config commit.gpgsign false
  if [ "${1:-tool}" != "notool" ]; then
    printf 'lint:\n\t@echo lint ok\ntest:\n\t@echo tests ok\n' > Makefile
  fi
  mkdir -p src
  # shellcheck disable=SC2016  # $1 is meant literally in the generated script
  printf '#!/bin/sh\ngreet() { echo "hello, $1"; }\n' > src/app.sh
  git add -A; git commit -qm init
}

# <name> — approved spec + valid single-task plan scoped to src/app.sh
mktask() {
  mkdir -p ".tasks/$1/report"
  cat > ".tasks/$1/SPEC.md" <<EOF
# SPEC — $1

Status: approved

## Problem
p

## Proposal
q

## Acceptance Criteria
- [ ] works
EOF
  cat > ".tasks/$1/PLAN.md" <<EOF
# PLAN — $1

## Task: $1
Scope:
- src/app.sh
Symbols:
- greet
Steps:
- do it
EOF
}

# in-place string replace (portable; no sed -i)
edit() {
  python3 -c "import sys; p,o,n=sys.argv[1:4]; s=open(p).read(); open(p,'w').write(s.replace(o,n))" "$1" "$2" "$3"
}

run() { OUT="$("$@" 2>&1)"; RC=$?; }
ok()  { run "$@"; if [ "$RC" -eq 0 ]; then pass; else fail "expected exit 0 (got $RC): $*"; fi; }
no()  { run "$@"; if [ "$RC" -ne 0 ]; then pass; else fail "expected failure: $*"; fi; }
rc()  { local want="$1"; shift; run "$@"; if [ "$RC" -eq "$want" ]; then pass; else fail "expected exit $want (got $RC): $*"; fi; }
has() { if printf '%s' "$OUT" | grep -q -e "$1"; then pass; else fail "output missing '$1'"; fi; }
hasfile()  { if [ -e "$1" ]; then pass; else fail "missing file: $1"; fi; }
filehas()  { if grep -q -e "$2" "$1" 2>/dev/null; then pass; else fail "$1 missing '$2'"; fi; }
pass() { PASS=$((PASS+1)); }
fail() {
  FAIL=$((FAIL+1)); echo "FAIL: $T — $1"
  if [ -n "${OUT:-}" ]; then printf '%s\n' "$OUT" | sed 's/^/    /' | head -12; fi
}
report() { echo; echo "harness tests: $((PASS+FAIL)) assertions, $FAIL failed"; [ "$FAIL" -eq 0 ]; }

# stub kiro-cli in $TESTTMP/bin: verifies invocation shape + inlined role,
# answers per role, decorates output with ANSI to exercise stripping
mkstub_kiro() {
  mkdir -p "$TESTTMP/bin"
  cat > "$TESTTMP/bin/kiro-cli" <<'EOF'
#!/bin/bash
[ "$1" = "chat" ] && [ "$2" = "--no-interactive" ] && [ "$3" = "--agent" ] || { echo "BADARGS: $*" >&2; exit 1; }
p="$5"
case "$p" in *"YOUR ROLE AND OUTPUT CONTRACT"*"# Role:"*) : ;; *) echo "ROLE-NOT-INLINED" >&2; exit 1 ;; esac
case "$p" in
  *"Review the diff at"*) printf '# Review — x\n\n## Blocking\n- none\n\n\033[32mVERDICT: pass\033[0m\n' ;;
  *"Critique the draft"*)             printf '# Spec critique — x\n\nASSESSMENT: ready\n' ;;
  *"Partition the spec"*)
    printf '=== SPEC: split-one ===\n# SPEC — split-one\n\nStatus: approved\n\n## Problem\np1\n\n## Acceptance Criteria\n- [ ] a\n'
    printf '=== SPEC: split-two ===\n# SPEC — split-two\n\nStatus: draft\n\n## Problem\np2\n\n## Acceptance Criteria\n- [ ] b\n' ;;
  *)                                  printf '\033[1m# PLAN — x\033[0m\n\n## Task: x\nScope:\n- src/app.sh\n' ;;
esac
EOF
  chmod +x "$TESTTMP/bin/kiro-cli"
}

# stub claude in $TESTTMP/bin emitting a fixed stream-json transcript
mkstub_claude() {
  mkdir -p "$TESTTMP/bin"
  cat > "$TESTTMP/bin/claude" <<'EOF'
#!/bin/bash
cat <<'J'
{"type":"system","subtype":"init","model":"claude-stub"}
{"type":"result","subtype":"success","is_error":false,"num_turns":1,"duration_ms":7,"total_cost_usd":0.01,"usage":{"input_tokens":2,"output_tokens":3},"result":"# PLAN — stub\n\n## Task: x\nScope:\n- src/app.sh\n"}
J
EOF
  chmod +x "$TESTTMP/bin/claude"
}

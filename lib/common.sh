#!/usr/bin/env bash
# Shared helpers, sourced by bin/harness, gates/*, adapters/*.
# Requires bash 3.2+ (macOS default). No mapfile, no assoc arrays.

HARNESS_HOME="${HARNESS_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

die()  { echo "harness: $*" >&2; exit 1; }
info() { echo "==> $*"; }

repo_root() {
  git -C "${1:-.}" rev-parse --show-toplevel 2>/dev/null \
    || die "not inside a git repository (the harness requires git)"
}

# cfg <repo_root> <key> <default> — flat-key lookup in .harness.toml
cfg() {
  local f="$1/.harness.toml" v=""
  if [ -f "$f" ]; then
    v=$(sed -nE "s/^[[:space:]]*$2[[:space:]]*=[[:space:]]*\"?([^\"#]*)\"?.*/\1/p" "$f" \
        | head -1 | sed 's/[[:space:]]*$//')
  fi
  echo "${v:-$3}"
}

# render <file.md> — show markdown readably: glow → bat → plain cat.
render() {
  if command -v glow >/dev/null 2>&1; then glow -w "${COLUMNS:-100}" "$1"
  elif command -v bat >/dev/null 2>&1; then bat --style=plain --language=md --paging=never "$1"
  else cat "$1"; fi
}

# discover_checks <repo_root> — the repo's own quality bar, one command per line.
# Never supplies a default toolchain; empty output means G2 must refuse.
discover_checks() {
  local d="$1" t
  if [ -f "$d/package.json" ]; then
    # Root scripts, declared npm/yarn workspaces, and one-level-deep sub-packages
    # (monorepos often keep the real toolchain below the root).
    python3 - "$d" <<'PY'
import glob, json, os, sys
root = sys.argv[1]
def scripts(p):
    try:
        return json.load(open(os.path.join(p, "package.json"))).get("scripts", {})
    except Exception:
        return {}
wanted = ("lint", "typecheck", "test")
for s in wanted:
    if s in scripts(root):
        print("npm run %s" % s)
ws = json.load(open(os.path.join(root, "package.json"))).get("workspaces", [])
if isinstance(ws, dict):
    ws = ws.get("packages", [])
members = set()
for pat in list(ws) + ["*"]:
    for m in glob.glob(os.path.join(root, pat)):
        rel = os.path.relpath(m, root)
        if rel.startswith("node_modules") or rel == ".":
            continue
        if os.path.isfile(os.path.join(m, "package.json")):
            members.add(rel)
for m in sorted(members):
    for s in wanted:
        if s in scripts(os.path.join(root, m)):
            print("npm --prefix %s run %s" % (m, s))
PY
  fi
  if [ -f "$d/Makefile" ]; then
    for t in lint typecheck test; do
      if grep -qE "^$t:" "$d/Makefile"; then echo "make $t"; fi
    done
  fi
  if [ -f "$d/justfile" ] || [ -f "$d/Justfile" ]; then
    for t in lint typecheck test; do
      if just --justfile "$d"/[jJ]ustfile --show "$t" >/dev/null 2>&1; then echo "just $t"; fi
    done
  fi
  if [ -f "$d/Cargo.toml" ]; then
    if cargo clippy --version >/dev/null 2>&1; then echo "cargo clippy --quiet -- -D warnings"; fi
    echo "cargo test --quiet"
  fi
  if [ -f "$d/go.mod" ]; then
    echo "go vet ./..."
    echo "go test ./..."
  fi
  if [ -f "$d/pyproject.toml" ]; then
    if grep -q '\[tool\.ruff' "$d/pyproject.toml"; then echo "ruff check ."; fi
    if grep -q '\[tool\.mypy' "$d/pyproject.toml"; then echo "mypy ."; fi
    if grep -q '\[tool\.pytest' "$d/pyproject.toml"; then echo "pytest -q"; fi
  fi
  if [ -f "$d/ruff.toml" ]; then echo "ruff check ."; fi
  if [ -f "$d/pytest.ini" ]; then echo "pytest -q"; fi
}

# lockfile_manifest <path> — the manifest a lockfile derives from (same dir),
# or nothing if the path is not a lockfile. A lockfile is in scope iff its
# manifest is: derived output rides with its source, and never counts toward
# the diff budget (machine-generated, reviewed by provenance not by line).
lockfile_manifest() {
  local d b m=""
  d=$(dirname "$1"); b=$(basename "$1")
  case "$b" in
    package-lock.json|npm-shrinkwrap.json|yarn.lock|pnpm-lock.yaml|bun.lockb) m="package.json" ;;
    Cargo.lock)   m="Cargo.toml" ;;
    go.sum)       m="go.mod" ;;
    poetry.lock|uv.lock) m="pyproject.toml" ;;
    Pipfile.lock) m="Pipfile" ;;
    Gemfile.lock) m="Gemfile" ;;
    composer.lock) m="composer.json" ;;
  esac
  [ -n "$m" ] || return 0
  case "$d" in .) echo "$m" ;; *) echo "$d/$m" ;; esac
}

# is_test_file <repo-relative path> — heuristic shared by the G2 diff budget
# (test lines are exempt: a size cap must never discourage tests) and any
# future test-efficacy checks.
is_test_file() {
  case "$1" in
    */__tests__/*|__tests__/*|*/tests/*|tests/*|*/test/*|test/*|*/spec/*|spec/*) return 0 ;;
    *.test.*|*.spec.*|*_test.*|*_spec.*) return 0 ;;
    test_*|*/test_*|conftest.py|*/conftest.py) return 0 ;;
  esac
  return 1
}

# plan_tasks <plan_file> — list task slugs, one per line
plan_tasks() { sed -nE 's/^## Task:[[:space:]]*(.*)/\1/p' "$1"; }

# plan_list <plan_file> <scope|sym> [task] — bullet entries of a section.
# Prints the full entry after "- " (so callers can see the "(new)" marker).
# With no task argument, prints entries across all tasks.
plan_list() {
  awk -v S="$2" -v want="${3:-}" '
    /^## Task:/  { t=$0; sub(/^## Task:[ \t]*/,"",t); sect="" }
    /^Scope:/    { sect="scope"; next }
    /^Symbols:/  { sect="sym";   next }
    /^[A-Za-z#]/ { sect="" }
    sect==S && /^- / && (want=="" || t==want) { sub(/^- +/,""); print }
  ' "$1"
}

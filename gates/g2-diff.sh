#!/usr/bin/env bash
# G2 — Diff gate: repo's own lint/typecheck/tests pass; diff-size budget
# respected; no files touched outside declared scope.
# REFUSES to run (exit 2) if the repo has no lint/type/test config of its own.
# Usage: g2-diff.sh <task_dir> <repo_root>
set -euo pipefail
source "$(cd "$(dirname "$0")/.." && pwd)/lib/common.sh"

td="${1:?usage: g2-diff.sh <task_dir> <repo_root>}"
root="${2:?usage: g2-diff.sh <task_dir> <repo_root>}"
plan="$td/PLAN.md"

[ -f "$plan" ] || die "G2: $plan not found"
git -C "$root" rev-parse HEAD >/dev/null 2>&1 || die "G2: repo has no commits to diff against"

# --- Discover the repo's own quality bar. Never supply a default toolchain. ---
discover_checks() {
  local d="$1" s t
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
        print("npm run %s --silent" % s)
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
            print("npm --prefix %s run %s --silent" % (m, s))
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

checks=$(discover_checks "$root" | awk '!seen[$0]++')
if [ -z "$checks" ]; then
  echo "G2: REFUSED — this repo declares no lint/typecheck/test configuration." >&2
  echo "G2: The harness never supplies a default toolchain. Add one, then retry." >&2
  exit 2
fi

# --- Scope check: changed files must be within the plan's declared scope. ---
scope=$(plan_list "$plan" scope | awk '{print $1}')
changed=$(git -C "$root" status --porcelain | awk '{print $NF}' \
          | grep -vE '^(\.tasks/|decisions/|\.harness\.toml$)' || true)
fail=0
for f in $changed; do
  echo "$scope" | grep -qxF "$f" \
    || { echo "G2: file changed outside declared scope: $f" >&2; fail=1; }
done
[ "$fail" -eq 0 ] || die "G2: scope violation"

# --- Diff budget: added+removed lines (tracked) + lines of new untracked files. ---
budget=$(cfg "$root" diff_budget_lines 400)
lines=$(git -C "$root" diff HEAD --numstat | awk '{n+=$1+$2} END{print n+0}')
while IFS= read -r f; do
  [ -n "$f" ] || continue
  case "$f" in .tasks/*|decisions/*) continue;; esac
  [ -f "$root/$f" ] && lines=$((lines + $(wc -l < "$root/$f")))
done <<EOF
$(git -C "$root" ls-files --others --exclude-standard)
EOF
[ "$lines" -le "$budget" ] || die "G2: diff is $lines lines, budget is $budget (diff_budget_lines)"
echo "G2: diff $lines/$budget lines, all changes in scope"

# --- Run the repo's own checks. ---
while IFS= read -r c; do
  info "G2 check: $c"
  (cd "$root" && eval "$c") || die "G2: check failed: $c"
done <<EOF
$checks
EOF

echo "G2: all repo checks passed"

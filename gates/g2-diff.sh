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

# --- The repo's own quality bar (lib/common.sh). No default toolchain, ever. ---
checks=$(discover_checks "$root" | awk '!seen[$0]++')
if [ -z "$checks" ]; then
  echo "G2: REFUSED — this repo declares no lint/typecheck/test configuration." >&2
  echo "G2: The harness never supplies a default toolchain. Add one, then retry." >&2
  exit 2
fi

# --- Scope check: changed files must be within the plan's declared scope. ---
scope=$(plan_list "$plan" scope | awk '{print $1}')
changed=$(git -C "$root" status --porcelain -uall | awk '{print $NF}' \
          | grep -vE '^(\.tasks/|decisions/|\.harness\.toml$)' || true)
# in_scope <file>: exact entry match, or under a directory entry (trailing /)
in_scope() {
  echo "$scope" | grep -qxF "$1" && return 0
  local e
  while IFS= read -r e; do
    case "$e" in
      */) case "$1" in "$e"*) return 0 ;; esac ;;
    esac
  done <<SCOPE
$scope
SCOPE
  return 1
}

fail=0
for f in $changed; do
  if in_scope "$f"; then continue; fi
  m=$(lockfile_manifest "$f")
  if [ -n "$m" ]; then
    if in_scope "$m"; then continue; fi
    echo "G2: lockfile $f changed but its manifest $m is not in scope (dependency drift?)" >&2
  else
    echo "G2: file changed outside declared scope: $f" >&2
  fi
  fail=1
done
[ "$fail" -eq 0 ] || die "G2: scope violation"

# --- Diff budget: added+removed product lines (tracked) + new untracked files.
# --- Test files are exempt — the cap must never reward skipping tests.
# Config reads from the metadata root ($td/../..): with worktrees, $root is the
# task's sandbox and its checked-out .harness.toml may lag the real one.
mroot="$(cd "$td/../.." && pwd)"
budget=$(cfg "$mroot" diff_budget_lines 400)
# Budget counts ADDED product lines: tests are exempt (never discourage
# tests) and deletions are free (deletion is a first-class operation).
lines=0; tlines=0; dlines=0
while read -r add del f; do
  [ -n "$f" ] || continue
  case "$add" in ''|*[!0-9]*) continue ;; esac   # binary files report "-"
  case "$f" in .tasks/*|decisions/*|.harness.toml) continue ;; esac  # harness metadata (tracked after merges)
  [ -n "$(lockfile_manifest "$f")" ] && continue  # machine-generated, never counted
  dlines=$((dlines + del))
  if is_test_file "$f"; then tlines=$((tlines + add)); else lines=$((lines + add)); fi
done <<EOF
$(git -C "$root" diff HEAD --numstat)
EOF
while IFS= read -r f; do
  [ -n "$f" ] || continue
  case "$f" in .tasks/*|decisions/*|.harness.toml) continue;; esac
  [ -f "$root/$f" ] || continue
  [ -n "$(lockfile_manifest "$f")" ] && continue
  if is_test_file "$f"; then tlines=$((tlines + $(wc -l < "$root/$f")))
  else lines=$((lines + $(wc -l < "$root/$f"))); fi
done <<EOF
$(git -C "$root" ls-files --others --exclude-standard)
EOF
[ "$lines" -le "$budget" ] || die "G2: diff adds $lines product lines (budget $budget; $tlines test lines exempt, $dlines deletions free).
G2: One feature? Raise diff_budget_lines in .harness.toml, committed with a reason. Several? Split. (PHILOSOPHY.md, field guide)"
echo "G2: diff $lines/$budget added product lines ($tlines test lines exempt, $dlines deleted free), all changes in scope"

# --- Run the repo's own checks. ---
info "G2: commands below are discovered from this repo's own manifests — to change one, change the script it names (specs instruct agents; manifests instruct gates)"
while IFS= read -r c; do
  info "G2 check: $c"
  (cd "$root" && eval "$c") || die "G2: check failed: $c"
done <<EOF
$checks
EOF

echo "G2: all repo checks passed"

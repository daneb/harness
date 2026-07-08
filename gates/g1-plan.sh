#!/usr/bin/env bash
# G1 — Plan gate: plan references only real files/symbols (cheap hallucination
# detection); task file scopes are disjoint when fan-out is declared.
# Usage: g1-plan.sh <task_dir> <repo_root>
set -euo pipefail
source "$(cd "$(dirname "$0")/.." && pwd)/lib/common.sh"

td="${1:?usage: g1-plan.sh <task_dir> <repo_root>}"
root="${2:?usage: g1-plan.sh <task_dir> <repo_root>}"
plan="$td/PLAN.md"

[ -f "$plan" ] || die "G1: $plan not found — run 'harness plan <task>'"

tasks=$(plan_tasks "$plan")
[ -n "$tasks" ] || {
  echo "G1: PLAN.md contains no '## Task:' entries — the planner ignored the output format." >&2
  echo "G1: inspect $plan and report/planner-transcript.*, then re-run 'harness plan'." >&2
  exit 1
}

fail=0

for t in $tasks; do
  scope=$(plan_list "$plan" scope "$t")
  if [ -z "$scope" ]; then
    echo "G1: task '$t' declares no Scope" >&2; fail=1; continue
  fi
  # Every scoped file must exist unless marked "(new)".
  while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    path="${entry%% *}"
    case "$entry" in *"(new)"*) continue;; esac
    [ -e "$root/$path" ] \
      || { echo "G1: task '$t' references missing file: $path (mark ' (new)' if intended)" >&2; fail=1; }
  done <<EOF
$scope
EOF
  # Every named symbol must exist somewhere in the repo.
  while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    sym="${entry%% *}"
    if command -v rg >/dev/null 2>&1; then
      rg -q -w -F "$sym" "$root" -g '!.tasks' -g '!decisions' \
        || { echo "G1: task '$t' references unknown symbol: $sym (hallucination?)" >&2; fail=1; }
    else
      grep -rqw --exclude-dir=.git --exclude-dir=.tasks --exclude-dir=decisions -F "$sym" "$root" \
        || { echo "G1: task '$t' references unknown symbol: $sym (hallucination?)" >&2; fail=1; }
    fi
  done <<EOF
$(plan_list "$plan" sym "$t")
EOF
done

# Disjoint scopes required when fan-out (>1 task) is declared.
ntasks=$(echo "$tasks" | wc -l | tr -d ' ')
if [ "$ntasks" -gt 1 ]; then
  overlap=$(plan_list "$plan" scope | awk '{print $1}' | sort | uniq -d)
  [ -z "$overlap" ] || { echo "G1: task scopes overlap on: $overlap" >&2; fail=1; }
fi

[ "$fail" -eq 0 ] || die "G1: plan validation failed"
echo "G1: plan valid — $ntasks task(s), scopes verified"

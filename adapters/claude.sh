#!/usr/bin/env bash
# Claude Code adapter. Contract: <role> <task_dir> <workdir> → artifacts + report.
#   planner     → writes <task_dir>/PLAN.md
#   implementer → edits workdir, log in report/implement.log
#   reviewer    → writes report/review.md (fresh context, read-only, cross-model)
# Every run captures the full agent event stream to report/<role>-transcript.jsonl
# and appends usage/cost to report/events.jsonl. The harness emits; it never serves.
set -euo pipefail
source "$(cd "$(dirname "$0")/.." && pwd)/lib/common.sh"

role="${1:?usage: claude.sh <planner|implementer|reviewer> <task_dir> <workdir>}"
td="${2:?}"; wd="${3:?}"
name=$(basename "$td")
rel=".tasks/$name"
sys="$HARNESS_HOME/roles/$role.md"
[ -f "$sys" ] || die "unknown role: $role"
command -v claude >/dev/null 2>&1 || die "claude CLI not found on PATH"
mkdir -p "$td/report"

readonly_tools="Read,Grep,Glob,LS,Bash(rg:*),Bash(ls:*),Bash(git diff:*),Bash(git status:*),Bash(git log:*)"

# Runs claude with $prompt/$sys, saves the stream transcript, emits the usage
# event, prints the agent's final result text on stdout.
run_role() {
  local tsf="$td/report/$role-transcript.jsonl"
  (cd "$wd" && claude -p "$prompt" \
      --append-system-prompt "$(cat "$sys")" \
      --output-format stream-json --verbose "$@") > "$tsf"
  python3 "$HARNESS_HOME/lib/stream_result.py" "$tsf" "$td/report/events.jsonl" "$role"
}

case "$role" in
  spec-splitter)
    info "spec splitter (fresh context, read-only) → report/spec-split.md"
    prompt="Partition the spec at $rel/SPEC.md into independently shippable \
specs per your role's rules — reorganize only, never add intent. Print ONLY \
the marker-delimited spec blocks; your stdout is saved verbatim."
    run_role --allowedTools "$readonly_tools" > "$td/report/spec-split.md"
    ;;
  spec-critic)
    info "spec critic (fresh context, read-only) → report/spec-review.md"
    prompt="Critique the draft specification at $rel/SPEC.md before human \
approval. Survey this repository to check the spec against reality. Print ONLY \
the critique in your role's format, ending with an ASSESSMENT line — your \
stdout is saved verbatim as $rel/report/spec-review.md."
    run_role --allowedTools "$readonly_tools" > "$td/report/spec-review.md"
    info "wrote $td/report/spec-review.md"
    ;;
  planner)
    info "planner (fresh context, read-only) → PLAN.md"
    prompt="Read $rel/SPEC.md, survey this repository, and produce the PLAN.md \
content for this task. Print ONLY the plan markdown in the exact format your \
role defines — your stdout is saved verbatim as $rel/PLAN.md."
    run_role --allowedTools "$readonly_tools" > "$td/PLAN.md"
    info "wrote $td/PLAN.md"
    ;;
  implementer)
    info "implementer (write access, scoped by G2) → working tree"
    prompt="Implement the task defined in $rel/SPEC.md according to $rel/PLAN.md. \
Touch only files within your task's declared Scope. Run this repo's own \
lint/tests before finishing. Leave all changes uncommitted."
    run_role --permission-mode acceptEdits | tee "$td/report/implement.log"
    ;;
  reviewer)
    model="${HARNESS_REVIEWER_MODEL:-}"   # set by bin/harness from reviewer_model config
    margs=()
    [ -n "$model" ] && margs=(--model "$model")
    info "reviewer (fresh context, read-only${model:+, model=$model}) → report/review.md"
    prompt="Review the current uncommitted diff ('git diff HEAD' plus untracked \
files) against $rel/SPEC.md and $rel/PLAN.md. You did not write this code. \
Print ONLY the review in your role's format, ending with a VERDICT line — your \
stdout is saved verbatim as $rel/report/review.md."
    run_role --allowedTools "$readonly_tools" ${margs[@]+"${margs[@]}"} > "$td/report/review.md"
    info "wrote $td/report/review.md"
    ;;
  *)
    die "unknown role: $role"
    ;;
esac

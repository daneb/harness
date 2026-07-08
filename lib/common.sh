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

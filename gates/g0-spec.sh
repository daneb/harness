#!/usr/bin/env bash
# G0 — Spec gate: SPEC.md exists, has acceptance criteria, human-approved.
# Usage: g0-spec.sh <task_dir>
set -euo pipefail
source "$(cd "$(dirname "$0")/.." && pwd)/lib/common.sh"

td="${1:?usage: g0-spec.sh <task_dir>}"
spec="$td/SPEC.md"

[ -f "$spec" ] || die "G0: $spec not found — run 'harness spec <task>' and write the spec"

grep -qiE '^##[[:space:]]+acceptance criteria' "$spec" \
  || die "G0: SPEC.md has no '## Acceptance Criteria' section"

awk '
  f && /^- /                                  { ok=1 }
  /^## /                                      { f=0 }
  tolower($0) ~ /^##[ \t]+acceptance criteria/ { f=1 }
  END { exit !ok }
' "$spec" || die "G0: '## Acceptance Criteria' section contains no criteria bullets"

grep -qiE '^status:[[:space:]]*approved' "$spec" \
  || die "G0: spec is not approved — a human must set 'Status: approved' in SPEC.md"

echo "G0: spec approved, acceptance criteria present"

#!/usr/bin/env bash
# G3 — Human gate: you read the diff. Never automated.
# Usage: g3-human.sh <task_dir> <repo_root>
set -euo pipefail
source "$(cd "$(dirname "$0")/.." && pwd)/lib/common.sh"

td="${1:?usage: g3-human.sh <task_dir> <repo_root>}"
root="${2:?usage: g3-human.sh <task_dir> <repo_root>}"

[ -t 0 ] || die "G3: requires an interactive terminal — human review is never automated"

echo "── Changed files ──────────────────────────────────────"
git -C "$root" status --short
echo "── Diff (q to quit pager) ─────────────────────────────"
git -C "$root" diff HEAD --color=always | ${PAGER:-less -R}

untracked=$(git -C "$root" ls-files --others --exclude-standard | grep -vE '^(\.tasks/|decisions/)' || true)
if [ -n "$untracked" ]; then
  echo "── New (untracked) files — review each ────────────────"
  for f in $untracked; do
    echo "· $f"; sed 's/^/    /' "$root/$f"
  done
fi

# Human decision is the ground-truth label for reviewer calibration.
emit_decision() {
  printf '{"ts":"%s","phase":"human-decision","decision":"%s"}\n' \
    "$(date +%Y-%m-%dT%H:%M:%S)" "$1" >> "$td/report/events.jsonl"
}

printf "Approve this diff for merge? [y/N] "
read -r ans
mkdir -p "$td/report"
case "$ans" in
  y|Y|yes)
    emit_decision approve
    echo "$(date '+%Y-%m-%d %H:%M:%S') by ${USER:-unknown}" > "$td/report/g3-approved"
    echo "G3: approved by human" ;;
  *)
    emit_decision reject
    die "G3: not approved" ;;
esac

#!/usr/bin/env bash
# G2.5 — Review gate: a fresh-context reviewer produced a structured verdict.
# blocking always fails; concerns fails when review_blocking = true.
# Usage: g25-review.sh <task_dir> <repo_root>
set -euo pipefail
source "$(cd "$(dirname "$0")/.." && pwd)/lib/common.sh"

td="${1:?usage: g25-review.sh <task_dir> <repo_root>}"
root="${2:?usage: g25-review.sh <task_dir> <repo_root>}"
rv="$td/report/review.md"

[ -f "$rv" ] || die "G2.5: $rv not found — run 'harness review <task>'"

# Tolerate markdown decoration (**VERDICT: pass**, ## Verdict: pass) but
# still require the keyword — a review without a verdict is not a review.
verdict=$(tr '[:upper:]' '[:lower:]' < "$rv" \
          | sed -nE 's/^[^a-z]*verdict[[:space:]]*:[[:space:]]*([a-z]+).*/\1/p' \
          | tail -1 || true)
[ -n "$verdict" ] || {
  echo "G2.5: review.md has no 'VERDICT:' line — the reviewer ignored the output contract." >&2
  echo "G2.5: inspect $rv (and report/reviewer-transcript.*), then re-run 'harness review'." >&2
  exit 1
}

# Calibration label, paired with the G3 human decision by `harness calibrate`.
printf '{"ts":"%s","phase":"review-verdict","verdict":"%s"}\n' \
  "$(date +%Y-%m-%dT%H:%M:%S)" "$verdict" >> "$td/report/events.jsonl"

case "$verdict" in
  pass)
    echo "G2.5: reviewer verdict — pass" ;;
  concerns)
    if [ "$(cfg "$root" review_blocking true)" = "true" ]; then
      die "G2.5: reviewer verdict — concerns (blocking; review_blocking=true). See $rv"
    fi
    echo "G2.5: reviewer verdict — concerns (non-blocking). Read $rv before G3." ;;
  blocking)
    die "G2.5: reviewer verdict — blocking. See $rv" ;;
  *)
    die "G2.5: unrecognized verdict '$verdict' (expected pass|concerns|blocking)" ;;
esac

# shellcheck shell=bash
# CLI behaviors: sequencing enforcement, scaffolding, calibration, merge writeback.

t "init scaffolds layout with CLAUDE.md symlink"
mkrepo
ok harness init
hasfile .tasks; hasfile decisions; hasfile AGENTS.md; hasfile .harness.toml
if [ -L CLAUDE.md ]; then pass; else fail "CLAUDE.md is not a symlink"; fi

t "spec scaffolds and refuses overwrite"
mkrepo
ok harness spec foo
filehas .tasks/foo/SPEC.md "SPEC — foo"
no harness spec foo; has "already exists"

t "implement refuses when G1 has not passed"
mkrepo; mktask y
no harness implement y; has "advances only through gates"

t "gate command records pass markers and events"
mkrepo; mktask y
ok harness gate g0 y
hasfile .tasks/y/report/g0.pass
filehas .tasks/y/report/events.jsonl '"phase":"gate:g0","result":"pass"'

t "a failing gate removes the pass marker"
mkrepo; mktask y
ok harness gate g0 y
edit .tasks/y/SPEC.md "Status: approved" "Status: draft"
no harness gate g0 y
if [ -f .tasks/y/report/g0.pass ]; then fail "stale g0.pass survived a failure"; else pass; fi

t "status shows gate progress"
mkrepo; mktask y; ok harness gate g0 y
run harness status y; has "g0"; has "pass"; has "pending"

t "require_adapter fails loud on a bad adapter value"
mkrepo; mktask y
HARNESS_ADAPTER=kiro-cli run harness critique y
if [ "$RC" -ne 0 ]; then pass; else fail "bad adapter accepted"; fi
has "no such adapter"; has "claude kiro"

t "calibrate pairs verdicts with human decisions chronologically"
mkrepo
mkdir -p .tasks/t2/report .tasks/t3/report
cat > .tasks/t2/report/events.jsonl <<'EOF'
{"ts":"2026-07-01T10:00:00","phase":"review-verdict","verdict":"pass"}
{"ts":"2026-07-01T11:00:00","phase":"human-decision","decision":"reject"}
{"ts":"2026-07-02T10:00:00","phase":"review-verdict","verdict":"concerns"}
{"ts":"2026-07-02T11:00:00","phase":"human-decision","decision":"reject"}
{"ts":"2026-07-03T10:00:00","phase":"review-verdict","verdict":"pass"}
{"ts":"2026-07-03T11:00:00","phase":"human-decision","decision":"approve"}
EOF
cat > .tasks/t3/report/events.jsonl <<'EOF'
{"ts":"2026-07-04T10:00:00","phase":"review-verdict","verdict":"concerns"}
{"ts":"2026-07-04T11:00:00","phase":"human-decision","decision":"approve"}
{"ts":"2026-07-05T10:00:00","phase":"review-verdict","verdict":"blocking"}
EOF
run harness calibrate
has "4 labeled pair"; has "TP 1"; has "FN 1"; has "TN 1"; has "FP 1"; has "1 verdict(s) unlabeled"

t "calibrate reports when no labels exist"
mkrepo
no harness calibrate; has "no (verdict, human decision) pairs"

t "merge requires G3 and writes commit + decision record"
mkrepo; mktask y
no harness merge y
touch .tasks/y/report/g3.pass
echo "2026-07-09 by test" > .tasks/y/report/g3-approved
printf '# R\n\nVERDICT: pass\n' > .tasks/y/report/review.md
ok harness merge y
run git log -1 --format=%s; has "task(y)"
run ls decisions; has "y.md"
filehas decisions/*-y.md "VERDICT: pass"

t "split stages drafts, forces Status: draft, preserves the original"
mkrepo; mktask bundled; mkstub_kiro
PATH="$TESTTMP/bin:$PATH" HARNESS_ADAPTER=kiro KIRO_AGENT_DIR="$TESTTMP/kagents" run harness split bundled
if [ "$RC" -eq 0 ]; then pass; else fail "split failed: $OUT"; fi
hasfile .tasks/split-one/SPEC.md; hasfile .tasks/split-two/SPEC.md
filehas .tasks/split-one/SPEC.md "Status: draft"   # stub wrote "approved"; must be forced
filehas .tasks/split-two/SPEC.md "- \[ \] b"
filehas .tasks/bundled/SPEC.md "Status: approved"  # original untouched
no harness gate g0 split-one                        # staged drafts cannot pass G0

t "split refuses to overwrite an existing task"
mkrepo; mktask bundled; mkstub_kiro
mkdir -p .tasks/split-one
PATH="$TESTTMP/bin:$PATH" HARNESS_ADAPTER=kiro KIRO_AGENT_DIR="$TESTTMP/kagents" run harness split bundled
if [ "$RC" -ne 0 ]; then pass; else fail "split overwrote an existing task"; fi
has "already exists"

t "re-critique preserves the prior critique and points the agent at it"
mkrepo; mktask y
echo "old critique" > .tasks/y/report/spec-review.md
mkdir -p "$TESTTMP/bin"
cat > "$TESTTMP/bin/kiro-cli" <<'EOF'
#!/bin/bash
printf '%s' "$5" > "$KCAP"
printf '# Spec critique\n\nASSESSMENT: ready\n'
EOF
chmod +x "$TESTTMP/bin/kiro-cli"
PATH="$TESTTMP/bin:$PATH" HARNESS_ADAPTER=kiro KCAP="$TESTTMP/prompt.txt" KIRO_AGENT_DIR="$TESTTMP/kagents" \
  run harness critique y
if [ "$RC" -eq 0 ]; then pass; else fail "re-critique failed: $OUT"; fi
filehas .tasks/y/report/spec-review.prev.md "old critique"
filehas "$TESTTMP/prompt.txt" "spec-review.prev.md"
filehas .tasks/y/report/spec-review.md "ASSESSMENT: ready"

t "first critique does not claim a prior exists"
mkrepo; mktask y
mkdir -p "$TESTTMP/bin"
cat > "$TESTTMP/bin/kiro-cli" <<'EOF'
#!/bin/bash
printf '%s' "$5" > "$KCAP"
printf '# Spec critique\n\nASSESSMENT: ready\n'
EOF
chmod +x "$TESTTMP/bin/kiro-cli"
PATH="$TESTTMP/bin:$PATH" HARNESS_ADAPTER=kiro KCAP="$TESTTMP/prompt.txt" KIRO_AGENT_DIR="$TESTTMP/kagents" \
  run harness critique y
if grep -q "re-critique" "$TESTTMP/prompt.txt"; then fail "re-critique claim on first run"; else pass; fi

t "stats aggregates cost, agent time, and gate failures"
mkrepo
mkdir -p .tasks/s1/report
cat > .tasks/s1/report/events.jsonl <<'EOF'
{"ts":"2026-07-09T10:00:00","phase":"planner","model":"m","cost_usd":0.25,"duration_ms":60000}
{"ts":"2026-07-09T10:01:00","phase":"gate:g1","result":"pass","duration_s":1}
{"ts":"2026-07-09T10:02:00","phase":"implementer","model":"m","cost_usd":1.75,"duration_ms":120000}
{"ts":"2026-07-09T10:03:00","phase":"gate:g2","result":"fail","duration_s":3}
{"ts":"2026-07-09T10:04:00","phase":"gate:g2","result":"pass","duration_s":3}
EOF
run harness stats
has "s1"; has "2.00"; has "3m00s"; has "g2:1"; has "g2 1/2"

t "stats reports when no events exist"
mkrepo
no harness stats; has "no events"

t "version prints version and commit"
run harness version; has "harness 0.1.0"

t "doctor passes on a healthy kiro setup"
mkrepo; mkstub_kiro
PATH="$TESTTMP/bin:$PATH" HARNESS_ADAPTER=kiro run harness doctor
if [ "$RC" -eq 0 ]; then pass; else fail "doctor failed on healthy setup"; fi
has "quality bar"; has "kiro"

t "doctor fails when the repo has no quality bar"
mkrepo notool; mkstub_kiro
PATH="$TESTTMP/bin:$PATH" HARNESS_ADAPTER=kiro run harness doctor
if [ "$RC" -ne 0 ]; then pass; else fail "doctor passed a bare repo"; fi
has "G2 will refuse"

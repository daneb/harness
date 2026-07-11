# shellcheck shell=bash
# Adapter contract: config generation, role inlining, ANSI stripping, events.

t "kiro planner: role inlined, ANSI stripped, event emitted"
mkrepo; mktask x; mkstub_kiro
ok env PATH="$TESTTMP/bin:$PATH" KIRO_AGENT_DIR="$TESTTMP/kagents" \
  "$A/kiro.sh" planner "$PWD/.tasks/x" "$PWD"
filehas .tasks/x/PLAN.md "## Task: x"
if grep -q "$(printf '\033')" .tasks/x/PLAN.md; then fail "ANSI escapes survived in PLAN.md"; else pass; fi
filehas .tasks/x/report/events.jsonl '"adapter":"kiro"'
hasfile .tasks/x/report/planner-transcript.kiro.txt

t "kiro planner/reviewer agent configs are read-only"
mkrepo; mktask x; mkstub_kiro
ok env PATH="$TESTTMP/bin:$PATH" KIRO_AGENT_DIR="$TESTTMP/kagents" \
  "$A/kiro.sh" planner "$PWD/.tasks/x" "$PWD"
ok python3 -c "
import json,sys
c=json.load(open('$TESTTMP/kagents/harness-planner.json'))
assert c['name'] == 'harness-planner', 'name field is REQUIRED by kiro-cli'
assert 'write' not in c['tools'], c['tools']
assert 'shell' not in c['allowedTools'], 'trusted shell voids allowedCommands'
assert 'allowedCommands' in c['toolsSettings']['shell']
"

t "one run regenerates every role config, all with the required name field"
mkrepo; mktask x; mkstub_kiro
ok env PATH="$TESTTMP/bin:$PATH" KIRO_AGENT_DIR="$TESTTMP/kagents" \
  "$A/kiro.sh" planner "$PWD/.tasks/x" "$PWD"
ok python3 -c "
import json
for r in ['planner','implementer','reviewer','spec-critic','spec-splitter']:
    c = json.load(open('$TESTTMP/kagents/harness-%s.json' % r))
    assert c['name'] == 'harness-' + r, r
"

t "another agent's invalid config does not kill this run"
mkrepo; mktask x
mkdir -p "$TESTTMP/bin"
cat > "$TESTTMP/bin/kiro-cli" <<'EOF'
#!/bin/bash
echo "Error: Json supplied at /home/u/.kiro/agents/harness-spec-critic.json is invalid: missing field name" >&2
printf '# PLAN — x\n\n## Task: x\nScope:\n- src/app.sh\n'
EOF
chmod +x "$TESTTMP/bin/kiro-cli"
ok env PATH="$TESTTMP/bin:$PATH" KIRO_AGENT_DIR="$TESTTMP/kagents" \
  "$A/kiro.sh" planner "$PWD/.tasks/x" "$PWD"

t "kiro adapter refuses output when the agent config fails to load"
mkrepo; mktask x
mkdir -p "$TESTTMP/bin"
cat > "$TESTTMP/bin/kiro-cli" <<'EOF'
#!/bin/bash
echo "Error: no agent with name harness-planner found. Falling back to user specified default" >&2
printf '# PLAN — x\n\n## Task: x\nScope:\n- src/app.sh\n'
EOF
chmod +x "$TESTTMP/bin/kiro-cli"
no env PATH="$TESTTMP/bin:$PATH" KIRO_AGENT_DIR="$TESTTMP/kagents" \
  "$A/kiro.sh" planner "$PWD/.tasks/x" "$PWD"
has "permissions were NOT applied"

t "kiro implementer config allows write, denies commit/push"
mkrepo; mktask x; mkstub_kiro
ok env PATH="$TESTTMP/bin:$PATH" KIRO_AGENT_DIR="$TESTTMP/kagents" \
  "$A/kiro.sh" implementer "$PWD/.tasks/x" "$PWD"
ok python3 -c "
import json
c=json.load(open('$TESTTMP/kagents/harness-implementer.json'))
assert 'write' in c['tools']
assert 'shell' not in c['allowedTools'], 'trusted shell voids deniedCommands'
assert any('git commit' in d for d in c['toolsSettings']['shell']['deniedCommands'])
assert any(d.startswith('npm') for d in c['toolsSettings']['shell']['allowedCommands'])
"

t "kiro reviewer honors cross-model override"
mkrepo; mktask x; mkstub_kiro
ok env PATH="$TESTTMP/bin:$PATH" KIRO_AGENT_DIR="$TESTTMP/kagents" \
  HARNESS_REVIEWER_MODEL=some-model "$A/kiro.sh" reviewer "$PWD/.tasks/x" "$PWD"
filehas "$TESTTMP/kagents/harness-reviewer.json" '"model": "some-model"'
filehas .tasks/x/report/review.md "VERDICT: pass"

t "kiro adapter dies clearly when the binary is missing"
mkrepo; mktask x
no env PATH="/usr/bin:/bin" KIRO_AGENT_DIR="$TESTTMP/kagents" \
  "$A/kiro.sh" planner "$PWD/.tasks/x" "$PWD"
has "not found"

t "claude planner: stream parsed, artifact written, usage event emitted"
mkrepo; mktask x; mkstub_claude
ok env PATH="$TESTTMP/bin:$PATH" "$A/claude.sh" planner "$PWD/.tasks/x" "$PWD"
filehas .tasks/x/PLAN.md "## Task: x"
filehas .tasks/x/report/events.jsonl '"model": "claude-stub"'
filehas .tasks/x/report/events.jsonl '"cost_usd": 0.01'
hasfile .tasks/x/report/planner-transcript.jsonl

t "stream_result.py fails loud on an error result"
mkrepo
cat > ts.jsonl <<'EOF'
{"type":"system","subtype":"init","model":"m"}
{"type":"result","subtype":"success","is_error":true,"result":"Credit balance is too low","usage":{}}
EOF
no python3 "$HROOT/lib/stream_result.py" ts.jsonl ev.jsonl smoke
filehas ev.jsonl '"is_error": true'

t "stream_result.py fails when the transcript has no result"
mkrepo
printf '{"type":"system","subtype":"init","model":"m"}\n' > ts.jsonl
no python3 "$HROOT/lib/stream_result.py" ts.jsonl ev.jsonl smoke; has "no result event"

t "spec-critic runs read-only and saves the critique"
mkrepo; mktask x; mkstub_kiro
ok env PATH="$TESTTMP/bin:$PATH" KIRO_AGENT_DIR="$TESTTMP/kagents" \
  "$A/kiro.sh" spec-critic "$PWD/.tasks/x" "$PWD"
filehas .tasks/x/report/spec-review.md "ASSESSMENT:"
ok python3 -c "
import json
c=json.load(open('$TESTTMP/kagents/harness-spec-critic.json'))
assert 'write' not in c['tools']
"

t "implementer prompt carries G3 feedback and prior review when present"
mkrepo; mktask x
echo "2026-07-09 — retry swallows timeouts" > .tasks/x/report/g3-feedback.md
printf '# R\n\nVERDICT: concerns\n' > .tasks/x/report/review.md
mkdir -p "$TESTTMP/bin"
cat > "$TESTTMP/bin/kiro-cli" <<'EOF'
#!/bin/bash
printf '%s' "$5" > "$KCAP"
echo implemented
EOF
chmod +x "$TESTTMP/bin/kiro-cli"
ok env PATH="$TESTTMP/bin:$PATH" KCAP="$TESTTMP/prompt.txt" KIRO_AGENT_DIR="$TESTTMP/kagents" \
  "$A/kiro.sh" implementer "$PWD/.tasks/x" "$PWD"
filehas "$TESTTMP/prompt.txt" "g3-feedback.md"
filehas "$TESTTMP/prompt.txt" "review.md"

t "implementer prompt omits feedback pointers when none exist"
mkrepo; mktask x
mkdir -p "$TESTTMP/bin"
cat > "$TESTTMP/bin/kiro-cli" <<'EOF'
#!/bin/bash
printf '%s' "$5" > "$KCAP"
echo implemented
EOF
chmod +x "$TESTTMP/bin/kiro-cli"
ok env PATH="$TESTTMP/bin:$PATH" KCAP="$TESTTMP/prompt.txt" KIRO_AGENT_DIR="$TESTTMP/kagents" \
  "$A/kiro.sh" implementer "$PWD/.tasks/x" "$PWD"
if grep -q "g3-feedback" "$TESTTMP/prompt.txt"; then fail "feedback pointer present without feedback"; else pass; fi

t "planner prompt carries DIRECTION.md and decisions/ when they exist"
mkrepo; mktask x
echo "# direction" > DIRECTION.md
mkdir -p decisions && echo "# past task" > decisions/2026-07-01-old.md
mkdir -p "$TESTTMP/bin"
cat > "$TESTTMP/bin/kiro-cli" <<'EOF'
#!/bin/bash
printf '%s' "$5" > "$KCAP"
printf '# PLAN — x\n\n## Task: x\nScope:\n- src/app.sh\n'
EOF
chmod +x "$TESTTMP/bin/kiro-cli"
ok env PATH="$TESTTMP/bin:$PATH" KCAP="$TESTTMP/prompt.txt" KIRO_AGENT_DIR="$TESTTMP/kagents" \
  "$A/kiro.sh" planner "$PWD/.tasks/x" "$PWD"
filehas "$TESTTMP/prompt.txt" "DIRECTION.md"
filehas "$TESTTMP/prompt.txt" "decisions/"

t "planner prompt omits cross-task pointers when neither exists"
mkrepo; mktask x
mkdir -p "$TESTTMP/bin"
cat > "$TESTTMP/bin/kiro-cli" <<'EOF'
#!/bin/bash
printf '%s' "$5" > "$KCAP"
printf '# PLAN — x\n\n## Task: x\nScope:\n- src/app.sh\n'
EOF
chmod +x "$TESTTMP/bin/kiro-cli"
ok env PATH="$TESTTMP/bin:$PATH" KCAP="$TESTTMP/prompt.txt" KIRO_AGENT_DIR="$TESTTMP/kagents" \
  "$A/kiro.sh" planner "$PWD/.tasks/x" "$PWD"
if grep -q "DIRECTION.md" "$TESTTMP/prompt.txt"; then fail "DIRECTION pointer without the file"; else pass; fi

t "plan_list parses scopes, symbols, and (new) markers"
mkrepo; mktask x
edit .tasks/x/PLAN.md "- src/app.sh" "- src/app.sh
- src/other.sh (new)"
run plan_list .tasks/x/PLAN.md scope
has "src/app.sh"; has "src/other.sh (new)"
run plan_list .tasks/x/PLAN.md sym
has "greet"

t "is_test_file heuristic"
ok is_test_file "src/__tests__/x.ts"
ok is_test_file "tests/foo.sh"
ok is_test_file "src/thing.test.ts"
ok is_test_file "pkg/util_test.go"
ok is_test_file "test_main.py"
no is_test_file "src/app.sh"
no is_test_file "contest.py"

# shellcheck shell=bash
# Gate behaviors: every refusal and pass proven during dogfooding, as regressions.

# ---------- G0 ----------
t "G0 refuses a missing spec"
mkrepo; mkdir -p .tasks/x/report
no "$G/g0-spec.sh" "$PWD/.tasks/x"

t "G0 refuses a draft spec"
mkrepo; mktask x; edit .tasks/x/SPEC.md "Status: approved" "Status: draft"
no "$G/g0-spec.sh" "$PWD/.tasks/x"; has "not approved"

t "G0 refuses acceptance criteria without bullets"
mkrepo; mktask x; edit .tasks/x/SPEC.md "- [ ] works" "prose, no bullets"
no "$G/g0-spec.sh" "$PWD/.tasks/x"; has "no criteria"

t "G0 passes an approved spec with criteria"
mkrepo; mktask x
ok "$G/g0-spec.sh" "$PWD/.tasks/x"

# ---------- G1 ----------
t "G1 refuses a plan with no tasks"
mkrepo; mktask x; printf '# PLAN\njust prose\n' > .tasks/x/PLAN.md
no "$G/g1-plan.sh" "$PWD/.tasks/x" "$PWD"; has "no '## Task:'"

t "G1 refuses a scope file that does not exist"
mkrepo; mktask x; edit .tasks/x/PLAN.md "src/app.sh" "src/nope.sh"
no "$G/g1-plan.sh" "$PWD/.tasks/x" "$PWD"; has "missing file"

t "G1 allows declared-new files"
mkrepo; mktask x; edit .tasks/x/PLAN.md "- src/app.sh" "- src/new_thing.sh (new)"
ok "$G/g1-plan.sh" "$PWD/.tasks/x" "$PWD"

t "G1 refuses a hallucinated symbol"
mkrepo; mktask x; edit .tasks/x/PLAN.md "- greet" "- greet
- imaginary_fn"
no "$G/g1-plan.sh" "$PWD/.tasks/x" "$PWD"; has "unknown symbol"

t "G1 refuses overlapping scopes on fan-out"
mkrepo; mktask x
cat >> .tasks/x/PLAN.md <<'EOF'

## Task: second
Scope:
- src/app.sh
EOF
no "$G/g1-plan.sh" "$PWD/.tasks/x" "$PWD"; has "overlap"

t "G1 passes a valid plan"
mkrepo; mktask x
ok "$G/g1-plan.sh" "$PWD/.tasks/x" "$PWD"

# ---------- G2 ----------
t "G2 refuses (exit 2) a repo with no toolchain"
mkrepo notool; mktask x
rc 2 "$G/g2-diff.sh" "$PWD/.tasks/x" "$PWD"; has "REFUSED"

t "G2 refuses an out-of-scope change"
mkrepo; mktask x; echo rogue > rogue.txt
no "$G/g2-diff.sh" "$PWD/.tasks/x" "$PWD"; has "outside declared scope: rogue.txt"

t "G2 sees individual files inside brand-new directories"
mkrepo; mktask x; mkdir -p deep/nested; echo x > deep/nested/f.txt
no "$G/g2-diff.sh" "$PWD/.tasks/x" "$PWD"; has "deep/nested/f.txt"

t "G2 enforces the product-line budget"
mkrepo; mktask x; printf 'diff_budget_lines = 3\n' > .harness.toml
printf 'a\nb\nc\nd\ne\n' >> src/app.sh
no "$G/g2-diff.sh" "$PWD/.tasks/x" "$PWD"; has "product lines"

t "G2 exempts test lines from the budget"
mkrepo; mktask x; printf 'diff_budget_lines = 3\n' > .harness.toml
cat >> .tasks/x/PLAN.md <<'EOF'
EOF
edit .tasks/x/PLAN.md "- src/app.sh" "- src/app.sh
- tests/big.test.sh (new)"
mkdir -p tests; python3 -c "open('tests/big.test.sh','w').write('# t\n'*200)"
ok "$G/g2-diff.sh" "$PWD/.tasks/x" "$PWD"; has "test lines exempt"

t "G2 allows a lockfile when its manifest is in scope, exempt from budget"
mkrepo; mktask x; printf 'diff_budget_lines = 3\n' > .harness.toml
edit .tasks/x/PLAN.md "- src/app.sh" "- src/app.sh
- package.json (new)"
echo '{"name":"r","scripts":{"test":"echo ok"}}' > package.json
python3 -c "open('package-lock.json','w').write('x\n'*200)"
ok "$G/g2-diff.sh" "$PWD/.tasks/x" "$PWD"

t "G2 flags a lockfile changing without its manifest"
mkrepo; mktask x
echo 'lock' > package-lock.json
no "$G/g2-diff.sh" "$PWD/.tasks/x" "$PWD"; has "dependency drift"

t "G2 scope entries tolerate trailing whitespace from hand-edited plans"
mkrepo; mktask x
printf '# PLAN — x\n\n## Task: x\nScope:\n- src/app.sh   \nSymbols:\n- greet\n' > .tasks/x/PLAN.md
echo '# ok' >> src/app.sh
ok "$G/g2-diff.sh" "$PWD/.tasks/x" "$PWD"

t "G2 directory scope covers everything beneath it, including deletions"
mkrepo; mktask x
mkdir -p legacy/deep; echo a > legacy/a.txt; echo b > legacy/deep/b.txt
git add -A; git commit -qm legacy
edit .tasks/x/PLAN.md "- src/app.sh" "- legacy/"
rm -r legacy
no_scope_rogue() { :; }
ok "$G/g2-diff.sh" "$PWD/.tasks/x" "$PWD"
echo rogue > rogue.txt
no "$G/g2-diff.sh" "$PWD/.tasks/x" "$PWD"; has "rogue.txt"

t "G2 budget: mass deletion is free, additions still counted"
mkrepo; mktask x; printf 'diff_budget_lines = 3\n' > .harness.toml
python3 -c "open('src/big.sh','w').write('# x\n'*500)"
git add -A; git commit -qm big
edit .tasks/x/PLAN.md "- src/app.sh" "- src/app.sh
- src/big.sh"
rm src/big.sh
ok "$G/g2-diff.sh" "$PWD/.tasks/x" "$PWD"; has "500 deleted free"
printf 'a\nb\nc\nd\ne\n' >> src/app.sh
no "$G/g2-diff.sh" "$PWD/.tasks/x" "$PWD"; has "adds 5 product lines"

t "G2 discovers monorepo sub-package toolchains"
mkrepo notool; mktask x
echo '{"name":"m","workspaces":["packages/*"]}' > package.json
mkdir -p packages/a angular-like
echo '{"name":"a","scripts":{"test":"echo sub tests ok"}}' > packages/a/package.json
echo '{"name":"al","scripts":{"lint":"echo al lint ok"}}' > angular-like/package.json
git add -A; git commit -qm pkgs
ok "$G/g2-diff.sh" "$PWD/.tasks/x" "$PWD"
has "npm --prefix packages/a run test"; has "npm --prefix angular-like run lint"

t "G2 fails when a repo check fails"
mkrepo; mktask x; printf 'lint:\n\t@echo lint ok\ntest:\n\t@exit 1\n' > Makefile
git add -A; git commit -qm mk
no "$G/g2-diff.sh" "$PWD/.tasks/x" "$PWD"; has "check failed"

t "G2 passes in-scope, in-budget work and runs the checks"
mkrepo; mktask x; echo '# ok' >> src/app.sh
ok "$G/g2-diff.sh" "$PWD/.tasks/x" "$PWD"; has "lint ok"

# ---------- G2.5 ----------
t "G2.5 refuses a missing review"
mkrepo; mktask x
no "$G/g25-review.sh" "$PWD/.tasks/x" "$PWD"; has "not found"

t "G2.5 refuses a review with no VERDICT"
mkrepo; mktask x; echo "looks fine" > .tasks/x/report/review.md
no "$G/g25-review.sh" "$PWD/.tasks/x" "$PWD"; has "no 'VERDICT:'"

t "G2.5 fails on blocking"
mkrepo; mktask x; printf '# R\n\nVERDICT: blocking\n' > .tasks/x/report/review.md
no "$G/g25-review.sh" "$PWD/.tasks/x" "$PWD"

t "G2.5 fails on concerns when review_blocking=true (default)"
mkrepo; mktask x; printf '# R\n\nVERDICT: concerns\n' > .tasks/x/report/review.md
no "$G/g25-review.sh" "$PWD/.tasks/x" "$PWD"

t "G2.5 passes concerns when review_blocking=false, warns"
mkrepo; mktask x; printf 'review_blocking = false\n' > .harness.toml
printf '# R\n\nVERDICT: concerns\n' > .tasks/x/report/review.md
ok "$G/g25-review.sh" "$PWD/.tasks/x" "$PWD"; has "non-blocking"

t "G2.5 parses decorated verdicts (bold, header, mixed case)"
mkrepo; mktask x; printf '# R\n\n**VERDICT: pass**\n' > .tasks/x/report/review.md
ok "$G/g25-review.sh" "$PWD/.tasks/x" "$PWD"
printf '# R\n\n## Verdict: blocking\n' > .tasks/x/report/review.md
no "$G/g25-review.sh" "$PWD/.tasks/x" "$PWD"

t "G2.5 passes on pass and logs the verdict event"
mkrepo; mktask x; printf '# R\n\nVERDICT: pass\n' > .tasks/x/report/review.md
ok "$G/g25-review.sh" "$PWD/.tasks/x" "$PWD"
filehas .tasks/x/report/events.jsonl '"phase":"review-verdict","verdict":"pass"'

# ---------- G3 ----------
t "G3 refuses to run before the machine gates have passed"
mkrepo; mktask x
touch .tasks/x/report/g0.pass .tasks/x/report/g1.pass .tasks/x/report/g2.pass
no "$G/g3-human.sh" "$PWD/.tasks/x" "$PWD" < /dev/null; has "gate g2.5 has not passed"

t "G3 refuses without a TTY — human review is never automated"
mkrepo; mktask x
touch .tasks/x/report/g0.pass .tasks/x/report/g1.pass .tasks/x/report/g2.pass .tasks/x/report/g2.5.pass
no "$G/g3-human.sh" "$PWD/.tasks/x" "$PWD" < /dev/null; has "interactive"

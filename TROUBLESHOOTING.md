# TROUBLESHOOTING

Symptom → cause → fix, for problems hit in real use. Search for the message
you're seeing. For *why* a gate refuses (the design), see PHILOSOPHY.md; this
is the operational companion.

Three rules cover most confusion: **specs instruct agents, manifests instruct
gates, the plan's Scope is the file contract** — a problem usually means the
wrong one of those three is being edited. **A task's work lives in its
worktree, not your main checkout** — "my changes vanished" is almost always
you looking in the wrong tree. And **run `harness` from your main checkout,
never from inside a worktree** — the tool navigates to the worktree for you.

---

## Setup & invocation

### `harness: no such adapter: kiro-cli` (or your value ignored)
`HARNESS_ADAPTER` names the adapter *file* (`kiro`, `claude`), not the binary.
Set `HARNESS_ADAPTER=kiro`; the kiro adapter finds `kiro-cli`/`kiro` itself
(or set `KIRO_BIN`). A misspelled variable *name* can't be caught — check it.

### `run harness doctor` first
Preflight for git repo, discoverable toolchain, adapter binary, deps, vault.
Three of the most common blockers surface here before a pipeline run.

---

## G2 — toolchain discovery

### `G2: REFUSED — this repo declares no lint/typecheck/test configuration` (exit 2)
The repo has no quality bar the harness can find, and it never supplies a
default. Declare one — scripts named exactly `lint`/`typecheck`/`test`, a
Makefile/justfile target, or the standard Cargo/Go/Python config — commit it,
retry. In a monorepo the bar may live in a sub-package; discovery walks npm
workspaces and one-level subdirs, but the script must be named exactly.

### G2 runs a command I didn't write / won't run the one I want (e.g. coverage)
G2's commands are *discovered from your manifests*, not from the spec — no
spec edit changes them. If coverage is part of your bar, put it *inside* the
test script: `"test": "vitest run --coverage"`. A script named `test:coverage`
is invisible to discovery by design. `harness doctor` lists what G2 will run.

---

## G2 — scope violations

### `G2: file changed outside declared scope: <file>`
The plan's `Scope:` doesn't list a file that changed. Either declare it (add
to PLAN.md, re-run `harness gate g1`) or revert the stray change. A directory
entry ending in `/` (`- angular-project/`) covers everything beneath it —
use it for mass changes instead of listing every file.

### Violation flood, all under one directory
The summary line names the directory and the one scope entry that covers it.
If the task owns that tree, add `- that-dir/` to Scope.

### `G2: task '<name>' — is this the task that owns these changes?`
You probably gated the wrong task (up-arrow habit). The task named in the
header and the log path is the one being checked — is it the one you meant?

### Scope violation on `.gitignore`/scaffolding right after `harness init`
`init`'s files are untracked; commit them before starting tasks.

### `G2: lockfile package-lock.json changed but its manifest package.json is not in scope`
A lockfile rides with its manifest. If you changed a dependency, add
`package.json` to Scope. If the lockfile changed incidentally (an install
rewrote it), `git checkout package-lock.json` to discard it — a task
shouldn't carry an unintended dependency change.

### A file with spaces in its name shows a trailing `"` and won't match scope
Fixed — git quotes such paths; the parser now dequotes. Pull the latest.

---

## G2 — diff budget

### `G2: diff adds N product lines (budget B)`
The budget counts *added product lines* — tests are exempt, deletions are
free. Read the *file list* first: more than one independently shippable
feature → split (`harness split <task>`). One coherent change slightly over →
raise `diff_budget_lines` in `.harness.toml`, committed with a reason (the
visible commit is the ratchet-brake). Greenfield work legitimately runs
higher than the 400 default. Never compress code or hide logic in test files
to duck the number.

---

## G2.5 — review

### `G2.5: review.md has no 'VERDICT:' line`
The reviewer produced no parseable verdict — often because the agent errored
but exited 0 (e.g. Kiro "model not available"), so the "review" is error
text. Check `report/reviewer-*.err` and `review.md`; re-run `harness review`.

### `G2.5: reviewer verdict — concerns/blocking`
Legitimate block. Read `report/review.md`. Route by where the defect lives:
implementation wrong → `harness implement` again (the reviewer's findings are
fed to the fresh run); spec wrong → fix spec, re-approve, re-plan; a nit →
fix it yourself and re-run the gates. To overrule concerns you disagree with:
set `review_blocking = false`, commit with your reasoning, re-gate — never a
silent workaround. Every rejection is also a calibration label.

### `reviewer_model = "kiro"` → `The model 'kiro' is not available`
A bare value is a *model id*, not an adapter. Use `""` (current adapter,
default model), `"some-model-id"`, or `"adapter/model"` for cross-CLI review.
Naming an adapter now fails fast with the correction.

---

## Worktrees & merge

### `npm run test` → `vitest: command not found` in a task
A fresh worktree has tracked files only — no `node_modules`. `harness
implement` now bootstraps from the lockfile (`npm ci`, etc.); pull the
latest, or `npm ci` in the worktree manually.

### "I don't see my changes" / the diff looks empty in main
Correct — the work is in the task's worktree, not main, until merge. See it
with `harness diff <task>` (reads the right tree, no navigation). Do NOT
checkout the task branch in main to look — that detaches the worktree HEAD.

### `WARNING: task '<name>' has a worktree, but your main checkout has uncommitted changes`
Split-brain: you edited/explored in main while the task's work belongs in its
worktree; the pipeline reviews the worktree and won't see the main edits. The
clean fix is **`harness adopt <task>`** — it shows the main→worktree delta,
asks, and moves your main work into the task's isolated worktree (worktrees
share `.git`, so it's a shared-stash move; `.tasks/` metadata stays in main).
Then gate/review/merge as normal. This is the intended flow: explore in main,
`adopt`, deliver through the isolated tree. (Or, to drive from main instead,
`git worktree remove` the worktree.)

### Does this task have a worktree? Do I need to check it out?
A task only gets a worktree once it passes G1 (created at `harness implement`).
Before that — or after you `git worktree remove` one — the task is driven from
your **main checkout**: edits, gates, review, and merge all operate on main,
and there's nothing to check out. Which is it? `harness status <task>` shows a
worktree line if one exists; `git worktree list` is definitive. No line = work
in main.

### A concern came back — do I re-plan? re-implement? touch the worktree?
Usually none of those. Route by where the defect lives, lowest rung first:
- a code or test fix (e.g. "add this assertion") is implementation-level — fix
  it in the tree and re-gate G2. This is most concerns.
- re-plan only when the plan is wrong (wrong files/approach), re-gate G1.
- re-spec only when the spec is wrong, re-approve and re-plan.
A `concerns`/`blocking` verdict is not "start over" — `review_blocking = true`
just halts the gate on any concern. And if the task has **no worktree** (you're
driving from main), apply the fix by hand in main, then re-gate. Do NOT run
`harness implement` on a no-worktree task whose work is uncommitted in main —
it forks a fresh worktree from main's last *commit*, which doesn't include your
uncommitted work, and the agent starts over in an empty tree.

### Applying a fix during or after review
Two rules. (1) The fix goes in the task's own tree — if the task has a worktree
(`harness status <task>`), edit the files under `<repo>-worktrees/<task>/`, not
in main; a fix in the wrong tree is split-brain and the merge won't include it
(the gate will stop you). (2) Changing the code invalidates the review that
approved the *old* code, so re-open the pipeline from G2: `harness gate g2
<task>` → `harness review <task>` → `harness approve` → `merge`. Never approve,
then patch, then merge — that ships code no gate saw; the `harness review` step
re-runs the reviewer and clears the stale approval. If the fix already landed in
the wrong tree, move it into the task's tree (or `git worktree remove` the
worktree to drive from main), then re-gate. (Single-tree mode, if enabled,
removes the wrong-tree half of this entirely — the task lives in main.)

### `merge: worktree HEAD is 'detached', not task/<name>`
A git-UI branch checkout detached the worktree. Your work is safe but
unmergeable until reattached: `git -C <worktree> checkout task/<name>`, then
merge. Avoid this by using `harness diff` instead of UI branch-hopping.

### `implement: the agent wrote to your MAIN checkout instead of the worktree (isolation leak)`
An agent (often a fan-out subtask) wrote files up in main via an absolute or
`../../<repo>` path instead of its worktree — worktrees isolate directories but
don't *confine* an agent, so one can escape. `implement` now detects this
(snapshots main before/after) and refuses rather than gating a worktree that's
missing the real work. Recover with **`harness adopt <task>`** — it pulls the
leaked work from main into the task's worktree — then re-gate. (Containers, a
future step, are the real confinement; until then this guard + the write-in-cwd
prompt are the defense.) If both trees ended up with versions of the same files
(e.g. stubs in the worktree, real impl in main), reconcile by hand: keep the
real files, delete the stubs, then adopt or collapse to main.

### A task is invisible from main, or its `.tasks/` lives inside a worktree
Cause: `harness` was run from *inside* a linked worktree, so it created and
looked up the task there instead of in main. Fixed — the harness now resolves
task metadata to the main checkout no matter where you invoke it — so pull the
latest. The rule to keep regardless: **run `harness` from your main checkout,
never from inside a worktree directory.** The tool navigates to the worktree
for you — that is what `task_wd`, `harness diff`, and `harness adopt` are for;
you never `cd` into a worktree yourself.

To rescue a task already stuck in a worktree (metadata + committed code there),
from main: `git merge --squash --no-commit task/<name>` brings its metadata and
code into main as uncommitted changes (stash any conflicting main edits first);
then `git worktree remove` + `git branch -D` the worktree, and gate it
single-tree from main.

### `WARNING: task '<name>' was already merged`
A merged task's `.tasks/` dir persists in history, so it stays a valid
target. You almost certainly meant another task.

---

## Specs & critique

### The reviewer keeps calling one criterion "ambiguous"; I keep rewording
You're rewording around a contradiction, not resolving it. Two shapes cause
it: (1) an AC lists a deliverable while prose defers it "to a later feature"
— an AC is binary, so DELETE it from the criteria and put one line under Out
of scope; (2) an AC describes what the target app does rather than what this
feature's code produces — rewrite as a diff-checkable output. Decide, edit
once, re-approve, re-critique.

### `harness critique` never says ready / seems never satisfied
Fixed by rule: `needs-work` now requires a real Must-fix item (style notes
never block), and re-critiques respect your edits — addressed and overruled
points are dropped, only still-open Must-fix items carry forward. If it still
blocks, there's a genuine open Must-fix item; read it. The critic works for
you — one or two rounds, then approve when Must-fix is empty or overruled.

### Critique flagged my spec as bundled
It contains more than one independently shippable feature. `harness split
<task>` stages the halves as draft specs; edit and approve each. Retire the
original task dir (delete `.tasks/<name>/`; it's inert).

---

## Adapters (Kiro)

### `Json ... is invalid: missing field 'name'` / `Falling back to user specified default`
Kiro requires `name` in agent configs (generated now). A config that fails to
load means Kiro silently ran with *default* permissions — the harness refuses
that output. Pull the latest; any run regenerates all role configs.

### `Command execute_bash is rejected ... non-interactive mode`
The role's command allowlist did its job — the agent tried a command outside
its permitted set and was refused (read-only roles get inspection commands
only; the implementer gets build/test/file-mutation commands). If a role
legitimately needs a command it lacks, widen that role's allowlist in
`adapters/kiro.sh` — don't blanket-trust `shell` (that voids the allowlist
entirely).

### A deletion task produced 1-line "stubbed" files instead of deleting
The implementer couldn't delete (no `rm` in its allowlist) and worked around
it. Fixed — the implementer can now `rm`/`git rm`/`mv`. Pull, reset the
worktree, re-run `harness implement`.

---

## Workflow patterns

### Deleting a whole directory
Scope it with a trailing slash (`- legacy/`, `- .gitignore`), not hundreds of
files. Deletions cost nothing against the budget. G1 accepts a path deleted
in the tree but present in HEAD, so the plan stays valid mid-deletion.

### A gate exposes a missing prerequisite mid-task (no tests/framework/dep yet)
If it belongs to *this* task's code, add it to Scope and continue. If it's a
pre-existing dependency, it's its own task: build and **merge** it first, then
resume. With worktrees, a dependent task's worktree branches from main at
`implement` time — so merge the prerequisite before you `implement` the
dependent, and it'll see the prerequisite's code.

### Building one feature that depends on another
Same rule: build the dependency to *merge*, then `harness implement` the
dependent (its worktree branches from the updated main). Record a standing
order in `DIRECTION.md` under Sequencing if it's more than a one-off.

### Brainstorming a feature with an agent
Do it in a plain chat session, outside the harness — the pipeline begins
where exploration ends. Then *you* write the spec from your understanding
(never "now write me the spec"). Keep the chat read-only; a brainstorm that
edits the repo leaves undeclared changes the next gate trips on.

### `harness stats` shows $0 cost
Kiro reports credits, not dollars; the credits column carries them (and
backfills from preserved transcripts for older tasks). A hand-implemented
task shows zero agent spend — correctly.

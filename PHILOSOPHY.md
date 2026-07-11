# PHILOSOPHY — why the harness behaves this way

You will be refused by this tool. This document exists so that when it
happens, you know why the refusal is correct and what the effective response
is. Read it once before your first task; return to the field guide whenever
a gate blocks you.

([HARNESS-PLAN.md](HARNESS-PLAN.md) is the design; [README.md](README.md) is
the reference; `templates/PRINCIPLES.md` is the pocket version of this.)

---

## The mental model

**Generation became cheap. Judgment didn't.** An agent produces 1,400 lines
in one sitting without tiring; your ability to genuinely review code has not
changed since before agents existed. Every failure mode of AI-assisted
development is some version of that ratio going wrong — more code produced
than anyone comprehends. The harness is a machine for rationing the scarce
resource: it concentrates your judgment at exactly two points (approving the
spec, reading the final diff) and mechanically guarantees that everything
between them held to contract.

Everything else follows from one rule:

> **Gates, not virtue.** An agent cannot advance the pipeline. Only a passing
> gate (exit 0) can. A model's claim that it tested, checked, or verified
> something is narration, not evidence — agents check off "ran lint" in repos
> that have no linter. Prompts can suggest behavior; they cannot enforce it.
> Exit codes can.

## Non-negotiables

These do not bend for convenience, deadlines, or good arguments. A change to
any of them is not a feature request; it is a different tool.

1. **Humans author specs.** Agents may critique a spec (`harness critique`)
   and reorganize one (`harness split` — the human's own words, repartitioned,
   staged as drafts). They never add intent, and nothing agent-touched is ever
   pre-approved: staged output is forced to `Status: draft` mechanically, not
   by instruction.
2. **G3 is a human reading the diff.** Interactive terminal, every time. There
   is no flag, environment variable, or "CI mode" that automates it, and none
   will be added.
3. **Only gates advance the pipeline.** No skip flags, no force flags, no
   admin override. If a gate is wrong, fix the gate — in the open, in a
   commit.
4. **No default toolchain.** A repo with no lint/typecheck/test config is
   refused (exit 2), never accommodated. The repo defines its quality bar or
   the harness does not work there.
5. **The harness emits; it never serves.** Structured files on disk are the
   entire observability contract. Dashboards, servers, and live agent views
   belong to external tools reading those files.
6. **Judgment stays concentrated at G0 and G3.** Features that smear human
   attention across the middle phases — supervision UX, approval prompts
   mid-pipeline, notification streams — are rejected on principle.
7. **Small stays small.** ~1,500 product lines, a four-key config, three-ish
   roles. Every addition is argued against the budget, and deletion is a
   first-class operation.

## Why each rule exists

**You write the spec. Agents may attack it; they never author it.**
The spec is the only point where your intent enters the pipeline. Every
downstream phase — plan, implementation, review — is *consistency-checking
against the spec*; no gate anywhere checks whether the spec itself is right.
That check is you, at G0. If an agent writes the spec, the pipeline's anchor
becomes another agent artifact, and G0 degrades into approving something
plausible you didn't think through — approval theater. Writing the
acceptance criteria is not overhead before the work; it *is* the work of
understanding. Use `harness critique` to have a fresh agent find the holes
in your draft — critique strengthens authorship, generation replaces it.
When the critique flags a bundled spec, `harness split` stages the partition
as draft specs — a purely clerical reorganization of your own words, each of
which you still edit and approve yourself. That is the full extent of agent
involvement in specs, deliberately: an agent that *applies* critique fixes
converges, one convenience at a time, into an agent that writes specs.

**The diff budget is 400 product lines because that's where human review
stops working.** The most-cited empirical result in code review (the
Cisco/SmartBear study of ~2,500 reviews) puts the cliff at roughly 400 lines
per session: beyond it, defect detection collapses and review becomes
rubber-stamping. Google's median change is ~24 lines; Meta ships large
features as stacks of small reviewable diffs. The budget is not a style
preference — it is the measured limit of the G3 you are about to perform.

**Test lines are exempt from the budget.** A size cap that counts tests
teaches agents to write fewer tests. Never let two controls fight: tests are
demanded by the implementer role and inspected by the reviewer, so the
budget deliberately ignores them.

**400 is a calibration starting point, not a constant of nature.** Lines are
a proxy for review burden, and the proxy pinches at the edges: greenfield
work (a new self-contained module) reads far faster per line than the same
count scattered across existing files, so early-phase repos legitimately dial
the budget up — per repo, in `.harness.toml`, committed with a reason. The
visible commit is the ratchet-brake: one calibration is tuning, a history of
creeping bumps is your specs growing, and `harness stats` will show which
story you're in. What never changes: the number must keep meaning "product
lines a human will genuinely review," and a coherent slightly-over feature
beats two mutilated fragments that duck the number.

**The reviewer is fresh-context, read-only, and ideally a different model.**
Self-review is contaminated review — the author (human or model) sees what
they meant, not what they wrote. The reviewer shares no context with the
implementer, cannot write, and is told to distrust the diff's own narration.
And because an LLM judge can fail silently, the harness measures it: every
verdict and every G3 decision is logged, and `harness calibrate` tells you
whether the reviewer actually catches what you catch (targets: TPR ≥ 0.80,
TNR ≥ 0.70). An unmeasured judge is a decoration.

**The harness refuses repos with no toolchain (G2, exit 2) and never
supplies a default.** The repo's own lint/typecheck/tests are its quality
bar; a harness that injects a generic one would make every repo accountable
to nothing in particular. If G2 refuses your repo, the repo is the problem —
declare a bar (scripts named `lint`/`typecheck`/`test`, a Makefile, etc.)
and retry. This refusal has ended more arguments than any code review.

**The harness emits; it never serves.** Every agent run writes its full
transcript and usage to `.tasks/<task>/report/`; gates log results to
`events.jsonl`. There is no dashboard and there will never be one inside the
harness — a live view of working agents is UI for babysitting, and the
design bets against babysitting. Watch a running agent with your session
tool if you must; judge it at the gates.

**Per-task gates verify locally; direction stays coherent through two
artifacts and you.** Every system that verifies locally can drift globally —
CI, peer review, TDD all share this. The harness's answer is not a gated
master plan (direction is judgment, and judgment stays human): it is
`DIRECTION.md` — a human-owned page of current bets, sequencing, and
deprecations that the planner plans within and the spec critic defends —
and `decisions/`, whose records of merged tasks are read back by those same
roles so settled questions stay settled. Sequencing intent belongs in
DIRECTION.md, never smuggled into acceptance criteria as "will be done in
the next feature" — an untestable criterion is where drift hides.

**Humans own exactly two gates.** G0 (is this what we want?) and G3 (is this
what we got?). Automating either defeats the tool. Supervising the phases
between them wastes the judgment the tool exists to conserve — if you find
yourself watching every implementer run, use a plain interactive agent
session instead; it's better at that job.

## Field guide: when a gate refuses you

**G0 refuses** — the spec is a draft, or has no acceptance criteria. That's
the point. Write testable criteria; set `Status: approved` only after you'd
bet a review sitting on them. Run `harness critique` first.

**The critique never says ready** — it can't happen anymore by role rule
(`needs-work` requires a non-empty Must-fix section; style items never
block), and re-critiques treat your edits as rulings. But the deeper rule is
yours: the critic works for you. One round, sometimes two; read the Must-fix
section seriously, skim the rest, and approve when Must-fix is empty or
consciously overruled. A critic you obey indefinitely is authoring your spec
by attrition — which is why it doesn't get to.

**G1 fails** — the plan references files or symbols that don't exist, or
declares overlapping scopes. The planner hallucinated or free-styled the
format. Re-run `harness plan` (fresh context, new roll) or fix PLAN.md by
hand — gates validate artifacts, they don't care who wrote them. Never
widen a scope just to make G1 pass.

**G2: REFUSED (exit 2)** — the repo declares no quality bar. Add one, commit
it, retry. The harness will not lower itself to repos that check nothing.

**G2 runs commands you didn't write, or won't run the one you want** — the
commands are *discovered* from your manifests: scripts named exactly `lint`,
`typecheck`, `test` (root and sub-packages), Makefile/justfile targets of the
same names, and the standard Rust/Go/Python declarations. `harness doctor`
lists them. The harness never invents or edits a command, and no amount of
spec-writing changes one — **specs instruct agents; manifests instruct
gates.** If coverage (or anything else) is part of your quality bar, it goes
*inside* the script that declares the bar: `"test": "vitest run --coverage"`
means G2 runs and enforces it, and its output lands in `g2.log` where the
reviewer is told to look. A script named `test:coverage` is invisible to
discovery — deliberately: the harness runs your declared bar, not everything
plausible.

**G2: scope violation** — a file changed outside the plan's declared Scope.
Either the agent drifted (revert the stray change) or the plan was
incomplete (fix the plan, re-gate G1, then G2). Uncommitted scaffolding
(e.g. from `harness init`) also triggers this: commit it.

**G2: budget exceeded** — run the decision procedure, in order:
1. Read the *file list*, not the diff. Count independently shippable
   features. More than one → split: park the second feature (`git stash push
   -u -- <files>`), narrow the plan, pipeline each feature through its own
   G2→G3→merge. Two 450-line reviews beat one 900-line skim.
2. Genuinely one irreducible change → raise `diff_budget_lines` in
   `.harness.toml` *for this repo, committed, visible in history* — and pay
   for it with a proportionally longer G3. A budget bump is a public act.
3. Never game it: don't compress code to duck the number, don't move logic
   into test files because they're exempt. The number only works while it
   means "product lines a human must deeply review."
4. If budgets keep blowing, the problem is upstream: your specs bundle
   features. The spec critic flags this — listen to it at critique time,
   when the fix costs an edit instead of a re-implementation.

**A gate exposes a missing prerequisite mid-task** (you assumed tests, docs,
or a capability existed — it doesn't). Route by where the missing piece
belongs. Part of the code your task touches → it's yours: add it to the
plan's Scope, re-gate G1, keep going. Pre-existing code you depend on but
don't touch → it's a prerequisite task: `git stash push -u` the feature, run
the small task through its own full pipeline, **merge it before you pop**
(merge commits with `git add -A`, so popped files in the tree get swept in),
then resume. A false assumption baked into the spec itself → fix the spec,
re-approve, re-plan. Since worktrees landed (build step 3), `harness implement` gives each task
its own sandbox checkout on a `task/<name>` branch — tasks no longer collide,
your checkout stays untouched until merge, and the stash dance survives only
for work you do by hand in the main tree. A prerequisite spec is allowed to
be five lines; small units through the pipeline is the system working.
If the reviewer is right, the task goes back to implement (fresh context,
with the review as input). If the reviewer is wrong, note it — your G3
decision is recorded, and `harness calibrate` turns your disagreements into
a measured verdict on the reviewer itself.

**G3** — there is no procedure for the reading. Read the diff. It's your name
on the merge. When you *find* an issue: reject, give the one-line reason when
prompted (it's saved to `report/g3-feedback.md` and fed to the next
implementer run), then route like a G2 failure — implementation defect →
`harness implement` again; wrong spec → edit it, re-approve, re-plan; a nit
you'd fix faster than explain → fix it yourself and let it re-run the gates.
Every rejection is also a calibration label: the reviewer passed something
you caught, and `harness calibrate` remembers.

## The friction is the feedback

The gates will jar you in ways plain agent use never does — a 419-line diff
refused over a 400-line budget, a critique that stings, a spec sent back for
splitting. When that happens, notice what the discomfort is *about*: scope,
testability, reviewability. That is precisely the feedback you asked a
quality system for — it just arrives as friction at the moment of violation
rather than as a compliment. There are only two delivery schedules for this
information: at the gate, while it costs an edit, or in the 30–90-day churn
numbers, after it costs a revert. There is no third option where the code
was quietly fine.

This is also the industry's live question, mostly unasked. Generation became
free; comprehension didn't; most teams are resolving that tension by merging
800-line agent diffs on green CI and never measuring what happens to them.
The harness's bet is to make the tension *visible and negotiable* instead:
when friction feels wrong, the legitimate responses are calibration in the
open (turn the dial, commit the reason) or fixing the gate itself — never a
quiet workaround. `harness stats` then turns "is this friction paying for
itself" from a feeling into a number: gate failures shifting from harness
gaps to genuine catches, budgets calibrating once versus creeping monthly.
A tool that stops jarring you because you got better is working; one that
stops jarring you because you routed around it has already failed.

## What the harness is not

- **Not an interactive assistant.** For exploration, debugging, and
  conversational iteration, use Claude Code or Kiro directly — the harness
  adds only ceremony there. It earns its keep on *delegated* work you judge
  at two points.
- **Not a spec generator.** By design. See above.
- **Not CI.** CI checks what's already committed; the gates run before
  anything is committed, per task, with scope and budget contracts CI knows
  nothing about. They complement.
- **Not finished when it merges.** Every merge writes a decision record to
  `decisions/`. Knowledge compounds; silent merges don't.

## Your first week

Day one: pick a small, real task. Write the spec yourself — smaller than
feels productive (one feature, testable criteria). `harness critique`, fix
what it catches, approve. Then let the pipeline run: `plan`, `implement`,
`review`, `approve`, `merge`. Expect to be refused at least once; when it
happens, find the failure in the field guide before overriding anything.
By the third task, the refusals mostly stop — not because the tool
softened, but because your specs got smaller and your plans got honest.
That transfer, from mechanical gate to personal habit, is the tool working.

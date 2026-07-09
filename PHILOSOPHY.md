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

**G2.5: blocking/concerns** — read `report/review.md` before anything else.
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

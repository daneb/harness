# SPEC — fanout

Status: approved
<!-- Human authorization: Dane — "Please write out the plan and GO!" (2026-07-12). -->

## Problem

Multi-task plans exist and G1 already verifies their scopes are disjoint,
but implementation still runs one agent at a time. The 900-line bundle
episode showed the need: independent tasks should run as parallel small
units, each reviewable alone, bounded by human judgment bandwidth.

## Proposal

Build-order step 4: when a plan declares more than one task, `harness
implement` fans out — one implementer per subtask, each in its own worktree
branched from the feature base, run in parallel capped by `fanout_cap`.
After the join, subtask branches combine into the feature worktree and are
reset to uncommitted changes, so G2, review, G3, and merge run exactly as
they do for a single task.

## Acceptance Criteria

- [ ] `harness implement <t>` on a multi-task plan runs one implementer per
      subtask in parallel, capped by fanout_cap (default 2)
- [ ] each subtask runs in its own worktree; the user's checkout is untouched
- [ ] after the join, the feature worktree holds all subtasks' changes
      uncommitted; the rest of the pipeline runs unchanged
- [ ] a failing subtask fails the phase, names the subtask, and preserves its
      output for inspection
- [ ] single-task plans behave exactly as before
- [ ] the regression suite covers the success, failure, and cap paths

## Out of scope

- zmx session integration (portable `&`+`wait` now; zmx attach later)
- per-subtask G2/review (the combined feature diff is the reviewed unit)
- containers

# PLAN — fanout

## Task: fanout
Scope:
- bin/harness
- adapters/claude.sh
- adapters/kiro.sh
- tests/
- README.md
- HARNESS-PLAN.md
- VERSION
Symbols:
- ensure_wt (new helper extracted from implement)
- plan_tasks
- fanout_cap
Steps:
- extract worktree creation into ensure_wt
- implement: single-task path unchanged; multi-task path launches one
  implementer per subtask in its own worktree, batched by fanout_cap
- join: wait per batch, collect failures, die naming failed subtasks
- combine: commit each subtask branch, merge into feature worktree,
  reset --mixed to base so changes are uncommitted
- adapters: HARNESS_SUBTASK narrows the implementer prompt and suffixes
  its transcript/log filenames so parallel runs do not collide
- regression tests: fan-out success, subtask failure, cap batching

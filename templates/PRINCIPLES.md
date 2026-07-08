# PRINCIPLES.md — global engineering principles

Install at `~/.harness/PRINCIPLES.md`. Keep under ~40 lines, forever.

1. Spec before code. If the acceptance criteria can't be written, the work
   isn't understood yet.
2. Gates, not virtue. Progress requires a passing check, never a claim of
   quality.
3. Small diffs. A change that can't be reviewed in one sitting is two changes.
4. The repo's own toolchain is the quality bar. Where there is none, add one
   before adding features.
5. Token economy: retrieve symbols, not files. Context is a budget, not a dump.
6. Fresh eyes review. The author of a change never reviews it, human or model.
7. Plans reference reality. Every file and symbol in a plan must exist or be
   explicitly declared new.
8. Scope is a contract. Nothing outside the declared file scope changes, ever.
9. Tests define done. An acceptance criterion without a failing-then-passing
   test is an opinion.
10. Humans own merges. Automation earns its way to the door of the decision,
    not through it.
11. Write down decisions. A merge without a decision record is knowledge
    thrown away.
12. Boring is a feature. Prefer the obvious implementation; cleverness needs
    a reason in writing.
13. When the plan is wrong, fix the plan. Never work around a gate.
14. Bounded parallelism. Run only as many agents as you can genuinely judge.
15. Delete freely. The system stays small because removal is a first-class
    operation.

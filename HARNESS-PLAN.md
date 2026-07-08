# Terminal AI Engineering Harness — Build Plan

**Working name:** TBD (suggestion: `forge` or `gate`)
**Owner:** Dane
**Date:** July 2026
**Status:** Approved design, pre-build

---

## 1. Vision

A thin terminal harness that drives systematic, well-executed software development by orchestrating existing agent CLIs (Claude Code, Copilot CLI, Kiro CLI) through mechanical quality gates, with aggressive token economy and bounded parallelism.

The harness is a **convention plus a small CLI, not an application**. It enforces Karpathy's agentic-engineering discipline mechanically: spec design, plan validation, diff review, eval loops, and human oversight as the final gate.

**Anti-goals (learned from Atelier / Forgiven):**

- Do not own the agent runtime or IDE loop
- No workflow DSL or engine — dynamism lives in data (the plan), not in machinery
- No persona/role frameworks (BMAD, SuperClaude) — roles are prompts plus permissions
- v1 stays under ~1,500 lines total. If it grows past that, something is wrong.

---

## 2. Core principles

1. **Gates, not virtue.** An agent cannot advance a phase; only a passing gate (exit 0) can.
2. **Token economy is enforced, not hoped for.** Agents never read whole files by default; they use symbol-aware retrieval.
3. **The plan is the workflow.** The human-approved plan declares tasks, file scopes, and fan-out. No separate workflow definition exists.
4. **Roles = prompt + permissions + pipeline position + fresh context.** Nothing more.
5. **Repos define their own quality bar.** The harness discovers each repo's existing lint/type/test config and **refuses to run where none exists**. It never supplies a default toolchain.
6. **Human review is never automated.** G3 is always a person.
7. **Knowledge compounds.** Every merged task writes back a decision record.

---

## 3. Architecture layers

### Layer 1 — Session substrate: zmx

- One zmx session per agent task: `zmx attach px.taskname`
- Session prefix per feature (`ZMX_SESSION_PREFIX`), `zmx wait` as the join point
- Daemon-per-session isolation: one crashed agent doesn't take down the rest
- Window management stays with the OS (no tmux layer)

### Layer 2 — Isolation: containers + worktrees

- Git worktree per task; bind-mounted into a throwaway container (Apple `container` or Docker)
- Agents write only inside the sandbox; merges happen only through the gate layer
- Reviewer role gets a **read-only** mount

### Layer 3 — Context economy: `ctx` subcommand

Agents are steered to use these instead of reading files:

| Command | Purpose | Backed by |
|---|---|---|
| `ctx map` | Repo skeleton (files, symbols, signatures) | tree-sitter |
| `ctx sym <name>` | Single symbol + signature + docstring | tree-sitter / ast-grep |
| `ctx grep <pattern>` | Lexical search with line budgets | ripgrep |
| `ctx doc <topic>` | Knowledge retrieval | Obsidian vault |

Steering rule (one sentence, in AGENTS.md): *"Never read whole files; use ctx. Escalate to full source only when ctx is insufficient."*

fzf is used interactively by the human for context selection when composing specs.

### Layer 4 — Gates

Each gate is an executable that exits 0 or 1. Claude Code hooks invoke them natively; the orchestrator runs them for other CLIs.

| Gate | Name | Checks |
|---|---|---|
| **G0** | Spec gate | SPEC.md exists, has acceptance criteria, human-approved |
| **G1** | Plan gate | Plan references only real symbols/files (ast-grep/ctags check — cheap hallucination detection); task file scopes are disjoint if fan-out is declared |
| **G2** | Diff gate | Repo's own lint + typecheck + tests pass; diff-size budget respected; no files touched outside declared scope. **Refuses to run if the repo has no lint/type/test config.** |
| **G2.5** | Review gate | Fresh-context reviewer agent (different model than implementer), read-only, outputs structured verdict: blocking / concerns / pass |
| **G3** | Human gate | You read the diff. Never automated. |

### Layer 5 — Roles

Three files. That is the whole team.

```
roles/
  planner.md      (~40 lines: decompose spec into tasks with file scopes)
  implementer.md  (~40 lines: implement one task within scope, use ctx)
  reviewer.md     (~40 lines: what to look for, structured verdict format)
```

Mechanics per role:
- **Prompt:** the role file, appended as system prompt (`claude -p --append-system-prompt roles/reviewer.md`)
- **Permissions:** implementer = write in sandbox; reviewer = read-only, no write tools
- **Context:** always fresh. The reviewer never shares context with the implementer (self-review contamination)
- **Cross-model review:** reviewer runs on a different model/CLI than the implementer via the adapter layer

### Layer 6 — Adapter layer

One contract: `run(task_spec, workdir) → diff + report`

```
adapters/
  claude.sh    (claude -p, hooks for gates)
  copilot.sh
  kiro.sh
```

The harness owns the spec format (`SPEC.md`, `PLAN.md`); adapters translate. Agents are interchangeable.

### Layer 7 — Steering files (layered, small, nothing else auto-loaded)

```
~/.harness/PRINCIPLES.md   (~40 lines, global engineering principles)
repo/AGENTS.md             (~60 lines, repo conventions + the ctx rule)
task/SPEC.md               (per-task, the only task-specific context)
```

### Layer 8 — Knowledge writeback

On merge: append a one-page task record (spec link, key decisions, gate results) to `repo/decisions/` and optionally the Obsidian vault. ADR discipline, near-zero effort.

---

## 4. Pipeline (fixed shape)

```
SPEC ──G0──▶ PLAN ──G1──▶ IMPLEMENT ──G2──▶ REVIEW ──G2.5──▶ HUMAN ──G3──▶ MERGE ──▶ WRITEBACK
                              │
                              ├─ task A (worktree + container + zmx px.a)
                              ├─ task B (worktree + container + zmx px.b)
                              └─ zmx wait (join) before G2 runs across the set
```

- Fan-out happens **only** at implement, **only** when G1 has verified disjoint file scopes
- Concurrency cap: **2–3** (matches human judgment bandwidth — the real bottleneck)
- If a second pipeline shape is ever genuinely needed (e.g. docs-only, skip G2 tests), add it as a **second named pipeline behind a flag** — never a DSL

---

## 5. Per-repo configuration (~8 lines of TOML, optional)

```toml
# .harness.toml
reviewer_model = "gpt-5"        # cross-model vs implementer
fanout_cap = 2
review_blocking = true
diff_budget_lines = 400
```

No other configuration exists.

---

## 6. Repo layout convention

```
myrepo/
  .harness.toml          (optional)
  AGENTS.md
  decisions/             (writeback records)
  .tasks/
    feature-x/
      SPEC.md
      PLAN.md
      report/            (gate outputs, reviewer verdicts)
```

---

## 7. Build order

| Step | Deliverable | Proves |
|---|---|---|
| **1** | Repo layout + G0–G3 gate scripts + Claude adapter; single-task flow end to end on one real repo | The gate design meets reality |
| **2** | `ctx` tooling (map, sym, grep, doc) + steering rule | Token economy works in practice |
| **3** | Worktree + container isolation | Sandbox model |
| **4** | zmx fan-out + `zmx wait` join + G1 disjoint-scope check | Bounded parallelism |
| **5** | Second adapter (Copilot or Kiro) + cross-model review | The abstraction holds |
| **6** | Writeback to decisions/ and vault | Knowledge compounds |

Start with shell/just scripts. Promote hot paths to a small Rust or TypeScript binary **only when proven** by usage.

---

## 8. Tooling inventory

| Tool | Role |
|---|---|
| zmx (+ zsm) | Session persistence, orchestration join points |
| Apple `container` / Docker | Agent sandboxes |
| git worktree | Per-task isolation |
| tree-sitter / ast-grep | Symbol-aware retrieval, G1 hallucination check |
| ripgrep | Lexical search with budgets |
| fzf | Human context selection during spec writing |
| just / shell | v1 orchestrator |
| Claude Code / Copilot CLI / Kiro CLI | Interchangeable agent runtimes |
| Obsidian vault | Knowledge repository (`ctx doc`) |

---

## 9. Success criteria

- v1 under ~1,500 lines
- A feature goes spec → merge with every gate exercised, on a real repo
- Token usage per task measurably lower than naive full-file agent runs (log and compare)
- A repo with no lint/test config is **refused**, not accommodated
- Reviewer catches at least one real issue the implementer missed (cross-model validation)
- You can hand the convention to another engineer with only PRINCIPLES.md and this plan

---

## 10. Open decisions

- [ ] Name
- [ ] v1 language for the binary when promoted (Rust vs TypeScript)
- [ ] Diff-size budget default
- [ ] Reviewer verdict schema (JSON vs structured markdown)
- [ ] Vault writeback: automatic or prompted
- [x] Observability (decided 2026-07-08): **the harness emits, it never serves.** Every agent run captures its full event stream to `report/<role>-transcript.jsonl`; gates and phases append usage/cost/duration to `report/events.jsonl`. Any dashboard/HTTP viewer is a separate external reader of those files — never a harness subcommand. Live watching of running agents is Layer 1's job (`zmx attach`).

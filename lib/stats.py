#!/usr/bin/env python3
"""Aggregate every task's events.jsonl: cost, agent time, gate outcomes.

The UX health metric is gate failure rate by gate — early on, most failures
are harness gaps; as the tool matures they should become genuine defects
caught. Usage: stats.py <repo_root>
"""
import glob
import json
import os
import sys

root = sys.argv[1]
rows = []                 # (task, cost, agent_ms, runs, fails, fail_detail)
gate_runs = {}            # gate -> [runs, fails]

for ev in sorted(glob.glob(os.path.join(root, ".tasks", "*", "report", "events.jsonl"))):
    task = ev.split(os.sep)[-3]
    cost = 0.0
    credits = 0.0
    agent_ms = 0
    runs = 0
    fails = {}
    for line in open(ev):
        try:
            d = json.loads(line)
        except ValueError:
            continue
        phase = d.get("phase", "")
        if phase.startswith("gate:"):
            g = phase[5:]
            gate_runs.setdefault(g, [0, 0])[0] += 1
            runs += 1
            if d.get("result") != "pass":
                gate_runs[g][1] += 1
                fails[g] = fails.get(g, 0) + 1
        elif phase in ("planner", "implementer", "reviewer", "spec-critic", "spec-splitter"):
            cost += d.get("cost_usd") or 0
            credits += d.get("credits") or 0
            agent_ms += d.get("duration_ms") or 0
    detail = " ".join("%s:%d" % (g, n) for g, n in sorted(fails.items()))
    rows.append((task, cost, credits, agent_ms, runs, sum(fails.values()), detail))

if not rows:
    sys.exit("stats: no events yet — run tasks through the pipeline first")

def dur(ms):
    s = ms // 1000
    return "%dm%02ds" % (s // 60, s % 60) if s >= 60 else "%ds" % s

print("%-28s %7s %8s %9s %10s  %s" % ("task", "cost$", "credits", "agent", "gate runs", "gate fails"))
for task, cost, credits, ms, runs, nf, detail in rows:
    print("%-28s %7.2f %8.2f %9s %10d  %s" % (task, cost, credits, dur(ms), runs, detail or "-"))

total_cost = sum(r[1] for r in rows)
total_credits = sum(r[2] for r in rows)
total_ms = sum(r[3] for r in rows)
print()
print("%d task(s), $%.2f + %.2f credits agent spend, %s agent time"
      % (len(rows), total_cost, total_credits, dur(total_ms)))
parts = []
for g in sorted(gate_runs):
    r, f = gate_runs[g]
    parts.append("%s %d/%d" % (g, f, r))
print("gate failures/runs: " + "  ".join(parts))

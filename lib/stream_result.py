#!/usr/bin/env python3
"""Parse a `claude -p --output-format stream-json` transcript.

Appends one phase event (model, cost, tokens, duration) to events.jsonl and
prints the agent's final result text to stdout, so callers can save it as the
phase artifact (PLAN.md, review.md, ...).

Usage: stream_result.py <transcript.jsonl> <events.jsonl> <phase>
"""
import json
import sys
import time

transcript, events, phase = sys.argv[1], sys.argv[2], sys.argv[3]

model = None
result = None
with open(transcript) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            d = json.loads(line)
        except ValueError:
            continue
        if d.get("type") == "system" and d.get("subtype") == "init":
            model = d.get("model")
        elif d.get("type") == "result":
            result = d

if result is None:
    sys.exit("stream_result: no result event in transcript — agent run failed?")

event = {
    "ts": time.strftime("%Y-%m-%dT%H:%M:%S"),
    "phase": phase,
    "model": model,
    "cost_usd": result.get("total_cost_usd"),
    "duration_ms": result.get("duration_ms"),
    "num_turns": result.get("num_turns"),
    "usage": result.get("usage"),
    "is_error": result.get("is_error", False),
}
with open(events, "a") as f:
    f.write(json.dumps(event) + "\n")

if result.get("is_error"):
    sys.exit("stream_result: agent returned an error result (see transcript)")

print(result.get("result") or "")

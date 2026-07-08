#!/usr/bin/env python3
"""Reviewer calibration: is the G2.5 reviewer's verdict predictive of the G3
human decision? Chronologically pairs each human-decision event with the most
recent review-verdict before it, across every task's events.jsonl.

Thresholds follow the eval-kit discipline an LLM judge must clear before it
is trusted: TPR >= 0.8, TNR >= 0.7 against human labels.

Usage: calibrate.py <repo_root>
"""
import glob
import json
import os
import sys

root = sys.argv[1]
pairs = []      # (task, verdict, decision)
unlabeled = 0   # verdicts never followed by a human decision (e.g. blocked pre-G3)

for ev in sorted(glob.glob(os.path.join(root, ".tasks", "*", "report", "events.jsonl"))):
    task = ev.split(os.sep)[-3]
    pending = None
    for line in open(ev):
        try:
            d = json.loads(line)
        except ValueError:
            continue
        if d.get("phase") == "review-verdict":
            if pending is not None:
                unlabeled += 1
            pending = d.get("verdict")
        elif d.get("phase") == "human-decision" and pending is not None:
            pairs.append((task, pending, d.get("decision")))
            pending = None
    if pending is not None:
        unlabeled += 1

if not pairs:
    sys.exit("calibrate: no (verdict, human decision) pairs yet — "
             "tasks must pass through G2.5 and G3 to generate labels")

# Reviewer "flagged" = concerns|blocking. Human "reject" = a real problem existed.
tp = sum(1 for _, v, d in pairs if v != "pass" and d == "reject")
fn = sum(1 for _, v, d in pairs if v == "pass" and d == "reject")
tn = sum(1 for _, v, d in pairs if v == "pass" and d == "approve")
fp = sum(1 for _, v, d in pairs if v != "pass" and d == "approve")

def rate(num, den):
    return num / den if den else None

def show(label, r, target):
    if r is None:
        return "%s    n/a (no such labels yet)   target ≥ %.2f" % (label, target)
    mark = "✓" if r >= target else "✗"
    return "%s   %.2f   target ≥ %.2f  %s" % (label, r, target, mark)

tpr = rate(tp, tp + fn)
tnr = rate(tn, tn + fp)

print("reviewer calibration — %d labeled pair(s), %d verdict(s) unlabeled "
      "(blocked before G3, or G3 not yet run)" % (len(pairs), unlabeled))
print()
print("                    human reject   human approve")
print("reviewer flagged       TP %-3d         FP %-3d" % (tp, fp))
print("reviewer passed        FN %-3d         TN %-3d" % (fn, tn))
print()
print(show("TPR (catches real problems)", tpr, 0.80))
print(show("TNR (passes good diffs)    ", tnr, 0.70))
print()
if len(pairs) < 20:
    print("n < 20 — collect more labeled pairs before trusting these numbers.")
if unlabeled and tp + fn == 0:
    print("note: with review_blocking=true, flagged verdicts rarely reach G3;")
    print("TPR only becomes measurable via review_blocking=false or re-reviews.")

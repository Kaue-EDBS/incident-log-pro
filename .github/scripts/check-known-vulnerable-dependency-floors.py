#!/usr/bin/env python3
import re
import sys
from pathlib import Path

text = Path("bun.lock").read_text(encoding="utf-8")

checks = {
    "brace-expansion 1.x": (r'brace-expansion@1\.(\d+)\.(\d+)', (1, 18)),
    "brace-expansion 5.x": (r'brace-expansion@5\.(\d+)\.(\d+)', (0, 9)),
    "js-yaml 4.x": (r'js-yaml@4\.(\d+)\.(\d+)', (3, 2)),
    "nanoid 3.x": (r'nanoid@3\.(\d+)\.(\d+)', (3, 18)),
}

failed = False
for label, (pattern, floor) in checks.items():
    matches = [tuple(map(int, m)) for m in re.findall(pattern, text)]
    if not matches:
        print(f"FAIL {label}: version not found")
        failed = True
        continue
    lowest = min(matches)
    if lowest < floor:
        print(f"FAIL {label}: found {lowest[0]}.{lowest[1]}, requires >= {floor[0]}.{floor[1]}")
        failed = True
    else:
        print(f"PASS {label}: floor satisfied ({lowest[0]}.{lowest[1]})")

if failed:
    sys.exit(1)

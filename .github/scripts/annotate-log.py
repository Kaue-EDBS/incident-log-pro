#!/usr/bin/env python3
"""Publish the useful part of a test log as GitHub annotations.

Annotations are readable through the public checks API, so failures can be diagnosed
without downloading the (authenticated) job log. Usage: annotate-log.py LOG TITLE [error|notice]
"""
import re
import sys

path, title = sys.argv[1], sys.argv[2]
level = sys.argv[3] if len(sys.argv) > 3 else "error"

ANSI = re.compile(r"\x1b\[[0-9;]*m")
with open(path, encoding="utf-8", errors="replace") as handle:
    lines = [ANSI.sub("", line.rstrip("\n")) for line in handle]

if level == "error":
    keep = [
        line
        for line in lines
        if re.search(r"(✘|FAIL|Error|error:|Expected|Received|expect\(|Timeout|at .*spec\.ts:\d+|›|Locator|waiting for)", line)
    ] or lines[-60:]
else:
    keep = [line for line in lines if line.startswith(("PASS", "Phase", "Latency"))]

text = "\n".join(keep[:400])
# GitHub limits annotations per step; send the text in a few large chunks.
chunk = 3500
for index in range(0, min(len(text), chunk * 8), chunk):
    body = text[index : index + chunk].replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
    print(f"::{level} title={title} ({index // chunk + 1})::{body}")

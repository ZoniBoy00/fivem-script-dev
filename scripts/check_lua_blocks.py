#!/usr/bin/env python3
"""Syntax-check every ```lua fenced block in Markdown files with `luac -p`.

Usage: python scripts/check_lua_blocks.py [luac-binary]
Exits non-zero when any block fails to compile.
"""
import pathlib
import re
import subprocess
import sys
import tempfile

LUAC = sys.argv[1] if len(sys.argv) > 1 else "luac"
FENCE = re.compile(r"^```lua[ \t]*\n(.*?)^```", re.M | re.S)

failures = 0
checked = 0
for md in sorted(pathlib.Path(".").glob("**/*.md")):
    if ".git" in md.parts:
        continue
    text = md.read_text(encoding="utf-8")
    for match in FENCE.finditer(text):
        checked += 1
        line = text.count("\n", 0, match.start()) + 2
        with tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False, encoding="utf-8") as tmp:
            tmp.write(match.group(1))
        result = subprocess.run([LUAC, "-p", tmp.name], capture_output=True, text=True)
        pathlib.Path(tmp.name).unlink()
        if result.returncode != 0:
            failures += 1
            # luac reports "<luac>: <tmpfile>:<n>: message" — keep only "<n>: message"
            msg = result.stderr.strip().replace(tmp.name, "block")
            print(f"{md.as_posix()}:{line}: {msg}")

print(f"Checked {checked} Lua blocks, {failures} failed")
sys.exit(1 if failures else 0)

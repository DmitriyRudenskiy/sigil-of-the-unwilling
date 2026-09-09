#!/usr/bin/env python3
"""Strip all comments from GDScript/Python sources (strings preserved).

- .gd: remove `#`/`##` comments (scanner respects ", ', \"\"\" escapes).
- .py: remove docstrings (ast line ranges) + `#` comments.
- Then: drop emptied lines, collapse blank runs, rstrip, single trailing newline.
"""
import ast
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def scan_strip(text: str) -> str:
    out = []
    i, n = 0, len(text)
    in_str = None  # '"', "'", or triple quote
    while i < n:
        ch = text[i]
        if in_str:
            out.append(ch)
            if ch == "\\" and i + 1 < n:
                out.append(text[i + 1])
                i += 2
                continue
            if text.startswith(in_str, i):
                out.append(in_str[1:] if len(in_str) == 3 else "")
                i += len(in_str)
                in_str = None
                continue
            i += 1
            continue
        if ch in ('"', "'"):
            if text.startswith(ch * 3, i):
                in_str = ch * 3
                out.append(ch * 3)
                i += 3
                continue
            in_str = ch
            out.append(ch)
            i += 1
            continue
        if ch == "#":
            nl = text.find("\n", i)
            i = n if nl == -1 else nl
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def strip_docstrings(text: str) -> str:
    try:
        tree = ast.parse(text)
    except SyntaxError:
        return text
    spans = []
    for node in ast.walk(tree):
        if isinstance(node, (ast.Module, ast.ClassDef, ast.FunctionDef, ast.AsyncFunctionDef)):
            body = node.body
            if (
                body
                and isinstance(body[0], ast.Expr)
                and isinstance(body[0].value, ast.Constant)
                and isinstance(body[0].value.value, str)
            ):
                spans.append((body[0].lineno, body[0].end_lineno))
    if not spans:
        return text
    lines = text.splitlines(keepends=True)
    keep = [
        ln
        for idx, ln in enumerate(lines, start=1)
        if not any(a <= idx <= b for a, b in spans)
    ]
    return "".join(keep)


def clean_lines(text: str) -> str:
    lines = []
    for ln in text.split("\n"):
        s = ln.rstrip()
        if not s and lines and not lines[-1]:
            continue  # collapse blank runs
        lines.append(s)
    while lines and not lines[-1]:
        lines.pop()
    return "\n".join(lines) + "\n" if lines else ""


def main() -> int:
    targets = sorted(ROOT.glob("scripts/**/*.gd")) + sorted(ROOT.glob("tests/**/*.gd"))
    targets += sorted(ROOT.glob("tests/**/*.py"))
    changed = 0
    for f in targets:
        if "__pycache__" in f.parts:
            continue
        orig = f.read_text()
        new = scan_strip(orig)
        if f.suffix == ".py":
            new = scan_strip(strip_docstrings(new))
        new = clean_lines(new)
        if new != orig:
            f.write_text(new)
            changed += 1
    print(f"changed {changed}/{len(targets)} files")
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Проверка связности Obsidian-vault в docs/.

Ищется:
  1. wikilinks [[target]] / [[target|alias]] / [[target#anchor]], ведущие в никуда;
  2. кириллические имена файлов (политика именования docs/ — только латиница);
  3. frontmatter-статусы вне разрешённого списка.

Запуск: python3 scripts/check_docs_links.py   (выход ≠ 0 при находках — для CI)
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCS = os.path.join(ROOT, "docs")

ALLOWED_STATUSES = {"canon", "deepened", "draft", "redirect", "reference", "archived"}


def doc_stems():
    stems = set()
    for name in os.listdir(DOCS):
        base, ext = os.path.splitext(name)
        if ext in {".md", ".canvas"}:
            stems.add(base)
    return stems


def check_wikilinks(stems):
    broken = []
    link_re = re.compile(r"\[\[([^\]\|#]+)(?:#[^\]\|]*)?(?:\|[^\]]*)?\]\]")
    for name in sorted(os.listdir(DOCS)):
        if not name.endswith(".md"):
            continue
        path = os.path.join(DOCS, name)
        text = open(path, encoding="utf-8").read()
        body = re.sub(r"^---.*?---\n", "", text, count=1, flags=re.S)  # skip frontmatter
        if name in {"STRUCTURE_AUDIT.md", "RESTRUCTURING_LOG.md"}:
            continue  # архивные логи: цитаты легаси-путей (gdd/, _index) — ожидаемы
        body = re.sub(r"`[^`\n]*`", "", body)  # skip inline code (log examples)
        for m in link_re.finditer(body):
            target = m.group(1).strip()
            if target.endswith(".canvas"):
                continue  # canvas-файлы живут в docs/, Obsidian резолвит по имени
            if "/" in target:  # vault-стиль gdd/X — легаси, не резолвится в docs/
                broken.append((name, target))
            elif target not in stems:
                broken.append((name, target))
    return broken


def check_filenames():
    return [n for n in sorted(os.listdir(DOCS)) if re.search(r"[А-Яа-яЁё]", n)]


def check_statuses():
    bad = []
    for name in sorted(os.listdir(DOCS)):
        if not name.endswith(".md"):
            continue
        text = open(os.path.join(DOCS, name), encoding="utf-8").read()
        m = re.match(r"^---\n(.*?)\n---", text, re.S)
        if not m:
            continue
        s = re.search(r"^status:\s*(.+)$", m.group(1), re.M)
        if s and s.group(1).strip() not in ALLOWED_STATUSES:
            bad.append((name, s.group(1).strip()))
    return bad


def main():
    stems = doc_stems()
    failed = False

    broken = check_wikilinks(stems)
    if broken:
        failed = True
        print("BROKEN WIKILINKS:")
        for f, t in broken:
            print(f"  {f}: [[{t}]]")

    cyr = check_filenames()
    if cyr:
        failed = True
        print("CYRILLIC FILENAMES (policy: latin only):")
        for n in cyr:
            print(f"  docs/{n}")

    statuses = check_statuses()
    if statuses:
        failed = True
        print("UNKNOWN FRONTMATTER STATUS:")
        for f, s in statuses:
            print(f"  {f}: status: {s} (allowed: {', '.join(sorted(ALLOWED_STATUSES))})")

    if failed:
        sys.exit(1)
    print(f"OK: docs/ links consistent ({len(stems)} notes checked)")


if __name__ == "__main__":
    main()

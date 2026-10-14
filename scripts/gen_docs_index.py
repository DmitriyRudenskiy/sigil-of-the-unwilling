#!/usr/bin/env python3
"""Индекс документации: docs/INDEX.md генерируется из frontmatter живых заметок.

Рот индекса дороже его отсутствия, поэтому индекс — генератор, а не ручной список:

    python3 scripts/gen_docs_index.py           # перегенерировать docs/INDEX.md
    python3 scripts/gen_docs_index.py --check   # выход ≠ 0, если INDEX.md устарел

Зона та же, что у check_docs_links: банковская зона docs/bank/ вне индекса (D-102),
архивные логи показываются с пометкой (у них нет frontmatter — AGENTS.md).

Порядок групп (сверху вниз): реестры и процессы → GDD и стиль → прочее; внутри
группы — по имени файла.
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import check_docs_links as ck  # noqa: E402  (та же зона сканирования)

OUT = os.path.join(ck.DOCS, "INDEX.md")
SELF = "INDEX.md"

REGISTRIES = {"CHANGELOG.md", "DECISIONS.md", "QUESTIONS.md", "BANK.md", "INDEX.md"}

FM_RE = re.compile(r"^---\n(.*?)\n---\n", re.S)
FIELD_RE = re.compile(r"^(title|status|date):\s*(.*)$", re.M)


def frontmatter(path):
    text = open(path, encoding="utf-8").read()
    m = FM_RE.match(text)
    if not m:
        return {}
    return {k: v.strip().strip('"') for k, v in FIELD_RE.findall(m.group(1))}


def rows():
    out = []
    for path in ck.doc_files():
        rel = os.path.relpath(path, ck.DOCS).replace(os.sep, "/")
        if rel == SELF or path.endswith(".canvas"):
            continue
        fm = frontmatter(path)
        if os.path.basename(rel) in ck.ARCHIVE_LOGS:
            fm.setdefault("status", "архив (вне графа)")
        out.append((rel, fm))
    return sorted(out)


def group(rel):
    if rel.startswith("mvp/") or rel in REGISTRIES:
        return "Реестры и процессы"
    return "GDD и стиль"


def render():
    lines = [
        "---",
        "title: Индекс документации",
        "tags:",
        "  - index",
        "status: reference",
        "date: 2026-10-14",
        "---",
        "",
        "> **Автогенерат — руками не редактировать.** Перегенерация:",
        "> `python3 scripts/gen_docs_index.py`; проверка устаревания — тот же файл",
        "> с `--check`. Зона та же, что у `scripts/check_docs_links.py`:",
        "> банковская зона `docs/bank/` вне индекса (D-102).",
        "",
        "> Статусы: `canon` / `deepened` / `draft` / `reference` / `redirect` /",
        "> `snapshot` / `archived`. `redirect` — файл-перенаправление, читать цель.",
        "",
    ]
    grouped = {}
    for rel, fm in rows():
        grouped.setdefault(group(rel), []).append((rel, fm))
    for name in [g for g in ("Реестры и процессы", "GDD и стиль") if g in grouped]:
        items = grouped[name]
        lines += [f"## {name} ({len(items)})", "", "| Заметка | Название | Статус | Дата |", "| --- | --- | --- | --- |"]
        for rel, fm in items:
            stem = os.path.splitext(os.path.basename(rel))[0]  # wikilink без пути (правило docs/)
            lines.append(
                f"| [[{stem}]] | {fm.get('title', '—')} | {fm.get('status', '—')} | {fm.get('date', '—')} |"
            )
        lines.append("")
    return "\n".join(lines)


def main():
    check = "--check" in sys.argv
    want = render()
    have = open(OUT, encoding="utf-8").read() if os.path.exists(OUT) else ""
    if check:
        if want != have:
            print("INDEX.md устарел: python3 scripts/gen_docs_index.py")
            sys.exit(1)
        print(f"OK: INDEX.md актуален ({len(rows())} заметок)")
        return
    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(want)
    print(f"docs/INDEX.md: {len(rows())} заметок")


if __name__ == "__main__":
    main()

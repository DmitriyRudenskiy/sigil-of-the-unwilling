#!/usr/bin/env python3
"""Проверка связности Obsidian-vault в docs/.

Ищется:
  1. wikilinks [[target]] / [[target|alias]] / [[target#anchor]], ведущие в никуда;
  2. кириллические имена файлов (политика именования docs/ — только латиница);
  3. frontmatter-статусы вне разрешённого списка.

Сканирование рекурсивное (docs/ + подкаталоги, напр. docs/mvp/).

Исключения (AGENTS.md):
  - банковская зона docs/bank/ — целиком вне графа (банк = не канон, каждая
    позиция с меткой аннулирования; реестр — docs/BANK.md);
  - архивные логи (ARCHIVE_LOGS) — освобождены от frontmatter и wikilink-графа,
    не редактируются; архивация — реестровый акт (DECISIONS.md + docs/CHANGELOG).

Запуск: python3 scripts/check_docs_links.py   (выход ≠ 0 при находках — для CI)
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCS = os.path.join(ROOT, "docs")

ALLOWED_STATUSES = {"canon", "deepened", "draft", "redirect", "reference", "archived"}

# Архивные логи: не редактируются, вне графа как источники (ссылки на них из живых
# доков остаются валидными), освобождены от frontmatter (AGENTS.md, D-106/D-109).
ARCHIVE_LOGS = {
    "STRUCTURE_AUDIT.md",
    "CONFLICTS_REPORT.md",
    "UNIFICATION_CHANGES.md",
    "NORMALIZATION_REPORT.md",
}

# Банковская зона: целиком исключена из чекера и гейтов (D-102).
BANK_DIR = os.path.join(DOCS, "bank")


def doc_files():
    """Все .md/.canvas в docs/ (рекурсивно), кроме банковской зоны."""
    files = []
    for dirpath, dirnames, names in os.walk(DOCS):
        if os.path.abspath(dirpath).startswith(os.path.abspath(BANK_DIR)):
            dirnames[:] = []
            continue
        for n in sorted(names):
            base, ext = os.path.splitext(n)
            if ext in {".md", ".canvas"}:
                files.append(os.path.join(dirpath, n))
    return files


def source_files(files):
    """Источники графа: все доки, кроме архивных логов (D-107: логи вне графа как источники)."""
    return [p for p in files if os.path.basename(p) not in ARCHIVE_LOGS]


def check_wikilinks(files, stems):
    broken = []
    link_re = re.compile(r"\[\[([^\]\|#]+)(?:#[^\]\|]*)?(?:\|[^\]]*)?\]\]")
    for path in files:
        name = os.path.basename(path)
        if not name.endswith(".md"):
            continue
        text = open(path, encoding="utf-8").read()
        body = re.sub(r"^---.*?---\n", "", text, count=1, flags=re.S)  # skip frontmatter
        body = re.sub(r"`[^`\n]*`", "", body)  # skip inline code (log examples)
        for m in link_re.finditer(body):
            target = m.group(1).strip()
            if target.endswith(".canvas"):
                continue  # canvas-файлы живут в docs/, Obsidian резолвит по имени
            if "/" in target:  # путевые ссылки запрещены (AGENTS.md: wikilinks без пути)
                broken.append((name, target))
            elif target not in stems:
                broken.append((name, target))
    return broken


def check_filenames(files):
    return [os.path.relpath(p, DOCS) for p in files if re.search(r"[А-Яа-яЁё]", os.path.basename(p))]


def check_races_table():
    """Инварианты каталога 54 (02e3 §9.4, A6-R/D-136):
    Σ групп = 54; каждая раса ровно в одной группе; первый эшелон (★) = 7 и покрывает 7 групп;
    нежить-трио (дампиры, перерождённые, одержимые гексом) отсутствует в каталоге."""
    path = os.path.join(DOCS, "02e3-races.md")
    if not os.path.exists(path):
        return []
    text = open(path, encoding="utf-8").read()
    m = re.search(r"^## 9\.4\..*?(?=^## )", text, re.S | re.M)
    if not m:
        return [("02e3-races.md", "секция 9.4 не найдена")]
    section = m.group(0)
    races, stars, errors = {}, [], []
    declared_total = 0
    for line in section.splitlines():
        if not line.startswith("|") or line.startswith("|---") or "Группа" in line and "Состав" in line:
            continue
        cells = [c.strip() for c in line.strip("|").split("|")]
        if len(cells) < 3:
            continue
        gm = re.search(r"\((\d+)\)", cells[0])
        if not gm:
            continue  # не строка группы
        declared_total += int(gm.group(1))
        group = cells[0]
        for token in cells[1].split(","):
            token = token.strip()
            if not token:
                continue
            is_star = token.endswith("★")
            name = token.replace("★", "").strip()
            if name in races:
                errors.append(("02e3-races.md", f"раса в двух группах: {name} ({races[name]} / {group})"))
            races[name] = group
            if is_star:
                stars.append((name, group))
    if len(races) != 54:
        errors.append(("02e3-races.md", f"Σ каталога = {len(races)}, ожидалось 54"))
    if declared_total != 54:
        errors.append(("02e3-races.md", f"сумма заявленных (N) = {declared_total}, ожидалось 54"))
    if len(stars) != 7 or len({g for _, g in stars}) != 7:
        errors.append(("02e3-races.md", f"первый эшелон: {len(stars)} ★ в {len({g for _, g in stars})} группах, ожидалось 7×7"))
    for undead in ("дампиры", "перерождённые", "одержимые гексом"):
        if undead in races:
            errors.append(("02e3-races.md", f"нежить в каталоге живого города: {undead} (принцип 3, A6-R)"))
    return errors


def check_statuses(files):
    bad = []
    for path in files:
        name = os.path.basename(path)
        if not name.endswith(".md") or name in ARCHIVE_LOGS:
            continue
        text = open(path, encoding="utf-8").read()
        m = re.match(r"^---\n(.*?)\n---", text, re.S)
        if not m:
            continue
        s = re.search(r"^status:\s*(.+)$", m.group(1), re.M)
        if s and s.group(1).strip() not in ALLOWED_STATUSES:
            bad.append((name, s.group(1).strip()))
    return bad


def main():
    files = doc_files()
    sources = source_files(files)
    stems = {os.path.splitext(os.path.basename(p))[0] for p in files}
    failed = False

    broken = check_wikilinks(sources, stems)
    if broken:
        failed = True
        print("BROKEN WIKILINKS:")
        for f, t in broken:
            print(f"  {f}: [[{t}]]")

    cyr = check_filenames(files)
    if cyr:
        failed = True
        print("CYRILLIC FILENAMES (policy: latin only):")
        for n in cyr:
            print(f"  docs/{n}")

    statuses = check_statuses(files)
    if statuses:
        failed = True
        print("UNKNOWN FRONTMATTER STATUS:")
        for f, s in statuses:
            print(f"  {f}: status: {s} (allowed: {', '.join(sorted(ALLOWED_STATUSES))})")

    races = check_races_table()
    if races:
        failed = True
        print("RACES TABLE INVARIANTS (02e3 §9.4, A6-R):")
        for f, msg in races:
            print(f"  {f}: {msg}")

    if failed:
        sys.exit(1)
    print(f"OK: docs/ links consistent ({len(sources)} notes checked)")


if __name__ == "__main__":
    main()

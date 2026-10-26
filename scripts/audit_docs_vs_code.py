#!/usr/bin/env python3
"""Сверка документации с кодом игры (change docs-code-sync).

Документы утверждают, что в игре есть автозагрузки, сцены, классы, действия ввода
и поля сейва. Этот скрипт читает факты из кода (project.godot, .tscn, .gd, схема
сейва) и проверяет каждое такое утверждение из docs/. Вывод — расхождения, а не
впечатления: «док ссылается на X, которого в коде нет» и «в коде есть X, о котором
не говорит ни один документ».

Выход: 0 — расхождений нет; 1 — есть (гейт шага 4 change docs-code-sync).
Запуск из корня репо: python3 scripts/audit_docs_vs_code.py [--json]
"""
from __future__ import annotations

import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
GAME = ROOT / "game"
DOCS = ROOT / "docs"
PROJECT = GAME / "project.godot"

# Документированность проверяется только по «живым» заметкам: архивные логи и
# банк канона (docs/bank) намеренно выведены из графа (AGENTS.md «Документация»).
SKIP_DOC_PARTS = {"bank"}
SKIP_DOC_NAMES = {"STRUCTURE_AUDIT", "CONFLICTS_REPORT", "UNIFICATION_CHANGES", "NORMALIZATION_REPORT"}


def _doc_texts() -> list[tuple[pathlib.Path, str]]:
    out = []
    for p in sorted(DOCS.rglob("*.md")):
        if SKIP_DOC_PARTS & set(p.relative_to(DOCS).parts):
            continue
        if any(n in p.name.upper() for n in SKIP_DOC_NAMES):
            continue
        out.append((p, p.read_text(encoding="utf-8", errors="replace")))
    return out


def _section(text: str, name: str) -> list[str]:
    """Значения ключей секции config_file (project.godot), построчно."""
    lines = text.splitlines()
    try:
        start = lines.index(f"[{name}]")
    except ValueError:
        return []
    keys = []
    for line in lines[start + 1 :]:
        if line.startswith("["):
            break
        m = re.match(r"^([A-Za-z0-9_/]+)\s*=", line)
        if m:
            keys.append(m.group(1))
    return keys


def autoloads() -> list[str]:
    return _section(PROJECT.read_text(encoding="utf-8"), "autoload")


def input_actions() -> list[str]:
    keys = _section(PROJECT.read_text(encoding="utf-8"), "input")
    return [k.split("/")[-1] for k in keys]


def scenes() -> list[str]:
    return sorted(p.name for p in (GAME / "scenes").rglob("*.tscn"))


def game_scripts() -> list[pathlib.Path]:
    """Только код игры: вендорные аддоны (GdUnit4, godot-mcp) — не предмет доков."""
    return [p for p in GAME.rglob("*.gd") if "addons" not in p.parts]


def class_names() -> list[str]:
    out = set()
    for p in game_scripts():
        m = re.search(r"^class_name\s+([A-Za-z0-9_]+)", p.read_text(encoding="utf-8", errors="replace"), re.M)
        if m:
            out.add(m.group(1))
    return sorted(out)


def save_keys() -> list[str]:
    """Верхнеуровневые ключи сейва: schema-файл объявляет их литералами."""
    f = GAME / "scripts" / "campaign" / "save" / "mvp_save_schema.gd"
    if not f.exists():
        return []
    s = f.read_text(encoding="utf-8", errors="replace")
    return sorted(set(re.findall(r"\"([a-z_]{3,})\"\s*:", s)))


def main() -> int:
    docs = _doc_texts()
    blob = "\n".join(t for _, t in docs)
    facts = {
        "autoload": autoloads(),
        "input_action": input_actions(),
        "scene": scenes(),
        "class_name": class_names(),
        "save_key": save_keys(),
    }
    missing_in_code: list[dict] = []
    undocumented: list[dict] = []
    for kind, names in facts.items():
        for n in names:
            # Имя сцены в доках пишут и с расширением, и без; класс — как есть.
            pat = re.compile(rf"\b{re.escape(n)}\b" + (r"(\.tscn)?" if kind == "scene" else ""))
            hit = any(pat.search(t) for _, t in docs)
            if not hit:
                undocumented.append({"kind": kind, "name": n})
    # Обратная сторона: на что доки ссылаются как на код игры.
    ref_re = re.compile(r"\b([A-Z][A-Za-z0-9_]{3,})\b")
    # Вендор (addons/) — не предмет доков игры, но и не битая ссылка: путь существует.
    vendor = set()
    for p in (GAME / "addons").rglob("*.gd"):
        m = re.search(r"^class_name\s+([A-Za-z0-9_]+)", p.read_text(encoding="utf-8", errors="replace"), re.M)
        if m:
            vendor.add(m.group(1))
    known = set(facts["class_name"]) | set(facts["autoload"]) | vendor
    for p, t in docs:
        for name in sorted(set(ref_re.findall(t))):
            if name in known or name.isupper():
                continue
            # Ссылка на класс-стиль, которого нет ни в class_name, ни в автолоадах.
            if any(re.search(rf"\bclass_name\s+{re.escape(name)}\b", f.read_text(encoding="utf-8", errors="replace"))
                   for f in game_scripts()):
                continue
            if re.search(rf"\b{re.escape(name)}\.(?:gd|tscn)\b", t):
                missing_in_code.append({"kind": "doc_ref", "name": name, "doc": str(p.relative_to(ROOT))})
    result = {
        "facts": {k: len(v) for k, v in facts.items()},
        "undocumented": undocumented,
        "doc_refs_absent_in_code": missing_in_code,
    }
    if "--json" in sys.argv:
        print(json.dumps(result, ensure_ascii=False, indent=1))
    else:
        print("факты кода:", ", ".join(f"{k}={v}" for k, v in result["facts"].items()))
        print(f"\nЕСТЬ В КОДЕ, НЕ УПОМИНАЕТСЯ В ДОКАХ ({len(undocumented)}):")
        for row in undocumented:
            print(f"  [{row['kind']}] {row['name']}")
        print(f"\nДОК ССЫЛАЕТСЯ, В КОДЕ НЕТ ({len(missing_in_code)}):")
        for row in missing_in_code[:40]:
            print(f"  [{row['kind']}] {row['name']} -> {row['doc']}")
    return 1 if (undocumented or missing_in_code) else 0


if __name__ == "__main__":
    sys.exit(main())

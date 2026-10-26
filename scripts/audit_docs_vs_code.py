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
def project_path() -> pathlib.Path:
    """project.godot текущего дерева (функция — чтобы тесты подменяли GAME)."""
    return GAME / "project.godot"

# Документированность проверяется только по «живым» заметкам: архивные логи и
# банк канона (docs/bank) намеренно выведены из графа (AGENTS.md «Документация»).
SKIP_DOC_PARTS = {"bank"}
# Реестры/журналы: append-only история, имена файлов в них — цитаты прошлого.
REGISTRY_PREFIXES = (
    "docs/CHANGELOG.md",
    "docs/DECISIONS.md",
    "docs/QUESTIONS.md",
    "docs/mvp/",
)
# Формулировки, при которых имя файла — сознательное «этого больше нет».
ABSENCE_MARKERS = (
    "в репо нет", "нет в репо", "не существует", "отсутству", "удален", "удалён",
    "снята", "снято", "больше не", "пре-D1", "историч", "ранее", " formerly",
    "не instantiated", "артефакт аудита",
)

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


def _allowlist() -> set[str]:
    """Ratchet-бэклог: имена классов, ещё не названных в доках. Список может
    только сокращаться — задокументированное имя, оставленное здесь, краснит
    гейт (иначе allowlist превращается в свалку)."""
    f = pathlib.Path(__file__).with_suffix(".allowlist")
    if not f.exists():
        return set()
    return {ln.strip() for ln in f.read_text(encoding="utf-8").splitlines() if ln.strip() and not ln.startswith("#")}


def _facts() -> dict:
    return {
        "autoload": autoloads(),
        "input_action": input_actions(),
        "scene": scenes(),
        "class_name": class_names(),
        "save_key": save_keys(),
    }


def autoloads() -> list[str]:
    return _section(project_path().read_text(encoding="utf-8"), "autoload")


def input_actions() -> list[str]:
    keys = _section(project_path().read_text(encoding="utf-8"), "input")
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


def audit() -> dict:
    """Собрать расхождения. Отдельно от печати — чтобы поведение тестировалось."""
    docs = _doc_texts()
    facts = _facts()
    strict_kinds = {"autoload", "input_action", "scene", "save_key"}
    allowlist = _allowlist()
    undocumented: list[dict] = []
    stale: list[str] = []
    missing_in_code: list[dict] = []
    for kind, names in facts.items():
        for n in names:
            pat = re.compile(rf"\b{re.escape(n)}\b" + (r"(\.tscn)?" if kind == "scene" else ""))
            hit = any(pat.search(t) for _, t in docs)
            if kind not in strict_kinds and n in allowlist:
                if hit:
                    stale.append(n)
                continue
            if hit:
                continue
            undocumented.append({"kind": kind, "name": n})
    ref_re = re.compile(r"\b([A-Za-z_][A-Za-z0-9_]*\.(?:gd|tscn))\b")
    existing = {q.name for q in GAME.rglob("*.gd")} | {q.name for q in GAME.rglob("*.tscn")}
    for doc, t in docs:
        rel = str(doc.relative_to(ROOT))
        if rel.startswith(REGISTRY_PREFIXES):
            # Реестры и логи — исторические акты: они вправе называть файлы,
            # удалённые позже; переписать их под текущий код = фальсификация.
            continue
        for line in t.splitlines():
            if any(m in line for m in ABSENCE_MARKERS):
                # Док прямо говорит, что носителя нет, — это правда о настоящем.
                continue
            for ref in sorted(set(ref_re.findall(line))):
                if ref not in existing:
                    missing_in_code.append({"kind": "doc_ref", "name": ref, "doc": rel})
    return {
        "facts": {k: len(v) for k, v in facts.items()},
        "undocumented": undocumented,
        "allowlist_stale": sorted(set(stale)),
        "doc_refs_absent_in_code": missing_in_code,
    }


def main_for() -> int:
    """Вердикт + печать. 0 — расхождений нет, 1 — есть (change docs-code-sync)."""
    res = audit()
    und, missing, stale = res["undocumented"], res["doc_refs_absent_in_code"], res["allowlist_stale"]
    print("факты кода:", ", ".join(f"{k}={v}" for k, v in res["facts"].items()))
    print(f"\nЕСТЬ В КОДЕ, НЕ УПОМИНАЕТСЯ В ДОКАХ ({len(und)}):")
    for row in und:
        print(f"  [{row['kind']}] {row['name']}")
    print(f"\nДОК ССЫЛАЕТСЯ, ФАЙЛА НЕТ ({len(missing)}):")
    for row in missing[:40]:
        print(f"  [{row['kind']}] {row['name']} -> {row['doc']}")
    if stale:
        print(f"\nALLOWLIST УСТАРЕЛ, имена уже задокументированы, убери их ({len(stale)}):")
        for n in stale[:40]:
            print(f"  {n}")
    bad = bool(missing) or bool(stale) or bool(und)
    return 1 if bad else 0


def main() -> int:
    if "--json" in sys.argv:
        print(json.dumps(audit(), ensure_ascii=False, indent=1))
        return 0
    return main_for()


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Сверка `doc/SAVE_MATRIX.md` с деревом (T-301).

Зачем. Матрица покрытия сейвов — реестр ссылок: файл, тест, версия миграции,
секция схемы. Всё это гниёт молча: тест переименовали, секцию добавили, ссылку в
прошлой матрице просто потеряли вместе с файлом в `5f412a37`. Отдельно заметим:
`doc/` лежит вне `docs`-хранилища (адрес выбран спекой), поэтому ни
`check_docs_links.py`, ни `audit_docs_vs_code.py` его не видят — ни одна проверка
ссылок здесь не работала бы сама собой. Этот сверщик и есть та проверка;
`run`-строка в `scripts/doc_gates.sh` красит расхождение уровнем RED.

Правила (каждое печатает строку, молчание = RED по D-265-семейству):
  1. CJK в `doc/*.md` — смесь раскладки, а не текст (тот же класс, что и в `docs/`).
  2. каждый путь `game/…`, `scripts/…`, `doc/…` из реестра существует;
  3. каждое голое имя файла резолвится ровно в один файл дерева (иначе реестр
     ссылается на «test_save.gd», которого в репо три);
  4. каждая ссылка `файл.gd::test_имя` — функция с таким именем там есть;
  5. каждая миграция `save_data.gd` (`_migrate_vA_to_vB`) упомянута как `vA→vB`
     — новая миграция без строки матрицы красная, это и есть правило T-301;
  6. каждая секция `MvpSaveSchema.SECTIONS` и каждый ключ `DERIVED_KEYS` названы
     в реестре — схема сейва не имеет права уезжать вперёд матрицы;
  7. в реестре живёт само правило («строка добавляется вместе с миграцией»).

Выход: 0 — расхождений нет; 1 — есть. Запуск из корня репо:
    python3 scripts/check_save_matrix.py
"""
from __future__ import annotations

import os
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
DOC = ROOT / "doc" / "SAVE_MATRIX.md"
DOC_DIR = ROOT / "doc"
SCHEMA = ROOT / "game" / "scripts" / "campaign" / "save" / "mvp_save_schema.gd"
SAVE_DATA = ROOT / "game" / "scripts" / "core" / "save_data.gd"
SEARCH_ROOTS = [ROOT / "game", ROOT / "scripts", DOC_DIR]

CJK_RE = re.compile(
    r"[\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff\uac00-\ud7af\u31f0-\u31ff]"
)
BACKTICK_RE = re.compile(r"`([^`\n]+)`")
PATH_RE = re.compile(r"^(?:game|scripts|doc|openspec)/\S*$")
# Голые имена файлов, в том числе с адресом строки: `population_system.gd:245-246`.
BARE_RE = re.compile(
    r"^([A-Za-z0-9_\-]+\.(?:gd|py|tscn|tres|json|md))(?::\d+(?:-\d+)?)?$")
TEST_REF_RE = re.compile(r"`?([A-Za-z0-9_\-]+\.(?:gd|py))::(test_[A-Za-z0-9_]+)`?")
FILE_RE = re.compile(r"([A-Za-z0-9_\-]+\.(?:gd|py))(?:::|:\d|\b)")
TEST_NAME_RE = re.compile(r"`(test_[A-Za-z0-9_]+)`")
MIGRATION_RE = re.compile(r"_migrate_v(\d+)_to_v(\d+)")
RULE_SENTENCE = "строка добавляется вместе с миграцией"


def backticked(text: str) -> list[str]:
    return BACKTICK_RE.findall(text)


def cjk_hits(text: str) -> list[str]:
    hits = []
    for n, line in enumerate(text.splitlines(), start=1):
        hit = CJK_RE.search(line)
        if hit:
            hits.append(f"{n}: …{line[max(0, hit.start() - 20):hit.end() + 20]}…")
    return hits


def index_basenames() -> dict[str, list[pathlib.Path]]:
    """Имя файла → где он лежит (для голо-имённых ссылок реестра)."""
    idx: dict[str, list[pathlib.Path]] = {}
    for root in SEARCH_ROOTS:
        if not root.exists():
            continue
        for p in root.rglob("*"):
            if not p.is_file():
                continue
            if any(part in {".godot", "reports", "node_modules", "archive"}
                    for part in p.parts):
                continue
            idx.setdefault(p.name, []).append(p)
    return idx


def schema_constants() -> tuple[list[str], list[str]]:
    """(секции SECTIONS, ключи DERIVED_KEYS) из схемы кампейн-сейва."""
    text = SCHEMA.read_text(encoding="utf-8")
    sections: list[str] = []
    m = re.search(r"const SECTIONS := \{(.*?)\n\}", text, re.S)
    if m:
        sections = re.findall(r'"([a-z_]+)":\s*TYPE_', m.group(1))
    derived: list[str] = []
    m = re.search(r"const DERIVED_KEYS: Array\[String\] = \[(.*?)\]", text, re.S)
    if m:
        derived = re.findall(r'"([a-z_]+)"', m.group(1))
    return sections, derived


def migrations() -> list[str]:
    """Цепочка миграций `SaveData` без дублей (каждая встречается дважды:
    вызов в `from_dict` и определение — правило это одно и то же)."""
    text = SAVE_DATA.read_text(encoding="utf-8")
    seen: dict[str, None] = {}
    for a, b in MIGRATION_RE.findall(text):
        seen.setdefault(f"v{a}→v{b}", None)
    return list(seen)


def check(doc_text: str, idx: dict[str, list[pathlib.Path]],
          doc_dir: pathlib.Path = DOC_DIR) -> dict[str, list[str]]:
    """Правило → список расхождений. Пустой список = правило зелёное."""
    out: dict[str, list[str]] = {}
    tokens = backticked(doc_text)

    out["cjk"] = []
    for f in sorted(doc_dir.glob("*.md")):
        out["cjk"] += [f"{os.path.relpath(f, ROOT)}:{h}" for h in cjk_hits(
            f.read_text(encoding="utf-8"))]

    out["пути"] = [t for t in tokens
                   if PATH_RE.match(t) and not (ROOT / t.split(":")[0]).exists()]
    out["голые имена"] = []
    for t in tokens:
        m = BARE_RE.match(t)
        if not m:
            continue
        t = m.group(1)
        found = idx.get(t, [])
        if not found:
            out["голые имена"].append(f"{t}: файла нет в дереве")
        elif len(found) > 1:
            where = ", ".join(os.path.relpath(p, ROOT) for p in found)
            out["голые имена"].append(f"{t}: имя неоднозначно ({where}) — зовите по пути")
    out["тесты"] = []
    cache: dict[str, str] = {}

    def has_func(file: pathlib.Path, test: str) -> bool:
        body = cache.get(str(file))
        if body is None:
            body = file.read_text(encoding="utf-8")
            cache[str(file)] = body
        return re.search(rf"^func {test}\b", body, re.M) is not None

    for fname, test in TEST_REF_RE.findall(doc_text):
        found = idx.get(fname, [])
        if len(found) != 1:
            continue  # уже сообщено правилом «голые имена»
        if not has_func(found[0], test):
            out["тесты"].append(f"{fname}::{test} — такой функции в файле нет")

    # Голые имена кейсов в той же строке таблицы, что и файл-носитель: реестр
    # пишет `test_foo.gd::test_a`, `test_b` — и `test_b` гниёт незаметно, если
    # его не проверять. Правило требует, чтобы имя жило в одном из файлов строки.
    for row in doc_text.splitlines():
        if not row.lstrip().startswith("|"):
            continue
        files = [f for f in FILE_RE.findall(row) if len(idx.get(f, [])) == 1]
        if not files:
            continue
        for test in set(TEST_NAME_RE.findall(row)):
            if not any(has_func(idx[f][0], test) for f in files):
                out["тесты"].append(
                    f"{test} — кейс не найден ни в одном файле строки "
                    f"({', '.join(sorted(set(files)))})")
    sections, derived = schema_constants()
    out["миграции"] = [m for m in migrations() if m not in doc_text]
    # Секция считается названной, если она упомянута целиком (`city`) или через
    # под-ключ (`city.housing`): строки матрицы сгруппированы по под-ключам.
    out["секции схемы"] = [s for s in sections
                       if f"`{s}`" not in doc_text and f"`{s}." not in doc_text]
    out["derived-ключи"] = [k for k in derived if f"`{k}`" not in doc_text]
    out["правило реестра"] = [] if RULE_SENTENCE in doc_text else [
        "в реестре нет самого правила T-301 («" + RULE_SENTENCE + "»)"]
    return out


def main() -> int:
    if not DOC.exists():
        print(f"RED: реестра нет на месте: {DOC.relative_to(ROOT)}")
        return 1
    doc_text = DOC.read_text(encoding="utf-8")
    problems = check(doc_text, index_basenames())
    failed = False
    for rule, hits in problems.items():
        if hits:
            failed = True
            print(f"RED [{rule}]:")
            for h in hits:
                print(f"  - {h}")
        else:
            print(f"OK [{rule}]")
    if failed:
        print("\nSAVE MATRIX: RED — реестр расходится с деревом (T-301)")
        return 1
    print("\nSAVE MATRIX: GREEN — ссылки, версии и секции сверены с деревом")
    return 0


if __name__ == "__main__":
    sys.exit(main())

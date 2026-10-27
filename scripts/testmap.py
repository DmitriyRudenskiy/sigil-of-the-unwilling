#!/usr/bin/env python3
"""Карта тестового набора: покрытие меньшим количеством тестов (T-227).

Зачем. Комплект вырос до сотен файлов; боль не в времени прогона (весь GdUnit —
порядка 3 минут), а в том, что число файлов растёт быстрее, чем число проверенных
носителей: новый тикет заводит новый файл, а старый никто не сводит с новым. Чтобы
сжимать набор честно, нужны три числа, а не ощущение:

  1. **покрытие** — сколько production-`.gd` назван хотя бы одним тестом (дыра =
     носитель, о котором тесты молчат);
  2. **слияния** — сколько тест-файлов спорят об одном носителе (кандидаты в один
     файл/таблицу), приписывание по имени носителя, а не по «самому частому импорту»:
     `hex_utils` всплывает в каждом тесте и не делает файл своим;
  3. **дубли** — тест-функции с совпадающими нормализованными телами ПО РАЗНЫМ
     файлам (один и тот же сценарий, проверенный дважды).

Дыры считаются со служебным исключением (`EXCLUDED_PREFIXES`): генераторы ассетов
(`scripts/build/`), корень композиции (`main/main.gd`) и демо-экран кита не имеют
носителя, который можно «покрыть» тестом, — их молчание не дефект, и считать его
дырой значит вечный красный отчёт.

Запуск: `python3 scripts/testmap.py [--json] [--top N]` (из корня репо).
"""
from __future__ import annotations

import argparse
import collections
import hashlib
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
GAME = ROOT / "game"
SCRIPTS = GAME / "scripts"
TESTS = GAME / "tests"

# Носители без теста по конструкции (см. докстринг).
EXCLUDED_PREFIXES = (
    "scripts/build/",                 # генераторы ассетов: запуск руками, не рантайм
    "scripts/main/main.gd",        # корень композиции: покрывается функциональными прогонами сцен
    "scripts/ui/kitchen_sink",     # демо-экран кита
    "scripts/ui/mcp_canvas_draw_node",  # инструментальная нода MCP-харнеса (tools/mcp/)
)

_FUNC_RE = re.compile(r"^func\s+(test_\w+)\s*\(", re.M)
_CLASS_RE = re.compile(r"^class_name\s+(\w+)", re.M)
_COMMENT_RE = re.compile(r"#.*")


def _read(p: pathlib.Path) -> str:
    return p.read_text(encoding="utf-8", errors="ignore")


def test_files() -> list[pathlib.Path]:
    """Файлы с хотя бы одной тест-функцией (GdUnit берёт их из tests/ рекурсией)."""
    out = []
    for p in sorted(TESTS.rglob("*.gd")):
        if _FUNC_RE.search(_read(p)):
            out.append(p)
    return out


def py_test_files() -> list[pathlib.Path]:
    out = []
    for p in sorted((TESTS / "mcp").glob("*.py")) if (TESTS / "mcp").is_dir() else []:
        if re.search(r"^def test_", _read(p), re.M):
            out.append(p)
    return out


def production_files() -> list[pathlib.Path]:
    return sorted(p for p in SCRIPTS.rglob("*.gd"))


def is_excluded(p: pathlib.Path) -> bool:
    rel = p.relative_to(GAME).as_posix()
    return any(rel.startswith(x) for x in EXCLUDED_PREFIXES)


def _patterns(cname: str | None, stem: str) -> list[re.Pattern]:
    pats = [
        r"res://scripts/[\w/.]*" + re.escape(stem) + r"\.gd",
        r"res://scenes/[\w/.]*" + re.escape(stem) + r"\.tscn",
        r"res://[\w/.]*" + re.escape(stem) + r"\.(json|tres|csv)",
    ]
    if cname:
        pats.append(r"\b" + re.escape(cname) + r"\b")
    return [re.compile(x) for x in pats]


def coverage() -> dict:
    """Сколько production-носителей названы тестами; дыры считаются без исключений."""
    prods = production_files()
    pats = {}
    for p in prods:
        t = _read(p)
        m = _CLASS_RE.search(t)
        pats[p] = _patterns(m.group(1) if m else None, p.stem)
    corpus = "\n".join(_read(p) for p in TESTS.rglob("*.gd"))
    corpus += "\n".join(_read(p) for p in TESTS.rglob("*.py"))
    holes, covered = [], 0
    for p in prods:
        if any(rx.search(corpus) for rx in pats[p]):
            covered += 1
        elif not is_excluded(p):
            holes.append(p.relative_to(GAME).as_posix())
    scored = [p for p in prods if not is_excluded(p)]
    return {
        "production_files": len(scored),
        "covered": covered,
        "holes": sorted(holes, key=lambda r: -_read(GAME / r).count("\n")),
    }


def merges() -> list[tuple[str, list[str]]]:
    """Группы тест-файлов, приписанных одному носителю (по имени файла-носителя).

    Приписывание: носитель, чей stem встречается в имени тест-файла, либо (если такого
    нет) носитель с максимальным числом упоминаний при условии, что других кандидатов
    того же счёта нет. Иначе общий хелпер (`hex_utils`, `battle_state`) забирал бы
    себе чужие файлы, и «кандидаты на слияние» превращались бы в шум.
    """
    prods = production_files()
    pats = {}
    for p in prods:
        t = _read(p)
        m = _CLASS_RE.search(t)
        pats[p] = (m.group(1) if m else None, p.stem, _patterns(m.group(1) if m else None, p.stem))

    groups: dict[str, list[str]] = collections.defaultdict(list)
    for tp in test_files():
        text = _read(tp)
        stem = tp.stem
        # Самый специфичный носитель: самое длинное имя, вошедшее в имя теста
        # (test_city_serializer.gd — это city_serializer, а не city).
        named = [p for p in prods if p.stem and re.search(r"(?:^|_)" + re.escape(p.stem) + r"(?:_|$)", stem)]
        if named:
            target = max(named, key=lambda p: len(p.stem))
        else:
            scored = []
            for p in prods:
                c = sum(len(rx.findall(text)) for rx in pats[p][2])
                if c:
                    scored.append((c, p))
            if not scored:
                continue
            scored.sort(key=lambda x: -x[0])
            if len([1 for c, _ in scored if c == scored[0][0]]) != 1:
                continue  # ничей не выиграл однозначно
            target = scored[0][1]
        groups[target.relative_to(GAME).as_posix()].append(tp.name)
    return sorted(
        [(k, sorted(v)) for k, v in groups.items() if len(v) >= 3],
        key=lambda kv: (-len(kv[1]), kv[0]),
    )


def _norm(body: str) -> str:
    s = _COMMENT_RE.sub("", body)
    s = re.sub(r'"[^"]*"', "S", s)
    # Числа — да; точки в System.new() — нет: иначе нормализация съедала бы
    # различия между телами и роняла их ниже порога длины.
    s = re.sub(r"(?<![\w.])[\d.]+(?![\w.])", "N", s)
    return re.sub(r"\s+", " ", s).strip()


def _test_bodies(text: str):
    """(имя, тело) каждой `func test_`. Тело — строки с табуляцией, пустые строки
    внутри тоже: обрезка по пустой строке оставляла от тела только префикс-фикстуру,
    и общий префикс двух разных сценариев выглядел дублем (замерено 2026-10-27)."""
    lines = text.split("\n")
    head = re.compile(r"^func\s+(test_\w+)\s*\(")
    for i, line in enumerate(lines):
        m = head.match(line)
        if not m:
            continue
        body = []
        for nxt in lines[i + 1:]:
            if nxt.startswith("\t") or not nxt.strip():
                body.append(nxt)
            else:
                break
        yield m.group(1), "\n".join(body)


def duplicates() -> list[list[str]]:
    """Тест-функции с совпадающими нормализованными телами в РАЗНЫХ файлах."""
    bodies = collections.defaultdict(list)
    for tp in test_files():
        for name, body in _test_bodies(_read(tp)):
            norm = _norm(body)
            if len(norm) < 60:
                continue  # тривиальное тело отличить от совпадения нельзя
            key = hashlib.md5(norm.encode()).hexdigest()[:8]
            bodies[key].append(f"{tp.relative_to(GAME)}::{name}")
    return sorted(
        [v for v in bodies.values() if len(v) > 1 and len({x.split("::")[0] for x in v}) > 1]
    )


def measure() -> dict:
    gd = test_files()
    py = py_test_files()
    return {
        "gd_files": len(gd),
        "gd_tests": sum(len(_FUNC_RE.findall(_read(p))) for p in gd),
        "py_files": len(py),
        "py_tests": sum(len(re.findall(r"^def test_", _read(p), re.M)) for p in py),
        "coverage": coverage(),
        "merge_groups": merges(),
        "duplicates": duplicates(),
    }


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", action="store_true", help="машинный вывод вместо отчёта")
    ap.add_argument("--top", type=int, default=12, help="сколько строк печатать в таблицах")
    ap.add_argument("--write-baseline", action="store_true",
                    help="зафиксировать метрики в scripts/testmap.baseline.json")
    a = ap.parse_args(argv)
    m = measure()
    if a.write_baseline:
        cov = m["coverage"]
        snap = {
            "gd_files": m["gd_files"], "gd_tests": m["gd_tests"],
            "py_files": m["py_files"], "py_tests": m["py_tests"],
            "holes": len(cov["holes"]), "merge_groups": len(m["merge_groups"]),
            "merge_files": sum(len(v) for _, v in m["merge_groups"]),
            "duplicate_groups": len(m["duplicates"]),
        }
        (ROOT / "scripts" / "testmap.baseline.json").write_text(
            json.dumps(snap, indent=1, ensure_ascii=False, sort_keys=True) + "\n", encoding="utf-8")
        print("базлайн записан:", json.dumps(snap, ensure_ascii=False, sort_keys=True))
        return 0
    if a.json:
        print(json.dumps(m, ensure_ascii=False, indent=1))
        return 0
    cov = m["coverage"]
    pct = 100 * cov["covered"] // max(cov["production_files"], 1)
    print(f"тест-файлов .gd: {m['gd_files']}, тест-функций: {m['gd_tests']}")
    print(f"pytest (mcp):    файлов {m['py_files']}, функций {m['py_tests']}")
    print(f"носителей (без служебных): {cov['production_files']}, покрыто: "
          f"{cov['covered']} ({pct}%), дыр: {len(cov['holes'])}")
    print(f"групп слияния (≥3 файла на носителе): {len(m['merge_groups'])}, "
          f"файлов в них: {sum(len(v) for _, v in m['merge_groups'])}")
    print(f"групп межфайловых дублей тел: {len(m['duplicates'])}")
    if not a.top:
        return 0
    print("\nдыры (крупнейшие):")
    for h in cov["holes"][: a.top]:
        print(f"  {_read(GAME / h).count(chr(10)):5}  {h}")
    print("\nкандидаты в слияние:")
    for k, v in m["merge_groups"][: a.top]:
        print(f"  {len(v):3} файла → {k}")
        for name in v:
            print(f"          {name}")
    print("\nдубли тел (разные файлы):")
    for g in m["duplicates"][: a.top]:
        print("  " + " = ".join(g))
    return 0


if __name__ == "__main__":
    sys.exit(main())

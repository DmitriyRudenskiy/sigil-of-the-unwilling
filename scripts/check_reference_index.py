#!/usr/bin/env python3
"""Проверка карты reference/INDEX.md с диском.

Карта референсов стиля — единственный реестр канонического комплекта, а пиксели
в git не входят (`reference/*` + `!reference/INDEX.md`). Значит согласованность
«карта ↔ диск» нельзя проверить по git-индексу — только по факту на диске.

Ищется:
  1. дубли канонических имён в карте;
  2. строка карты без файла на диске;
  3. файл в reference/ без строки карты;
  4. статус вне словаря этой же карты (секция «Статусы»);
  5. md5 в строке не совпадает с md5 файла (дрейф пикселя);
  6. пустое поле провенанса у строки (право/происхождение обязаны быть названы).

Запуск: python3 scripts/check_reference_index.py   (выход ≠ 0 при находках)

В scripts/ci2_checkers.sh НЕ добавляется намеренно: CI-2 работает по git-индексу,
а пикселей комплекта там нет — чекер был бы вечно зелёным (тот же класс
соображения, что вынес addons/ и openspec/ из CI-шага про .import). Запускается
локально рядом с check_docs_links.py (D-185).
"""
import hashlib
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REF = os.path.join(ROOT, "reference")
INDEX = os.path.join(REF, "INDEX.md")

STATUSES = set()  # заполняется из словаря карты в main()

MD5_RE = re.compile(r"\b[0-9a-f]{32}\b")
NUM_RE = re.compile(r"^\d{2}$")


def cells(line):
    """Разобрать markdown-строку таблицы; None если это не строка таблицы."""
    line = line.strip()
    if not line.startswith("|"):
        return None
    parts = [c.strip() for c in line.strip("|").split("|")]
    if parts and all(set(c) <= set("-: ") for c in parts):
        return None  # разделитель |---|---|
    return parts


def read_lines(path):
    with open(path, encoding="utf-8") as fh:
        return fh.read().splitlines()


def parse_statuses(lines):
    """Словарь статусов из секции «## Статусы» — он же единственный легальный."""
    statuses, inside = set(), False
    for line in lines:
        if line.startswith("## "):
            inside = line.strip() == "## Статусы"
            continue
        if not inside:
            continue
        c = cells(line)
        if c and c[0].startswith("**"):
            name = c[0].strip("* ").strip()
            if name and name != "Статус":
                statuses.add(name)
    return statuses


def parse_rows(lines):
    """Строки комплекта: первая ячейка — номер NN, вторая — имя файла в бэктиках."""
    rows = []
    for no, line in enumerate(lines, 1):
        c = cells(line)
        if not c or len(c) < 4 or not NUM_RE.match(c[0]):
            continue
        m = re.fullmatch(r"`([^`]+)`", c[1])
        if not m:
            continue
        name = m.group(1)
        md5 = next((x for cell in c for x in MD5_RE.findall(cell)), None)
        status = next((x.strip("* ") for x in c if x.strip("* ") in STATUSES), None)
        rows.append({"line": no, "name": name, "md5": md5, "status": status,
                     "provenance": c[-1]})
    return rows


def md5_of(path):
    h = hashlib.md5()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def main():
    global STATUSES
    if not os.path.isfile(INDEX):
        print(f"MISSING: {INDEX}")
        sys.exit(1)

    lines = read_lines(INDEX)
    STATUSES = parse_statuses(lines)
    if not STATUSES:
        print("BROKEN MAP: секция «## Статусы» не найдена — словарь легальных статусов пуст")
        sys.exit(1)

    rows = parse_rows(lines)
    problems = []

    seen = {}
    for r in rows:
        if r["name"] in seen:
            problems.append(f"DUPLICATE NAME: {r['name']} (строки {seen[r['name']]} и {r['line']})")
        else:
            seen[r["name"]] = r["line"]

        if not os.path.isfile(os.path.join(REF, r["name"])):
            problems.append(f"ROW WITHOUT FILE: {r['name']} (строка {r['line']})")

        if r["md5"] is None:
            problems.append(f"NO MD5 IN ROW: {r['name']} (строка {r['line']})")
        elif os.path.isfile(os.path.join(REF, r["name"])):
            actual = md5_of(os.path.join(REF, r["name"]))
            if actual != r["md5"]:
                problems.append(f"MD5 DRIFT: {r['name']} — карте {r['md5']}, файлу {actual}")

        if r["status"] is None:
            problems.append(f"STATUS OUT OF DICTIONARY: {r['name']} (строка {r['line']}); "
                            f"словарь: {', '.join(sorted(STATUSES))}")

        if not r["provenance"] or r["provenance"] in {"—", "-"}:
            problems.append(f"EMPTY PROVENANCE: {r['name']} (строка {r['line']})")

    on_disk = {n for n in os.listdir(REF) if n != os.path.basename(INDEX)}
    for name in sorted(on_disk - set(seen)):
        problems.append(f"FILE WITHOUT ROW: {name}")
    for name in sorted(set(seen) - on_disk):
        if os.path.isfile(os.path.join(REF, name)):
            problems.append(f"FILE NOT LISTED IN DIRECTORY SCAN: {name}")

    if problems:
        print(f"REFERENCE INDEX PROBLEMS ({len(problems)}):")
        for p in problems:
            print(f"  {p}")
        sys.exit(1)

    print(f"OK: reference/INDEX.md ↔ диск согласованы ({len(rows)} файлов комплекта)")


if __name__ == "__main__":
    main()

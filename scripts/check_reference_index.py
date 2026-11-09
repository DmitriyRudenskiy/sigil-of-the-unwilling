#!/usr/bin/env python3
"""Проверка карты референсов стиля с диском комплекта.

Карта — `docs/style-reference-index.md`, единственный реестр канонического комплекта.
Пиксели комплекта живут **вне рабочего дерева** (`SIGIL_REFERENCE_DIR`, по умолчанию
`~/sigil-reference`) и в git не входят. Значит согласованность «карта ↔ диск» нельзя
проверить по git-индексу — только по факту на диске, и только там, где комплект есть.

Ищется:
  1. дубли канонических имён в карте;
  2. строка карты без файла на диске — с различением: **заявленная утрата** (статус
     `утрачен`, инцидент 2026-10-17, D-193) печатается как `LOST (declared)`, случайная
     пропажа — как `ROW WITHOUT FILE`; и то и другое остаётся падением (выход 1):
     заявленная утрата — измеряемый долг, а не «зелёный» фон (условие владельца 2026-10-17:
     обходного правила «в зелёный» не вводится);
  3. файл в каталоге комплекта без строки карты;
  4. статус вне словаря этой же карты (секция «Статусы»);
  5. md5 в строке не совпадает с md5 файла (дрейф пикселя);
  6. пустое поле провенанса у строки (право/происхождение обязаны быть названы);
  7. противоречие «статус `утрачен`, но файл на месте» (носитель вернулся без правки карты).

Статус **`вытеснен`** (комплект заменён новым, D-203) — отсутствующий файл НЕ находка:
строка остаётся как мера состава, повторная передача не требуется. Присутствующий файл
всё равно сверяется по md5.

Каталог комплекта: `SIGIL_REFERENCE_DIR`, значение по умолчанию `$HOME/sigil-reference`.
Машине владельца задавать его не нужно — дефолт и есть её каталог.

Запуск: python3 scripts/check_reference_index.py

Коды возврата: **0** — карта и диск согласованы; **1** — расхождение против карты
(единственная сигнализация о дрейфе эталона); **2** — `CANON DIR ABSENT`, комплекта на
этой машине нет целиком. 2 отделён от 1 намеренно: отсутствие эталона на машине — это
факт про машину, а не дрейф; и отделён от 0, чтобы случайная потеря каталога не
выглядела «всё хорошо».

В scripts/ci2_checkers.sh НЕ добавляется намеренно: CI-2 работает по git-индексу,
а пикселей комплекта там нет — чекер был бы вечно зелёным (тот же класс
соображения, что вынес addons/ и openspec/ из CI-шага про .import). Запускается
локально (D-185).
"""
import hashlib
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INDEX = os.path.join(ROOT, "docs", "style-reference-index.md")
REF = os.environ.get("SIGIL_REFERENCE_DIR") or os.path.join(
    os.path.expanduser("~"), "sigil-reference")

STATUSES = set()  # заполняется из словаря карты в main()

MD5_RE = re.compile(r"\b[0-9a-f]{32}\b")
NUM_RE = re.compile(r"^\d{2}$")
PATH_RE = re.compile(r"`([^`]+/[^`]+)`")

# Статус «носитель утрачен, строка карты остаётся» (инцидент 2026-10-17, D-193).
LOST_STATUS = "утрачен"

# Статус «комплект вытеснён новым» (D-203, 2026-10-18): строка остаётся как мера состава
# и истории, файл не требуется и ничего не должен — в отличие от «утрачен», где файл
# ДОЛЖЕН вернуться. Если файл всё же на диске, md5 по-прежнему сверяется (дрейф пикселя
# остаётся находкой). Обходного правила «в зелёный» не появляется: зелёным становится
# только то, что перестало быть долгом по решению владельца, а не то, что разошлось.
SUPERSEDED_STATUS = "вытеснен"


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
        # Носитель строки: по умолчанию — файл комплекта в REF; строка может объявить
        # репозиторный носитель **тем же именем** (так живут `battle_*.png`, которые
        # читаются игрой и потому лежат в git). Путь берётся из самой строки карты,
        # чтобы в чекере не заводилось второго источника истины о составе.
        carrier = next((os.path.join(ROOT, p) for cell in c for p in PATH_RE.findall(cell)
                        if os.path.basename(p) == name
                        and os.path.isfile(os.path.join(ROOT, p))), None)
        md5 = next((x for cell in c for x in MD5_RE.findall(cell)), None)
        status = next((x.strip("* ") for x in c if x.strip("* ") in STATUSES), None)
        rows.append({"line": no, "name": name, "md5": md5, "status": status,
                     "carrier": carrier, "provenance": c[-1]})
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
    if not os.path.isdir(REF):
        print(f"CANON DIR ABSENT ({REF}) — комплект референсов на этой машине отсутствует; "
              f"задай каталог переменной SIGIL_REFERENCE_DIR. Это не дрейф карты.")
        sys.exit(2)

    lines = read_lines(INDEX)
    STATUSES = parse_statuses(lines)
    if not STATUSES:
        print("BROKEN MAP: секция «## Статусы» не найдена — словарь легальных статусов пуст")
        sys.exit(1)

    rows = parse_rows(lines)
    problems = []
    declared_lost = []
    superseded_missing = []

    seen = {}
    for r in rows:
        if r["name"] in seen:
            problems.append(f"DUPLICATE NAME: {r['name']} (строки {seen[r['name']]} и {r['line']})")
        else:
            seen[r["name"]] = r["line"]

        present = os.path.isfile(r["carrier"] or os.path.join(REF, r["name"]))
        path = r["carrier"] or os.path.join(REF, r["name"])
        if not present:
            if r["status"] == SUPERSEDED_STATUS:
                superseded_missing.append(r["name"])
            elif r["status"] == LOST_STATUS:
                declared_lost.append(r["name"])
                problems.append(
                    f"LOST (declared): {r['name']} (строка {r['line']}) — носитель утрачен "
                    f"2026-10-17 (D-193), ждёт повторной передачи владельцем")
            else:
                problems.append(f"ROW WITHOUT FILE: {r['name']} (строка {r['line']})")

        if r["md5"] is None:
            problems.append(f"NO MD5 IN ROW: {r['name']} (строка {r['line']})")
        elif os.path.isfile(path):
            actual = md5_of(path)
            if actual != r["md5"]:
                problems.append(f"MD5 DRIFT: {r['name']} — карте {r['md5']}, файлу {actual}")

        if r["status"] is None:
            problems.append(f"STATUS OUT OF DICTIONARY: {r['name']} (строка {r['line']}); "
                            f"словарь: {', '.join(sorted(STATUSES))}")
        elif present and r["status"] == LOST_STATUS:
            problems.append(f"LOST STATUS BUT FILE PRESENT: {r['name']} (строка {r['line']}) — "
                            f"носитель на месте, сними статус «{LOST_STATUS}» и сверь md5")

        if not r["provenance"] or r["provenance"] in {"—", "-"}:
            problems.append(f"EMPTY PROVENANCE: {r['name']} (строка {r['line']})")

    on_disk = set(os.listdir(REF))  # карта больше не лежит рядом с пикселями
    for name in sorted(on_disk - set(seen)):
        problems.append(f"FILE WITHOUT ROW: {name}")
    for name in sorted(set(seen) - on_disk):
        if os.path.isfile(os.path.join(REF, name)):
            problems.append(f"FILE NOT LISTED IN DIRECTORY SCAN: {name}")

    if problems:
        print(f"REFERENCE INDEX PROBLEMS ({len(problems)}):")
        for p in problems:
            print(f"  {p}")
        if declared_lost:
            print(f"  — из них заявлено утраченными (статус «{LOST_STATUS}», D-193): "
                  f"{len(declared_lost)}; неожиданных расхождений: "
                  f"{len(problems) - len(declared_lost)}")
        sys.exit(1)

    print(f"OK: docs/style-reference-index.md ↔ {REF} согласованы ({len(rows)} файлов комплекта)")
    if superseded_missing:
        print(f"  справочно: стр со статусом «{SUPERSEDED_STATUS}» без файла на диске — "
              f"{len(superseded_missing)} (D-203: вытесненный комплект ничего не должен)")


if __name__ == "__main__":
    main()

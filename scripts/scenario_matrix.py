#!/usr/bin/env python3
"""Драйвер матрицы «роль × класс» — носитель T-238 (спек `scenario-matrix`).

Зачем. Прогон матрицы был ручным: оператор сам запускал `game/tools/matrix_report.gd`
по одному процессу на роль, сам читал 55 строк и сам переносил цифры в tasks.md.
Инструмент обязано собрать то, что до него делалось глазами: список ячеек, полнота
отчёта, коды «нет строки» вместо молчаливой дырки, история прогонов и сравнение с
прошлым прогоном того же объёма.

Единственный источник списка ячеек — сама игра: `matrix_report.gd -- --list` печатает
`MATRIX-CELL` из `ScenarioTargets.role_ids()` × `HeroClasses.CLASSES`. Копия 5×11 здесь
расходилась бы с таблицами игры при первой же новой роли, и матрица молча недосчитывала
бы строки (**T-238**, «дубли сценариев»).

Запуск (из корня репо):

    python3 scripts/scenario_matrix.py --cell fighter,collector          # одна ячейка
    python3 scripts/scenario_matrix.py --roles trader,builder --turns 30 # выборка
    python3 scripts/scenario_matrix.py --full --history docs/mvp/matrix/history.jsonl
    python3 scripts/scenario_matrix.py --full --expensive skip           # дорогое — мимо
    python3 scripts/scenario_matrix.py --compare --history docs/mvp/matrix/history.jsonl

Без фильтров и без `--full` — **выборка** (первый по алфавиту класс каждой роли), как
требует спек: «по умолчанию — выборка (не все 55), полная матрица — по маркеру».

Коды выхода — те же, что у `game/tools/survival_report.gd`: недобор цели и регрессии
относительно прошлого прогона — это измерение, а не падение (`MATRIX-WARNING`, 0);
поломанные ячейки, отсутствующие строки, дубли ячеек и нераспознанный вывод — техническая
ошибка (`MATRIX-ERRORS`, 1). Отчёт пишется в файл, путь печатается в stdout.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import shutil
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROJECT = os.path.join(REPO, "game")
TOOL = "res://tools/matrix_report.gd"
DEFAULT_HISTORY = os.path.join("docs", "mvp", "matrix", "history.jsonl")
## Ячейка дороже этого числа ходов считается «дорогой сценой» (**T-238**, выключатель
## дорогих сцен). Это бюджет запуска, а не игровой баланс: 90-ходовые профили
## (traveler/trader/builder) для быстрой проверки регрессий не нужны.
EXPENSIVE_TURNS = 60


class MatrixError(Exception):
    """Техническая проблема прогона/разбора: не «недобор цели», а сломанный замер."""


# ─────────────────────────────── разбор вывода ───────────────────────────────


def _coerce(value: str):
    if value == "true":
        return True
    if value == "false":
        return False
    try:
        return int(value)
    except ValueError:
        pass
    try:
        return float(value)
    except ValueError:
        return value


def parse_fields(payload: str) -> dict:
    """`class=fighter|turns=12|goal=true` → словарь. Значение может содержать `=`
    (текстовые `reason=`/`block=`), поэтому режем только по первому `=`; фрагмент без
    `=` — продолжение предыдущего значения, а не отдельное поле."""
    out: dict = {}
    last_key = None
    for frag in payload.split("|"):
        if not frag:
            continue
        if "=" in frag:
            key, _, value = frag.partition("=")
            out[key] = _coerce(value)
            last_key = key
        elif last_key is not None:
            out[last_key] = f"{out[last_key]}|{frag}" if isinstance(out[last_key], str) else frag
    return out


def parse_run(stdout: str, role: str) -> dict:
    """Разбор stdout одного процесса `matrix_report.gd` для одной роли.

    Возвращает `{"rows": [...], "summary": {...}, "errors": [...], "determinism": [...]}`.
    Строки `MATRIX-BEAT|MATRIX-SLOW|MATRIX-LEDGER|MATRIX-UNIT|MATRIX-DIFF|MATRIX-ROW-*`
    — трасса, в отчёт не входят: отчёт обязан оставаться тем же множеством ячеек, что
    и план, иначе «недобор» неотличим от режима трассы.
    """
    rows: list[dict] = []
    summary: dict = {}
    tool_errors: list[str] = []
    determinism: list[dict] = []
    for line in stdout.splitlines():
        if line.startswith("MATRIX|"):
            row = parse_fields(line[len("MATRIX|"):])
            row["role"] = role
            rows.append(row)
        elif line.startswith("MATRIX-SUMMARY|"):
            summary = parse_fields(line[len("MATRIX-SUMMARY|"):])
            summary["role"] = role
        elif line.startswith("MATRIX-ERRORS|"):
            tool_errors.append(line[len("MATRIX-ERRORS|"):])
        elif line.startswith("MATRIX-DETERMINISM|"):
            determinism.append(parse_fields(line[len("MATRIX-DETERMINISM|"):]))
    return {"rows": rows, "summary": summary, "errors": tool_errors, "determinism": determinism}


def parse_inventory(stdout: str) -> list[dict]:
    """`MATRIX-CELL` → план ячеек; `MATRIX-INV` обязана сойтись с числом строк."""
    cells: list[dict] = []
    inv: dict | None = None
    for line in stdout.splitlines():
        if line.startswith("MATRIX-CELL|"):
            cells.append(parse_fields(line[len("MATRIX-CELL|"):]))
        elif line.startswith("MATRIX-INV|"):
            inv = parse_fields(line[len("MATRIX-INV|"):])
    if inv is None:
        raise MatrixError("нет строки MATRIX-INV — инвентарь ячеек не напечатан")
    if int(inv.get("cells", -1)) != len(cells):
        raise MatrixError(
            f"MATRIX-INV|cells={inv.get('cells')} не совпала с числом MATRIX-CELL ({len(cells)})"
        )
    seen = set()
    for cell in cells:
        key = (str(cell.get("role")), str(cell.get("class")))
        if key in seen:
            raise MatrixError(f"дубль ячейки в инвентаре: {key[0]}×{key[1]}")
        seen.add(key)
    if not cells:
        raise MatrixError("инвентарь ячеек пуст")
    return cells


# ─────────────────────────────── план прогона ───────────────────────────────


def plan(inventory: list[dict], roles=None, classes=None, cell=None,
         turns=None, full=False, expensive="run", expensive_above=EXPENSIVE_TURNS):
    """Отбор ячеек. Возвращает `(selected, skipped)`; skipped — список `(cell, причина)`.

    Приоритет: `--cell` (одна ячейка) → `--roles`/`--classes` → выборка по умолчанию
    (первый по алфавиту класс каждой роли). `--full` берёт весь инвентарь.
    """
    if cell:
        cls, _, role = cell.partition(",")
        wanted = [(role, cls)]
    elif roles or classes:
        role_set = set(roles) if roles else None
        class_set = set(classes) if classes else None
        wanted = [
            (str(c["role"]), str(c["class"])) for c in inventory
            if (role_set is None or str(c["role"]) in role_set)
            and (class_set is None or str(c["class"]) in class_set)
        ]
    elif full:
        wanted = [(str(c["role"]), str(c["class"])) for c in inventory]
    else:
        first_by_role: dict[str, str] = {}
        for c in sorted(inventory, key=lambda c: (str(c["role"]), str(c["class"]))):
            first_by_role.setdefault(str(c["role"]), str(c["class"]))
        wanted = [(r, c) for r, c in sorted(first_by_role.items())]

    by_key = {(str(c["role"]), str(c["class"])): c for c in inventory}
    selected: list[dict] = []
    skipped: list[tuple[dict, str]] = []
    for key in wanted:
        base = by_key.get(key)
        if base is None:
            raise MatrixError(f"ячейки нет в инвентаре игры: {key[0]}×{key[1]}")
        item = dict(base)
        item["turns"] = int(turns) if turns else int(base.get("turns", 0))
        if expensive == "skip" and item["turns"] > expensive_above:
            skipped.append((item, f"дорогая сцена: turns={item['turns']} > {expensive_above}"))
            continue
        selected.append(item)
    return selected, skipped


# ─────────────────────────────── прогоны ───────────────────────────────


def godot_bin(explicit: str | None = None) -> str:
    for candidate in (explicit, os.environ.get("GODOT_BIN"), shutil.which("godot")):
        if candidate and os.path.exists(candidate):
            return candidate
    raise MatrixError("Godot не найден: передай --godot или GODOT_BIN")


def run_inventory(bin_path: str, timeout: int) -> list[dict]:
    cmd = [bin_path, "--headless", "--path", PROJECT, "-s", TOOL, "--", "--list"]
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    return parse_inventory(proc.stdout)


def run_role(bin_path: str, role: str, classes: list[str], turns: int, timeout: int) -> dict:
    cmd = [bin_path, "--headless", "--path", PROJECT, "-s", TOOL, "--",
           role, str(turns), ",".join(classes)]
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    parsed = parse_run(proc.stdout, role)
    parsed["returncode"] = proc.returncode
    return parsed


# ─────────────────────────────── отчёт и проверка ───────────────────────────────

def cell_record(row: dict) -> dict:
    """Ячейка отчёта в форме спека: {class, role, metrics, survived, turns, seed}
    плюс `goal_met` (история и сравнение) и `seconds` (требование «время прогона»)."""
    metrics = {k: v for k, v in sorted(row.items())
               if k not in ("class", "role", "seed", "turns", "survived", "goal",
                            "goal_turn", "error", "secs")}
    return {
        "class": str(row.get("class", "?")),
        "role": str(row.get("role", "?")),
        "seed": row.get("seed"),
        "turns": row.get("turns"),
        "survived": bool(row.get("survived", False)),
        "goal_met": bool(row.get("goal", False)),
        "goal_turn": row.get("goal_turn"),
        "seconds": row.get("secs"),
        "error": str(row.get("error", "") or ""),
        "metrics": metrics,
    }


def check_run(selected: list[dict], rows: list[dict]) -> tuple[list[dict], list[str]]:
    """Сверка плана и строк прогона: дубли, отсутствующие ячейки, строки-призраки.

    Возвращает `(записи, технические_ошибки)`. Отсутствующая ячейка получает запись
    `error="нет строки прогона"` — молчаливая дырка в отчёте опаснее падающего
    прогона (ровно этот класс дефекта матрица отдала кодом 0 в 2026-10-26).
    """
    problems: list[str] = []
    records: list[dict] = []
    by_key: dict[tuple[str, str], list[dict]] = {}
    for row in rows:
        by_key.setdefault((str(row.get("role")), str(row.get("class"))), []).append(row)
    for cell in selected:
        key = (str(cell["role"]), str(cell["class"]))
        found = by_key.pop(key, [])
        if not found:
            problems.append(f"нет строки прогона: {key[0]}×{key[1]}")
            records.append({"class": key[1], "role": key[0], "seed": cell.get("seed"),
                            "turns": None, "survived": False, "goal_met": False,
                            "goal_turn": None, "seconds": None, "error": "нет строки прогона",
                            "metrics": {}})
            continue
        if len(found) > 1:
            problems.append(f"дубль строки: {key[0]}×{key[1]} ({len(found)} строки)")
        records.append(cell_record(found[0]))
    for (role, cls) in sorted(by_key):
        problems.append(f"строка вне плана: {role}×{cls}")
    return records, problems


def build_report(records: list[dict], scope: dict, head_sha: str, tool: str) -> dict:
    goals = sum(1 for r in records if r["goal_met"])
    alive = sum(1 for r in records if r["survived"])
    return {
        "date": dt.date.today().isoformat(),
        "head_sha": head_sha,
        "tool": tool,
        "scope": scope,
        "summary": {
            "cells": len(records),
            "goal_met": f"{goals}/{len(records)}",
            "survived": f"{alive}/{len(records)}",
        },
        "cells": records,
    }


# ─────────────────────────────── история и сравнение ───────────────────────────────


def scope_key(scope: dict) -> str:
    """Одинаковый объём прогона = сопоставимая история. Разные составы не сравниваем:
    «выборка 5 ячеек» против «полной матрицы» регрессией быть не может."""
    return json.dumps(scope, sort_keys=True, ensure_ascii=False)


def load_history(path: str) -> list[dict]:
    if not os.path.exists(path):
        return []
    entries = []
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if line:
                entries.append(json.loads(line))
    return entries


def append_history(path: str, entry: dict) -> None:
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "a", encoding="utf-8") as handle:
        handle.write(json.dumps(entry, ensure_ascii=False, sort_keys=True) + "\n")


def previous_entry(entries: list[dict], scope: dict) -> dict | None:
    key = scope_key(scope)
    for entry in reversed(entries):
        if scope_key(entry.get("scope", {})) == key:
            return entry
    return None


def compare_cells(prev: list[dict], now: list[dict]) -> tuple[list[str], list[str]]:
    """Сравнение по парам (role, class): регрессии и улучшения.

    Регрессия — `goal_met 1→0`, `survived 1→0` или прогон, ставший ошибкой. Падение
    числа ходов регрессией **не** считается: цель может быть достигнута раньше, и это
    улучшение, а не поломка.
    """
    def index(records: list[dict]) -> dict:
        return {(r["role"], r["class"]): r for r in records}

    old, new = index(prev), index(now)
    regressions: list[str] = []
    improvements: list[str] = []
    for key in sorted(set(old) & set(new)):
        a, b = old[key], new[key]
        tag = f"{key[0]}×{key[1]}"
        if a["goal_met"] and not b["goal_met"]:
            regressions.append(f"{tag}: цель была и стала недостижима")
        elif b["goal_met"] and not a["goal_met"]:
            improvements.append(f"{tag}: цель достигнута впервые")
        if a["survived"] and not b["survived"]:
            regressions.append(f"{tag}: герой выживал и погиб")
        if not a["error"] and b["error"]:
            regressions.append(f"{tag}: прогон стал ошибочным ({b['error']})")
    return regressions, improvements


# ─────────────────────────────── вспомогательное ───────────────────────────────


def git_head() -> str:
    try:
        out = subprocess.run(["git", "-C", REPO, "rev-parse", "--short", "HEAD"],
                             capture_output=True, text=True, timeout=30)
        return out.stdout.strip() or "?"
    except (OSError, subprocess.SubprocessError):
        return "?"


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="Драйвер матрицы «роль × класс» (T-238)")
    parser.add_argument("--godot", help="путь к Godot (иначе GODOT_BIN, затем PATH)")
    parser.add_argument("--roles", help="список ролей через запятую")
    parser.add_argument("--classes", help="список классов через запятую")
    parser.add_argument("--cell", help="одна ячейка: class,role")
    parser.add_argument("--turns", type=int, help="переопределить число ходов")
    parser.add_argument("--full", action="store_true", help="вся матрица (маркер полной)")
    parser.add_argument("--expensive", choices=("run", "skip"), default="run",
                        help="дорогие сцены (turns выше --expensive-above): run|skip")
    parser.add_argument("--expensive-above", type=int, default=EXPENSIVE_TURNS)
    parser.add_argument("--out", help="куда положить JSON-отчёт")
    parser.add_argument("--history", help="JSONL история прогонов (пусто = не писать)")
    parser.add_argument("--compare", action="store_true",
                        help="сверить с последним прогоном того же объёма")
    parser.add_argument("--timeout", type=int, default=3600, help="сек на один процесс Godot")
    parser.add_argument("--list-only", action="store_true", help="тогда инвентарь и выход")
    args = parser.parse_args(argv)

    try:
        bin_path = godot_bin(args.godot)
        inventory = run_inventory(bin_path, min(args.timeout, 600))
    except MatrixError as exc:
        print(f"MATRIX-ERRORS|{exc}")
        return 1
    except (OSError, subprocess.SubprocessError) as exc:
        print(f"MATRIX-ERRORS|инвентарь ячеек не получен: {exc}")
        return 1

    if args.list_only:
        for cell in inventory:
            print(f"MATRIX-CELL|role={cell['role']}|class={cell['class']}"
                  f"|seed={cell['seed']}|turns={cell['turns']}")
        print(f"MATRIX-INV|roles={len({c['role'] for c in inventory})}"
              f"|classes={len({c['class'] for c in inventory})}|cells={len(inventory)}")
        return 0

    roles = args.roles.split(",") if args.roles else None
    classes = args.classes.split(",") if args.classes else None
    try:
        selected, skipped = plan(inventory, roles=roles, classes=classes, cell=args.cell,
                                 turns=args.turns, full=args.full, expensive=args.expensive,
                                 expensive_above=args.expensive_above)
    except MatrixError as exc:
        print(f"MATRIX-ERRORS|{exc}")
        return 1
    if not selected:
        print("MATRIX-ERRORS|план пуст — все ячейки отсечены фильтром")
        return 1
    for cell, reason in skipped:
        print(f"MATRIX-SKIP|role={cell['role']}|class={cell['class']}|{reason}")

    by_role: dict[str, dict] = {}
    for cell in selected:
        group = by_role.setdefault(str(cell["role"]), {"classes": [], "turns": int(cell["turns"])})
        group["classes"].append(str(cell["class"]))
        group["turns"] = max(group["turns"], int(cell["turns"]))

    rows: list[dict] = []
    problems: list[str] = []
    summaries: list[dict] = []
    for role, group in sorted(by_role.items()):
        print(f"MATRIX-RUN|role={role}|classes={len(group['classes'])}|turns={group['turns']}")
        try:
            parsed = run_role(bin_path, role, group["classes"], group["turns"], args.timeout)
        except (OSError, subprocess.SubprocessError) as exc:
            problems.append(f"{role}: процесс не отработал ({exc})")
            continue
        rows.extend(parsed["rows"])
        if parsed["summary"]:
            summaries.append(parsed["summary"])
        problems.extend(f"{role}: {e}" for e in parsed["errors"])
        if parsed["returncode"] not in (0, 1) or (parsed["returncode"] == 1 and not parsed["errors"]):
            problems.append(f"{role}: код возврата {parsed['returncode']} без MATRIX-ERRORS")

    records, checked = check_run(selected, rows)
    problems.extend(checked)

    scope = {
        "roles": sorted({r["role"] for r in records}),
        "classes": sorted({r["class"] for r in records}),
        "turns": {r["role"]: next(c["turns"] for c in selected if c["role"] == r["role"])
                  for r in records},
        "expensive": args.expensive,
    }
    report = build_report(records, scope, git_head(), TOOL)
    report["summaries"] = summaries
    report["skipped"] = [{"role": c["role"], "class": c["class"], "reason": why}
                         for c, why in skipped]

    out_path = args.out or os.path.join(
        "docs", "mvp", "matrix", dt.date.today().isoformat(),
        f"matrix-{dt.datetime.now().strftime('%H%M%S')}.json")
    os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as handle:
        json.dump(report, handle, ensure_ascii=False, indent=1, sort_keys=True)
    print(f"MATRIX-REPORT|{out_path}|cells={len(records)}"
          f"|goal={report['summary']['goal_met']}|survived={report['summary']['survived']}")

    warnings: list[str] = []
    if args.history:
        entries = load_history(args.history)
        if args.compare:
            prev = previous_entry(entries, scope)
            if prev is None:
                print("MATRIX-CMP|нет прогона того же объёма в истории — сверять не с чем")
            else:
                regressions, improvements = compare_cells(prev.get("cells", []), records)
                for line in regressions:
                    print(f"MATRIX-CMP|regression|{line}")
                for line in improvements:
                    print(f"MATRIX-CMP|improvement|{line}")
                if regressions:
                    warnings.append(f"регрессий {len(regressions)} (сверка с {prev.get('head_sha')})")
        append_history(args.history, {"date": report["date"], "head_sha": report["head_sha"],
                                      "scope": scope, "summary": report["summary"],
                                      "cells": records})
        print(f"MATRIX-HISTORY|{args.history}|записей={len(entries) + 1}")

    if problems:
        print(f"MATRIX-ERRORS|n={len(problems)}|{' ; '.join(problems)}")
        return 1
    if warnings:
        print(f"MATRIX-WARNING|{' ; '.join(warnings)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

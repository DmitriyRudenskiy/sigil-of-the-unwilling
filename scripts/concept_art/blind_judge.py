#!/usr/bin/env python3
"""Слепой судья без человека: свежая сессия `pi` без инструментов смотрит листы
якорей и ставит баллы. Инструментов чтения у неё нет — реестр с заявленными
уровнями прочесть нечем. Ответы пишутся тем же `anchors score`, класс
`independent`; сырые ответы остаются в docs/anchor-judge-<дата>.md для аудита.

Запуск: python3 scripts/concept_art/blind_judge.py [--only AP-line]
"""
import concurrent.futures as cf
import re
import subprocess
import sys
from datetime import date
from pathlib import Path
from types import SimpleNamespace

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from concept_art import jobloop as j

# Что именно читается по строке — судья знает строку, но не знает уровней.
ROW = {"line": "линия: ровный тёмный контур одинаковой толщины закрывает каждый фрагмент",
       "color": "колорит: семья оттенков, сатурация, температура, отсутствие глянцевого сдвига",
       "texture": "фактура: характер поверхности — мазок, матовость, микровариация, не пластик",
       "shade": "светотень: световая логика, жёсткость собственной тени, мягкий возврат"}


def ask(board: Path, pairs: list[dict]) -> tuple[dict, str]:
    rows = " · ".join(sorted({ROW[p["row"]] for p in pairs}))
    ask_for = "\n".join(f'{p["id"]} {p["row"]}=' for p in pairs)
    p = subprocess.run(
        ["pi", "-p", "--no-tools", "--no-session", "--mode", "text", f"@{board}",
         f"{j.BLIND_BRIEF}\n\nМеряемая строка листа: {rows}.\n"
         f"Ответь ровно {len(pairs)} строками, без пояснений и прочего текста "
         f"(id, строка, балл):\n{ask_for}N"],
        capture_output=True, text=True, timeout=1800, stdin=subprocess.DEVNULL)
    return (dict(re.findall(r"(AP-[\w-]+)[\s:=]+\w+\s*=\s*(\d+)", p.stdout)),
            p.stdout + ("\n[stderr]\n" + p.stderr if p.returncode else ""))


def main() -> int:
    only = sys.argv[2] if len(sys.argv) > 2 and sys.argv[1] == "--only" else ""
    today = str(date.today())
    judged = {r["id"] for r in j.anchor_log()
              if r.get("klass") == "independent" and r.get("date") == today}
    rows = j.anchor_rows()
    boards: dict[Path, list[dict]] = {}
    for r in rows:
        if (not only or only in r["id"]) and r["id"] not in judged:
            boards.setdefault(j.board_path(r), []).append(r)
    print(f"листов {len(boards)}, пар {sum(len(v) for v in boards.values())}, судья pi --no-tools")
    raw, marks = [], {}
    with cf.ThreadPoolExecutor(max_workers=min(8, len(boards))) as ex:
        for board, (got, text) in zip(boards, ex.map(lambda b: ask(b, boards[b]), boards)):
            raw.append(f"## {board.name}\n\n```\n{text.strip()}\n```\n")
            marks.update(got)
            print(f"  {board.name}: " + (", ".join(f"{k}={v}" for k, v in got.items())
                                         or "НЕ РАЗОБРАНО — ответ в журнале, переслать лист"))
    judge = f"pi:blind-{date.today()}"
    for r in rows:
        if r["id"] in judged:
            continue
        if r["id"] not in marks:
            print(f"{r['id']}: судья не ответил, пара не записана")
            continue
        j.cmd_anchors(SimpleNamespace(what="score", id=r["id"],
                                      mark=f'{r["row"]}={marks[r["id"]]}',
                                      judge_pass="revision", judge=judge,
                                      klass="independent"))
    log = j.DOCS / f"anchor-judge-{date.today()}.md"
    if not log.is_file():
        log.write_text(f"# Слепой проход {judge}\n\n")
    with log.open("a") as fh:
        fh.write("\n".join(raw) + "\n")
    print(f"сырые ответы: {log}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

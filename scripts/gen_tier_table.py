#!/usr/bin/env python3
"""Таблица «Слои прогона» в TEST-MAP генерируется из `run_tests.sh --help`.

Повод (срез test-suite-restructure 8.1): раздел С-6 переписывал руками, и к
моменту, когда слои поменяли, таблица осталась описывать прежний набор — читатель
ряда «сегодняшний гейт» не мог понять, что входит в слой. Числа файлов/тестов и
замер времени остаться в доке не могут (их знает только прогон), а **состав слоя**
знает раннер — он и есть единственный носитель.

Режимы:
  --check  сравнить сгенерированное с тем, что напечатано между сентинелями в
           доке; расхождение — красный (так док не может устареть молча);
  --write  вписать сгенерированное в док.

Уровень не имеет права молчать: пустой список слоёв в `--help` — красный, а не
«пустая таблица совпадает с пустой таблицей».
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
HELP_ARGS = [str(REPO / "game" / "run_tests.sh"), "--help"]
BEGIN = "<!-- ТИРЫ:НАЧАЛО (генерирует scripts/gen_tier_table.py --write; не редактировать) -->"
END = "<!-- ТИРЫ:КОНЕЦ -->"
# Строка слоя в --help: «  smoke — <что входит>, бюджет 30 с». Тире — эм-тире,
# бюджет у слоя может не быть (`full` — «по умолчанию», ограничения нет).
# Строки слоя в --help. Первая — «что меряет» (+ бюджет), следующая строка с тем
# же отступом — «команда: … | не мерит: …». Формат читается и человеком, и парсером.
ROW = re.compile(r"^\s*(smoke|fast|full)\s*[—-]\s*(.*?)(?:[,;]\s*бюджет\s+(.+?))?\s*$")
DETAIL = re.compile(r"^\s*команда:\s*(.*?)\s*\|\s*не мерит:\s*(.*?)\s*$")
# Строка таблицы дока, чтобы отличить сгенерированные строки от ручной таблицы.
DOC_ROW = re.compile(r"^\|\s*`(smoke|fast|full)`\s*\|")


def help_rows() -> list[tuple[str, str, str, str, str]]:
    out = subprocess.run(HELP_ARGS, capture_output=True, text=True, check=True).stdout
    rows: list[tuple[str, str, str, str, str]] = []
    lines = out.splitlines()
    for i, line in enumerate(lines):
        m = ROW.match(line)
        if not m:
            continue
        detail = DETAIL.match(lines[i + 1]) if i + 1 < len(lines) else None
        rows.append((
            m.group(1),
            m.group(2).strip(),
            detail.group(1) if detail else "—",
            (m.group(3) or "—").strip(),
            detail.group(2) if detail else "—",
        ))
    if not rows:
        raise SystemExit("TIER TABLE: RED — в `run_tests.sh --help` нет ни одной строки слоя; "
                         "источник пуст, сравнивать нечего")
    missing = [r[0] for r in rows if r[2] == "—"]
    if missing:
        raise SystemExit(f"TIER TABLE: RED — у слоёв {missing} нет строки «команда: … | не мерит: …»; "
                         "ряд «чего не мерит» — половина смысла слоя (T-281 про «не мерили»)")
    return rows


def table(rows: list[tuple[str, str, str, str, str]]) -> str:
    lines = ["| Слой | Что меряет | Команда | Бюджет | Чего не мерит |", "| --- | --- | --- | --- | --- |"]
    lines += [f"| `{t}` | {what} | `{cmd}` | {budget} | {notmeasured} |"
              for t, what, cmd, budget, notmeasured in rows]
    return "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("doc", nargs="?", default="docs/mvp/TEST-MAP.md")
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    path = Path(a.doc) if Path(a.doc).is_absolute() else REPO / a.doc
    want = table(help_rows())
    text = path.read_text()
    if BEGIN not in text or END not in text:
        # Ручная таблица вместо блока = док снова переписывают руками.
        manual = next((l for l in text.splitlines() if DOC_ROW.match(l)), "—")
        raise SystemExit(
            f"TIER TABLE: RED — в {path.name} нет блока {BEGIN}; ручная строка слоя: {manual!r}. "
            f"Замените её пустым блоком и заполните --write"
        )
    if a.write:
        head, rest = text.split(BEGIN, 1)
        tail = rest.split(END, 1)[1]
        path.write_text(f"{head}{BEGIN}\n\n{want}\n\n{END}{tail}")
        print(f"TIER TABLE: записано в {path.name} ({len(help_rows())} слоя)")
        return 0
    got = text.split(BEGIN, 1)[1].split(END, 1)[0].strip("\n")
    if got != want:
        print("TIER TABLE: RED — «Слои прогона» в доке разошлись с `run_tests.sh --help`:")
        print("--- в доке ---")
        print(got)
        print("--- из --help ---")
        print(want)
        print("починка: python3 scripts/gen_tier_table.py --write")
        return 2
    print(f"TIER TABLE: OK ({len(help_rows())} слоя сверены с `--help`)")
    return 0


if __name__ == "__main__":
    sys.exit(main())

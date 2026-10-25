#!/usr/bin/env python3
"""Приёмка UI read-агентом (задача 10.3, прецедент `blind_judge.py`).

Свежая сессия `pi` без инструментов и без истории смотрит по одному кадру демо
и отвечает по чек-листу спеки `battle-demo-ui`. Чисел модели в промпте нет —
агент обязан сам выписать то, что нарисовано, а сверку с `CombatState` делает
отчёт (`tools/capture_screens.gd` печатает модель рядом с каждым кадром).

Запуск: python3 battle-demo/tools/ui_read_judge.py
"""
import concurrent.futures as cf
import os
import subprocess
from datetime import date
from pathlib import Path

DEMO = Path(__file__).resolve().parent.parent
SHOTS = DEMO / "artifacts/screenshots"
OUT = DEMO / f"docs/ui-read-judge-{date.today()}.md"

# Кадр → состояние, снятое с него (без чисел: их агент читает с пикселей).
FRAMES = [
    ("a_select", "экран выбора набора, подтверждается набор A"),
    ("b_select", "экран выбора набора, подтверждается набор B"),
    ("a_start", "первые ходы боя, набор A"),
    ("b_start", "первые ходы боя, набор B"),
    ("a_mid", "середина боя, набор A"),
    ("b_mid", "середина боя, набор B"),
    ("a_result", "бой окончен, набор A"),
    ("b_result", "бой окончен, набор B"),
]

BRIEF = """Ты рецензируешь кадр боевого интерфейса тактической пошаговой демо-игры.
Отвечай только по тому, что видно на кадре; домысливать состояние игры нельзя.

Кадр: {state}.

Меряемые строки:
1. СОСТАВ — элементы макета на месте: поле с двумя сторонами, полосы HP над
   юнитами, полоса порядка ходов сверху, панель активного юнита с командами,
   панели полководцев по углам (для экрана выбора — две карты состава).
2. ЧИТАЕМОСТЬ — весь текст читается: кегль, контраст, подпись не тонет в фоне.
3. НАЛОЖЕНИЯ — ничего не перекрывает другое и ничего не обрезано краем кадра.
4. ПОМЕТКА — текущий юнит отличим от остальных; недоступная команда (если есть
   на кадре) помечена как недоступная; погибшие не выглядят живыми.

Ответь ровно четырьмя строками вида `КЛЮЧ=ok` или `КЛЮЧ=плохо: причина`, без
прочего текста, и пятой строкой выпиши все видимые числа:
ЧИСЛА: раунд=…, карточек_в_полосе=…, враг=…/…, своих=N
(чего на кадре нет — то `нет`)."""


def ask(frame: str, state: str) -> str:
    answer = subprocess.run(
        ["pi", "-p", "--no-tools", "--no-session", "--mode", "text",
         # Модель берётся та же, на которой идёт текущая сессия: дефолт
         # `settings.json` (27B на 9121) может быть поднят не был, и тогда
         # каждая сессия отвечает `Connection error`.
         "--provider", os.environ.get("PI_PROVIDER", "local-qwen38-flash-92"),
         "--model", os.environ.get("PI_MODEL", "qwen3.8-flash-next-unsloth-ud-iq4_xs"),
         f"@{SHOTS / (frame + '.png')}", BRIEF.format(state=state)],
        capture_output=True, text=True, timeout=1800, stdin=subprocess.DEVNULL)
    body = answer.stdout.strip()
    if answer.returncode:
        body += "\n[stderr]\n" + answer.stderr.strip()
    return body


def main() -> int:
    with cf.ThreadPoolExecutor(max_workers=4) as pool:
        answers = list(pool.map(lambda f: ask(*f), FRAMES))
    lines = [
        f"# Read-агент по кадрам приёмки — {date.today()}",
        "",
        "`pi -p --no-tools --no-session --mode text @кадр` (прецедент",
        "`scripts/concept_art/blind_judge.py`): у сессии нет ни инструментов,",
        "ни истории, ни чисел модели — только пиксели и чек-лист спеки. Сырые",
        "ответы ниже; сверка чисел с `CombatState` — в `docs/ui-review-2026-10-25.md`.",
        "",
    ]
    for (frame, state), answer in zip(FRAMES, answers):
        lines += [f"## {frame}.png — {state}", "", "```", answer or "[пусто]", "```", ""]
    OUT.write_text("\n".join(lines), encoding="utf-8")
    for (frame, _), answer in zip(FRAMES, answers):
        print(f"{frame}: " + " | ".join(answer.splitlines()[:4]))
    print(f"журнал → {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

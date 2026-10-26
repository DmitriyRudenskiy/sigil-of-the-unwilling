#!/usr/bin/env python3
"""Классификатор MCP-журнала: ошибка readiness — жёлтый, а не красный (D-265).

Зачем. MCP-секция поднимает живой Godot (не headless) и ждёт готовности игры
(`game/tests/mcp/godot_mcp.py:163 wait_ready`). Когда машине не хватает памяти,
ready не наступает за `READY_TIMEOUT` (180 с), fixture падает с
`MCPError: игра не готова за 180 с (… Not connected to game interaction server.)`,
pytest считает это `error`, а гейт считал это красным. Замеры 2026-10-26: четыре
прогона подряд, жертвы каждый раз разные файлы, изолированно те же тесты зелёные,
длительность секции прыгала 290 с → 655 с при 13 GB RSS чужого процесса и
«свободно 0» по `free -g`. Отличить «одна регрессия» от «одна среда» глазами было
нельзя, и агент сжигал прогон (~11 мин) на различение.

Решение владельца (2026-10-26): **readiness-error — жёлтый**. Здесь оно прошито явно:
жёлтыми считаются ТОЛЬКО падения, в тексте которых есть подпись `wait_ready`
(`READINESS_PATTERNS`). Всё остальное — `<failure>`, другой `<error>`, упавший
teardown, непарсящийся журнал — остаётся красным. Жёлтый не «съедается»: количество
и имена жертв печатаются в протокол, а строка `MCP VERDICT: YELLOW` обязана попасть
в гейт-артефакт.

Вызов: `python3 scripts/classify_mcp_junit.py <junit.xml> [...]`
Код возврата: 0 — зелёный (красного и жёлтого нет), **3 — жёлтый** (только readiness;
только он и имеет право снять красный с pytest), 1 — есть красное, 2 — журнал не разобран
(красный не снимается; молчать секция не имеет права).
"""

from __future__ import annotations

import sys
import xml.etree.ElementTree as ET
from pathlib import Path

# Единственный источник подписи — `wait_ready` в godot_mcp.py:172. Расширять список
# можно только новой строкой замера: «похоже на среду» сюда писать нельзя.
READINESS_PATTERNS: tuple[str, ...] = ("игра не готова за",)

GREEN = "MCP VERDICT: GREEN"
YELLOW = "MCP VERDICT: YELLOW"
RED = "MCP VERDICT: RED"


def _is_readiness(text: str) -> bool:
    low = text.lower()
    return any(p.lower() in low for p in READINESS_PATTERNS)


def classify(paths: list[Path]) -> dict:
    """Разбирает junit-отчёты; возвращает вердикт и списки жертв.

    Бросает Exception, если хотя бы один файл не читается или не является junit, —
    вызывающий обязан трактовать это как «не разобрано» (красный), а не как «пусто».
    """
    red: list[str] = []
    yellow: list[str] = []
    counts = {"passed": 0, "skipped": 0, "failed": 0, "errors": 0}
    for path in paths:
        root = ET.parse(path).getroot()  # намеренно без guard: не разобрано = красный
        for case in root.iter("testcase"):
            where = f"{case.get('classname', '?')}::{case.get('name', '?')}"
            problems = list(case)
            bad = [c for c in problems if c.tag in ("failure", "error")]
            if not bad:
                if any(c.tag == "skipped" for c in problems):
                    counts["skipped"] += 1
                else:
                    counts["passed"] += 1
                continue
            for node in bad:
                text = " ".join(
                    filter(None, [node.get("message") or "", node.text or ""])
                )
                counts["errors" if node.tag == "error" else "failed"] += 1
                # 2026-10-26: readiness ловился только как <error>. Замер гейта
                # среза D-268: `test_scenario_pilot_collector_wizard` упал с тем же
                # `MCPError: игра не готова за 180 с`, но pytest записал его как
                # <failure> (таймаут наступил не в setup, а внутри теста) — и гейт
                # покраснел, хотя классификатор должен был сказать «среда».
                # Подпись принадлежит только readiness-гейту, тег значения не имеет.
                if _is_readiness(text):
                    yellow.append(f"{where} :: {_first_line(text)}")
                else:
                    red.append(f"{where} [{node.tag}] :: {_first_line(text)}")
    verdict = RED if red else (YELLOW if yellow else GREEN)
    return {"verdict": verdict, "red": red, "yellow": yellow, "counts": counts}


def _first_line(text: str) -> str:
    for line in text.splitlines():
        s = line.strip()
        if s:
            return s[:180]
    return "<пусто>"


def main(argv: list[str]) -> int:
    paths = [Path(a) for a in argv[1:]]
    if not paths:
        print("MCP VERDICT: RED (не передано ни одного junit-журнала — секция молчит)")
        return 2
    missing = [str(p) for p in paths if not p.is_file()]
    if missing:
        print(f"MCP READINESS: SKIPPED (нет файлов журнала: {', '.join(missing)})")
        return 2
    try:
        res = classify(paths)
    except Exception as exc:  # noqa: BLE001 - любой сбой разбора = «не разобрано»
        print(f"MCP READINESS: SKIPPED (журнал не разобран: {exc}; errors считаются красными)")
        return 2
    c = res["counts"]
    print(
        "MCP JUNIT: passed=%d skipped=%d failed=%d errors=%d"
        % (c["passed"], c["skipped"], c["failed"], c["errors"])
    )
    if res["yellow"]:
        print(
            "MCP READINESS: YELLOW — %d error с подпиской readiness (%s): среда, не "
            "регрессия (D-265); тесты обязан переснять владелец либо повторный прогон:"
            % (len(res["yellow"]), READINESS_PATTERNS[0])
        )
        for line in res["yellow"]:
            print("  - %s" % line)
    for line in res["red"]:
        print("MCP RED: %s" % line)
    print(res["verdict"])
    if res["verdict"] == RED:
        return 1
    # Жёлтый — отдельный код, а не общий ноль: право снять красный с pytest есть ONLY у
    # readiness. Зелёный вердикт при ненулевом коде pytest (например, exit 5 — «nothing
    # collected») красный снимать не должен, иначе молчание снова станет зелёным.
    return 3 if res["verdict"] == YELLOW else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

#!/usr/bin/env python3
"""Реестр прогонов `battle-demo/docs/generation-log.md` из манифеста (задача 6.10).

Вердикт — ручная колонка в `battle-demo/artifacts/verdicts.json`
(`{"<путь к кадру>": "годен" | "брак: <причина>"}`); без записи — «не смотрен».

Запуск: python3 battle-demo/tools/gen_log.py
"""
import json
import sys
from pathlib import Path

import comfy

ROOT = comfy.ROOT
MANIFEST = ROOT / "battle-demo/artifacts/generation-manifest.json"
VERDICTS = ROOT / "battle-demo/artifacts/verdicts.json"
OUT = ROOT / "battle-demo/docs/generation-log.md"


def main() -> int:
    rows = json.loads(MANIFEST.read_text()) if MANIFEST.exists() else []
    verdicts = json.loads(VERDICTS.read_text()) if VERDICTS.exists() else {}
    lines = [
        "# Реестр прогонов спрайтов (задача 6.10)",
        "",
        "Строка = один кадр. Источник строки — `artifacts/generation-manifest.json`",
        "(его пишет `tools/gen_frames.py`), вердикт — `artifacts/verdicts.json`.",
        "Пиксели кадров в git не идут (D-185); контрольные суммы — в манифесте.",
        "Один кадр может стоять несколькими строками — это перегенерация после брака;",
        "вердикт относится к последней строке (последнему прогону).",
        "",
        "| персонаж | анимация | кадр | портрет | карта позы | seed | рез. | кадр | md5 | вердикт |",
        "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |",
    ]
    for row in rows:
        lines.append(
            f"| {row['character']} | {row['animation']} | {row['frame']} "
            f"| `{row['source_portrait']}` | `{row['pose_map']}` | {row['seed']} "
            f"| {row['resolution']} | `{row['path']}` | {row['md5'][:8]} "
            f"| {verdicts.get(row['path'], 'не смотрен')} |")
    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"строк: {len(rows)} → {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

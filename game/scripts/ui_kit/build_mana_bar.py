#!/usr/bin/env python3
"""Генерация fill_mana.png — полоса маны по образцу полосы HP.

Провенанс (macOS-режим, ui-mockup-parity §5, 2026-10-21):
макет 11 (`1791966469952-...jpeg`, нормализован к 1920×1080) — мана-строка
карточки героя, y 105..122, x 65..325. Замеры по строкам:

    верхняя кромка  (42, 144, 210)  #2a90d2
    середина        (26, 117, 189)  #1a75bd
    нижняя кромка   (16,  67, 119)  #104377

Форма силуэта берётся из `fill_health.png` (тот же скруглённый 9-слейс),
цвет — градиент макета по яркости исходника: полоса остаётся парной HP-полосе
геометрически и отличается только палитрой (мандат: цвет — из макета).

Запуск: python3 scripts/ui_kit/build_mana_bar.py  (из game/)
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
OUT = HERE.parent.parent / "assets" / "ui" / "widgets" / "progress_bars"
SRC = OUT / "fill_health.png"

TOP = (42, 144, 210)
MID = (26, 117, 189)
BOTTOM = (16, 67, 119)


def _ramp(t: float) -> tuple[float, float, float]:
    """Двухсегментный градиент макета: bright → mid → dark."""
    a, b = (TOP, MID) if t < 0.5 else (MID, BOTTOM)
    k = t * 2.0 if t < 0.5 else (t - 0.5) * 2.0
    return tuple(a[i] + (b[i] - a[i]) * k for i in range(3))


def main() -> None:
    src = Image.open(SRC).convert("RGBA")
    w, h = src.size
    lum = [sum(src.getpixel((x, y))[:3]) / 3.0 for y in range(h) for x in range(w)]
    lo, hi = min(lum), max(lum)
    span = max(hi - lo, 1.0)
    out = Image.new("RGBA", (w, h))
    for y in range(h):
        for x in range(w):
            r, g, b, a = src.getpixel((x, y))
            if a == 0:
                continue
            # яркость исходника → положение на градиенте макета (сверху вниз)
            t = 1.0 - (sum((r, g, b)) / 3.0 - lo) / span
            nr, ng, nb = _ramp(max(0.0, min(1.0, t)))
            out.putpixel((x, y), (int(nr), int(ng), int(nb), a))
    OUT.mkdir(parents=True, exist_ok=True)
    out.save(OUT / "fill_mana.png")
    print(f"wrote {OUT / 'fill_mana.png'} ({w}x{h})")


if __name__ == "__main__":
    main()

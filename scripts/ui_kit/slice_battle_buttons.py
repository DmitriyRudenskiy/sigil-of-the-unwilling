#!/usr/bin/env python3
"""Нарезка листа кнопок владельца на семь медальонов боевой панели (alpha-battle-field 4.1).

Носитель — `~/Downloads/Interface_battle/mai-image-2.6 (t2i)_b_A_3×3_grid_of_hand-p.png`
(1536×1536): сетка 3×3, семь ячеек заняты, две пустые. Альфы у носителя нет —
медальоны тёмные на тёмном же фоне, поэтому не вырезание (`place_hero_art.keyed`
тут не применим: порога «белый» кадр не имеет), а рез по ячейкам и округлая
маска вместо кожаной дорожки (почему маской, а не по цвету — в `matte`).

Имена — по команде, а не по позиции, чтобы потребитель панели читался. Спорные
пары (флаг/бегущая ↔ «отступить», меч/бегущая ↔ «автобой») решены design.md §4,
а не на глаз — см. `CELLS`.

Запуск: python3 scripts/ui_kit/slice_battle_buttons.py [--dry]
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
SRC = Path.home() / "Downloads/Interface_battle/mai-image-2.6 (t2i)_b_A_3×3_grid_of_hand-p.png"
OUT = ROOT / "game/assets/ui/widgets/battle"
GRID = 3
INSET = 0.022          # кожаная дорожка по краям ячейки, доля кадра с каждой стороны (замер кадра: дорожка ~2%)
RADIUS = 0.135          # скругление пластины (у носителя скругление пластины ~13% ширины)
FEATHER = 3.0          # мягкая кромка маски, px


# ячейка (col, row) → имя команды. Соответствие знак↔команда взято из design.md §4
# («знак „меч“ листа едет на „Автобой“»), а не на глаз: белый флаг = `surrender`
# (капитуляция — T-282, на панели НЕ рисуется, медальон лежит носителем), бегущая
# фигура = `retreat` (отступить), меч = `auto` (у описания владельца «скрещённые
# мечи» — в листе их нет, расхождение фиксирует приёмка 4.6, а не молчание).
CELLS = {
    (0, 0): "spellbook",
    (1, 0): "surrender",
    (2, 0): "retreat",
    (0, 1): "cancel",
    (1, 1): "wait",
    (2, 1): "defend",
    (1, 2): "auto",
}


def matte(cell: Image.Image) -> Image.Image:
    """Прозрачные поля по краям плитки — округлая маска, а не вырезание.

    Отделить кожаную дорожку по цвету не вышло: угол ячейки — это сама пластина,
    а дорожка фактурная (замер: bbox = весь кадр при порогах 14/18/25/32 и по
    «отличается от угла», и по «темнее угла»). AC задачи требует прозрачные поля
    и размер = геометрия ячейки, поэтому маска берётся геометрией листа: сетка
    3×3 правильная, пластина в ней центрирована.
    """
    w, h = cell.size
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle([w * INSET, h * INSET, w * (1 - INSET), h * (1 - INSET)],
                        radius=w * RADIUS, fill=255)
    out = cell.convert("RGBA")
    out.putalpha(m.filter(ImageFilter.GaussianBlur(FEATHER)))
    return out


def main() -> int:
    dry = "--dry" in sys.argv
    if not SRC.exists():
        print(f"нет носителя: {SRC}")
        return 1
    src = Image.open(SRC).convert("RGB")
    cw, ch = src.width // GRID, src.height // GRID
    OUT.mkdir(parents=True, exist_ok=True)
    bad = 0
    for (col, row), name in sorted(CELLS.items(), key=lambda kv: (kv[0][1], kv[0][0])):
        cell = src.crop((col * cw, row * ch, (col + 1) * cw, (row + 1) * ch))
        plate = matte(cell)
        # пластина обязана быть почти квадратной: медальон растягивается под
        # размер кнопки, и чужая пропорция = эллипс вместо щита
        ratio = plate.width / plate.height
        a = plate.split()[-1]
        line = (f"{name:10s} {plate.width}×{plate.height} (пропорция {ratio:.2f}), "
                f"углы {max(a.getpixel(p) for p in [(0, 0), (plate.width - 1, plate.height - 1)])}, "
                f"центр {a.getpixel((plate.width // 2, plate.height // 2))}")
        if not 0.8 <= ratio <= 1.25 or max(a.getpixel(p) for p in [(0, 0), (plate.width - 1, plate.height - 1)]) > 0:
            line += "  ⚠ пропорция вне медальона"
            bad += 1
        print(" ", line)
        if not dry:
            plate.save(OUT / f"{name}.png")
    print(("проверка (без записи) " if dry else "записано в ") + str(OUT))
    return 1 if bad else 0


if __name__ == "__main__":
    raise SystemExit(main())

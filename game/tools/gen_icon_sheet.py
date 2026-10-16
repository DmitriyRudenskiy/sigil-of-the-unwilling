#!/usr/bin/env python3
"""Пересъёмка листа доказательств ASSET-1: docs/img/18_asset1_resources_sheet.png.

Четыре рендера одной строкой иконок (порядок — по id), на носителе §4.1:
  1 нативный 32×32 · 2 ×2 nearest · 3 16 px на носителе · 4 60 % десатурация.

Лист — доказательство группы B (глазами), поэтому он переснимается каждый раз,
когда меняется состав или рисунок: `python3 game/tools/gen_icon_sheet.py`.
Раньше собирался одноразовым скриптом в /tmp — воспроизвести кадр после смены
икон было нечем. Подписи латиницей: растровый шрифт PIL кириллицы не имеет, и
прежний лист выходил с квадратиками вместо подписей.

Меру различимости этот скрипт не считает — только композит (dHash живёт в
DhashMeasure, печать матрицы — в tools/dhash_report.gd).
"""
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICONS = os.path.join(ROOT, "assets", "ui", "icons", "resources")
OUT = os.path.join(os.path.dirname(ROOT), "docs", "img", "18_asset1_resources_sheet.png")
CARRIER = (0x28, 0x1C, 0x0F)
LABEL = (0xAE, 0x9C, 0x77)
GUTTER = 8
ROW_H = 56


def _desat(img: Image.Image, keep: float) -> Image.Image:
    gray = img.convert("L").convert("RGBA")
    out = Image.blend(gray, img, keep)
    out.putalpha(img.getchannel("A"))
    return out


def _row(imgs, scale, step):
    w = GUTTER + step * len(imgs)
    row = Image.new("RGBA", (w, ROW_H), CARRIER + (255,))
    for i, img in enumerate(imgs):
        cell = img if scale == 1 else img.resize((32 * scale, 32 * scale), Image.NEAREST)
        row.alpha_composite(cell, (GUTTER + i * step, (ROW_H - cell.height) // 2))
    return row


def main():
    ids = sorted(f[len("icon_resource_"):-len(".png")]
                 for f in os.listdir(ICONS)
                 if f.startswith("icon_resource_") and f.endswith(".png"))
    icons = [Image.open(os.path.join(ICONS, f"icon_resource_{i}.png")).convert("RGBA")
             for i in ids]
    small = [i.resize((16, 16), Image.LANCZOS) for i in icons]
    rows = [
        ("1 native 32x32", _row(icons, 1, 40), 1),
        ("2 x2 nearest", _row(icons, 2, 76), 2),
        ("3 16 px on carrier", _row(small, 1, 24), 3),
        ("4 60% desaturated", _row([_desat(i, 0.4) for i in icons], 1, 40), 4),
    ]
    width = max(r[1].width for r in rows) + GUTTER
    sheet = Image.new("RGB", (width, len(rows) * (ROW_H + 14)), (0x1B, 0x13, 0x0A))
    draw = ImageDraw.Draw(sheet)
    for n, (label, row, _scale) in enumerate(rows):
        sheet.paste(row.convert("RGB"), (0, n * (ROW_H + 14)))
        draw.text((GUTTER, n * (ROW_H + 14) + ROW_H + 2), label, fill=LABEL)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    sheet.save(OUT)
    print(f"{OUT}: {len(ids)} иконок, {sheet.size[0]}×{sheet.size[1]}")


if __name__ == "__main__":
    main()

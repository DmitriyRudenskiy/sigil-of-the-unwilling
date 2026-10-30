#!/usr/bin/env python3
"""Монтаж листов приёмки дорожек: строка = герой/действие, колонка = вариант.

Кадр берётся средний из сохранённых превью варианта (`v0N_032.png`), поэтому одна
картинка отвечает на вопрос «не упал ли герой / не потерял ли оружие», а лист
`sheet.png` остаётся доказательством по кадрам.
"""
import sys
import pathlib

from PIL import Image, ImageDraw

ROOT = pathlib.Path("scripts/hero_anim/out")
ACTIONS = ["idle", "walk", "attack", "hit", "turn"]
FRAME = "032"
CELL_H = 200


def montage(heroes, out):
    rows = []
    for h in heroes:
        for a in ACTIONS:
            cells = []
            n = 1
            while True:
                f = ROOT / h / a / f"v{n:02d}_{FRAME}.png"
                if not f.exists():
                    break
                cells.append((f"v{n}", Image.open(f).convert("RGB")))
                n += 1
            if cells:
                rows.append((f"{h}/{a}", cells))
    if not rows:
        print("нет кадров")
        return
    cols = max(len(c) for _, c in rows)
    pad, label = 8, 150
    th = max(im.height for _, c in rows for _, im in c)
    tw = max(im.width for _, c in rows for _, im in c)
    scale = CELL_H / th
    sheet = Image.new("RGB", (label + (int(tw * scale) + pad) * cols,
                              (CELL_H + pad) * len(rows)), (20, 20, 20))
    d = ImageDraw.Draw(sheet)
    for r, (name, cells) in enumerate(rows):
        d.text((6, r * (CELL_H + pad) + CELL_H // 2), name, fill=(255, 255, 0))
        for c, (tag, im) in enumerate(cells):
            tile = im.resize((int(im.width * scale), int(im.height * scale)))
            x = label + c * (int(tw * scale) + pad)
            sheet.paste(tile, (x, r * (CELL_H + pad)))
            d.text((x + 4, r * (CELL_H + pad) + 4), tag, fill=(255, 255, 0))
    sheet.save(out)
    print(f"{out}: {len(rows)} строк × {cols} вариантов")


if __name__ == "__main__":
    heroes = sys.argv[1].split(",")
    montage(heroes, sys.argv[2] if len(sys.argv) > 2 else "tmp/montage.png")

#!/usr/bin/env python3
"""Контактный лист всех принятых кадров (задача 6.17).

Один кадр = одна плитка 128×128 на шахматном фоне (альфа видна), подпись —
`персонаж поза кадр`. Лист собирается из манифестов, поэтому показывает и
статичные кадры (`generation-manifest.json`), и клипы (`clip-manifest.json`).

Лист — рабочий инструмент просмотра, пиксели в git не идут (D-185): файл лежит в
`artifacts/contact-sheet.jpg`, в репозитории остаётся этот инструмент.

    python3 battle-demo/tools/gen_contact_sheet.py [--char knight] [--tile 128]
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
GEN = ROOT / "artifacts/generation-manifest.json"
CLIPS = ROOT / "artifacts/clip-manifest.json"
OUT = ROOT / "artifacts/contact-sheet.jpg"
LABEL = 14


def checker(size: int) -> Image.Image:
    tile = Image.new("RGB", (size, size), (52, 52, 58))
    draw = ImageDraw.Draw(tile)
    step = size // 8
    for y in range(0, size, step * 2):
        for x in range(0, size, step * 2):
            draw.rectangle((x, y, x + step - 1, y + step - 1), fill=(38, 38, 44))
    return tile


def sources(char: str | None) -> list[tuple[str, str, Path]]:
    """(персонаж, подпись, файл) — статичные кадры и клипы одним списком."""
    rows = []
    for row in json.loads(GEN.read_text()):
        if char and row["character"] != char:
            continue
        rows.append((row["character"], f"{row['animation']} {row['frame']}",
                     ROOT.parent / row["path"]))
    for row in json.loads(CLIPS.read_text()):
        if char and row["char"] != char:
            continue
        for index, path in enumerate(row["subsampled"]):
            rows.append((row["char"], f"{row['anim']} клип {index + 1}", ROOT.parent / path))
    return rows


def sheet(sources_list: list[tuple[str, str, Path]], tile: int) -> Image.Image:
    columns = 12
    rows = -(-len(sources_list) // columns)
    page = Image.new("RGB", (columns * tile, rows * (tile + LABEL)), (20, 20, 24))
    draw = ImageDraw.Draw(page)
    board = checker(tile)
    for index, (character, caption, path) in enumerate(sources_list):
        if not path.exists():
            continue
        image = Image.open(path).convert("RGBA")
        image.thumbnail((tile, tile), Image.LANCZOS)
        x, y = (index % columns) * tile, (index // columns) * (tile + LABEL)
        page.paste(board, (x, y))
        page.paste(image, (x + (tile - image.width) // 2, y + (tile - image.height) // 2), image)
        draw.text((x + 2, y + tile + 2), f"{character} {caption}", fill=(220, 220, 220))
    return page


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--char")
    parser.add_argument("--tile", type=int, default=128)
    args = parser.parse_args()
    found = sources(args.char)
    sheet(found, args.tile).save(OUT, quality=82)
    print(json.dumps({"плиток": len(found), "tile": args.tile, "path": str(OUT.relative_to(ROOT.parent))},
                     ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

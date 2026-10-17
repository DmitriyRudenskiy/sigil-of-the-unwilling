#!/usr/bin/env python3
"""Оправка кадров к судейскому просмотру: строкой эталон | krea2 | ernie на юнита.

Нужна одному — агенту, который ставит STY и вердикт по похожеści кадра на
эталон. Строка на юнита, несколько юнитов на лист, чтобы один просмотр
закрывал четыре решения.

    judge_board.py -o /tmp/j.png IMG-073 IMG-074 IMG-075 IMG-076
"""
import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
LAB = ROOT / "image-clone"
MODELS = ("krea2", "ernie")
H = 420


def tiles(uid: str, frame: str) -> list[tuple[str, Image.Image]]:
    out = [("эталон", Image.open(LAB / "references" / "crops" / f"{uid}.png").convert("RGB"))]
    for m in MODELS:
        f = LAB / "attempts" / uid / f"{m}_{uid}_{frame}.webp"
        out.append((f"{m}_{frame}", Image.open(f).convert("RGB") if f.exists() else Image.new("RGB", (H, H), "red")))
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("ids", nargs="+")
    ap.add_argument("-o", "--out", default="/tmp/judge.png")
    ap.add_argument("-f", "--frame", default="v1", help="версия кадра, v1 у всех стадий")
    a = ap.parse_args()

    rows, w = [], 0
    for uid in a.ids:
        row = [(lab, im) for lab, im in tiles(uid, a.frame)]
        row = [(lab, im.resize((int(im.width * H / im.height), H))) for lab, im in row]
        w = max(w, sum(im.width for _, im in row) + 12 * len(row))
        rows.append((uid, row))
    gap, top = 14, 26
    board = Image.new("RGB", (w + gap, len(rows) * (H + top) + gap), (245, 245, 245))
    d = ImageDraw.Draw(board)
    for r, (uid, row) in enumerate(rows):
        x, y = gap, gap + r * (H + top)
        d.text((x, y), uid, fill=(0, 0, 0))
        y += top
        for lab, im in row:
            d.text((x + 2, y - 16), lab, fill=(0, 0, 0))
            board.paste(im, (x, y))
            x += im.width + 12
    board.save(a.out, quality=90)
    print(f"{a.out}: {len(a.ids)} юнитов, {board.size}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

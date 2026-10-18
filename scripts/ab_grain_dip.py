#!/usr/bin/env python3
"""A/B полоски зерна на переходе биомов — «видно на масштабе, на котором играют».

T-138: машина сказала, что в полосе пера зерно проседает до 0.80× шумового поля
(контроль 0.98×). На «цепляется ли глаз» она не отвечает, и отвечать не должна: для
этого нужен кадр, снятый на игровом зуме, и пара «как есть / с инжектом зерна». Кадр
даёт `tools/map_shot.gd --zoom=` (ZOOM_LEVELS игры: 0.5…2.25, дефолт 1.0), пару даёт
`GRAIN_INJECT` в `gen_map_art.py`.

Полоса монтируется по общему ребру самой сильной в кадре пары биомов: окно 3× ширины
пера поперёк ребра, чтобы глаз видел и бregа, и яму. Ряд 1 — 1:1 (что игрок видит на
экране), ряд 2 — ×3 nearest (деталь без интерполяции).

  python3 scripts/ab_grain_dip.py A.png B.png --out ab.png --label "zoom 0.5"
"""
from __future__ import annotations

import argparse
import json
import math
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from measure_decal_seam import NEIGH_EVEN, NEIGH_ODD, de76, tone_lab  # noqa: E402

NEIGH = {"even": NEIGH_EVEN, "odd": NEIGH_ODD}


def edges(geo: dict) -> list[tuple[str, str, int, int, float]]:
    """Общие рёбра разнородных соседей: (биомA, биомB, x, y, контраст) — x,y середина ребра."""
    cells = geo["cells"]
    img = np.asarray(Image.open(geo["__shot"]).convert("RGB"), dtype=np.float64)
    means = {}
    for biome in sorted({v[2] for v in cells.values()}):
        px = [img[max(0, v[1] - 12):v[1] + 12, max(0, v[0] - 12):v[0] + 12].reshape(-1, 3)
              for v in cells.values() if v[2] == biome]
        means[biome] = np.concatenate(px).mean(0)
    out = []
    for key, val in cells.items():
        cx, cy = map(int, key.split(","))
        for d in NEIGH["odd" if cy % 2 else "even"]:
            nb = cells.get(f"{cx + d[0]},{cy + d[1]}")
            if not nb or val[2] == nb[2]:
                continue
            c = de76(tone_lab(tuple(means[val[2]])), tone_lab(tuple(means[nb[2]])))
            out.append((val[2], nb[2], (val[0] + nb[0]) // 2, (val[1] + nb[1]) // 2, c))
    return sorted(out, key=lambda e: -e[4])


def strip(shot: str, e, half: int, scale: int = 1) -> Image.Image:
    """Окно 2×half поперёк ребра, центрированное на середине ребра (там и живёт перо)."""
    img = Image.open(shot).convert("RGB")
    x, y = int(e[2]), int(e[3])
    box = (max(0, x - half), max(0, y - half), min(img.width, x + half), min(img.height, y + half))
    crop = img.crop(box)
    if scale != 1:
        crop = crop.resize((crop.width * scale, crop.height * scale), Image.NEAREST)
    return crop


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("a", help="кадр «как есть»")
    ap.add_argument("b", help="кадр-кандидат")
    ap.add_argument("--out", required=True)
    ap.add_argument("--label", default="")
    ap.add_argument("--pairs", type=int, default=3, help="сколько рёбер в полосу")
    ap.add_argument("--depth", type=int, default=0, help="полуокно поперёк ребра, px (0 = 3×FEATHER-окно кадра)")
    ap.add_argument("--skip", default="", help="биомы, чьи рёбра не брать (по умолчанию пусто)")
    a = ap.parse_args()
    skip = {s for s in a.skip.split(",") if s}

    ga = json.load(open(f"{a.a}.cells.json", encoding="utf-8"))
    ga["__shot"] = a.a
    gb = json.load(open(f"{a.b}.cells.json", encoding="utf-8"))
    half = a.depth or max(24, int(3 * 0.22 * ga["tile"][0]))
    picked = [e for e in edges(ga) if e[0] not in skip and e[1] not in skip][: a.pairs]
    rows = []
    for scale in (1, 3):
        tiles = []
        for e in picked:
            ca, cb = strip(a.a, e, half, scale), strip(a.b, e, half, scale)
            w = min(ca.width, cb.width)
            tiles.append((ca, cb, e, w))
        h = max(t[0].height for t in tiles)
        row = Image.new("RGB", (sum(t[3] + 8 for t in tiles) + 8, h), (24, 24, 24))
        x = 8
        for ca, cb, e, w in tiles:
            row.paste(ca, (x, 0))
            x += w + 4
            row.paste(cb, (x, 0))
            x += w + 8
        rows.append((row, h))
    band = 18 if a.label else 0
    sheet = Image.new("RGB", (rows[0][0].width, sum(r[1] for r in rows) + 26 + band), (12, 12, 12))
    y = 0
    for i, (row, h) in enumerate(rows):
        sheet.paste(row, (0, y))
        y += h + 4
    if a.label:
        from PIL import ImageDraw
        ImageDraw.Draw(sheet).text((6, y + 2), f"{a.label} · слева «как есть», справа кандидат · "
                                    f"ряды: 1:1 (как на экране) и ×3 · рёбра: "
                                    + ", ".join(f"{e[0]}↔{e[1]} ΔE {e[4]:.0f}" for e in picked),
                                    fill=(230, 230, 230))
    sheet.save(a.out)
    print(f"{a.out}: {sheet.width}x{sheet.height} · рёбра " +
          ", ".join(f"{e[0]}↔{e[1]} ΔE {e[4]:.0f} @({e[2]},{e[3]})" for e in picked))
    return 0


if __name__ == "__main__":
    sys.exit(main())

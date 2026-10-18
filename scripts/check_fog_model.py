#!/usr/bin/env python3
"""Модель тумана: почему у AC 8 нет пиксельного носителя (круг 14).

Туман в map_renderer.gd — не полупрозрачный слой, а замена тайла
(apply_fog -> set_cell(FOG_SOURCE_ID)). Здесь это меряется, а не утверждается:
сколько подложки остаётся в затемнённом пикселе и что при этом может мерить кадр.

  python3 scripts/check_fog_model.py <fog=1.png> <fog=0.png>   # рядом лежит fog=1.png.cells.json
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
from make_fog_transition_carrier import cells_of, feather_band, label_map, pitch


def box(a, k):
    c = np.cumsum(np.cumsum(np.pad(a, ((1, 0), (1, 0))), 0), 1)
    return c[k:, k:] - c[:-k, k:] - c[k:, :-k] + c[:-k, :-k]


def lstd(a, k=9):
    mu = box(a, k) / (k * k)
    return np.sqrt(np.clip(box(a * a, k) / (k * k) - mu * mu, 0, None))


def main():
    on = np.asarray(Image.open(sys.argv[1]).convert("L"), dtype=np.float64)
    off = np.asarray(Image.open(sys.argv[2]).convert("L"), dtype=np.float64)
    fogged = np.abs(on - off) >= 1
    o, b = on[fogged], off[fogged]
    slope, intercept = np.polyfit(b, o, 1)
    print(f"модель тумана:   on = {slope:.3f}·off + {intercept:.1f}   "
          f"R² = {1 - (o - (slope * b + intercept)).var() / o.var():.3f}")
    print(f"подложка даёт {slope:.1%} значения затемнённого пикселя; "
          f"площадь под туманом {fogged.mean():.1%}")
    t_on, t_off = lstd(on), lstd(off)
    f = fogged[: t_on.shape[0], : t_on.shape[1]]
    print(f"текстура (локальная дисперсия, k=9): под туманом {t_on[f].mean():.2f} | "
          f"на земле {t_on[~f].mean():.2f} | та же область без тумана {t_off[f].mean():.2f}")

    geo = cells_of(Path(sys.argv[1]))
    tile = pitch(geo)
    h, w = on.shape
    band = feather_band(label_map(geo, tile, (h, w)), tile)
    low = np.asarray(Image.fromarray(off.astype(np.uint8)).filter(ImageFilter.GaussianBlur(6)),
                     dtype=np.float64)
    grad = np.zeros((h, w))
    grad[:, :-1] += np.abs(np.diff(low, axis=1))
    grad[:-1, :] += np.abs(np.diff(low, axis=0))
    rng = np.random.default_rng(3)
    target = int(band.sum())
    nulls = []
    for _ in range(12):
        m = np.zeros((h, w), bool)
        while m.sum() < target:
            y, x = int(rng.integers(0, h)), int(rng.integers(0, w))
            m[max(0, y - tile):y + tile, max(0, x - tile):x + tile] = True
        nulls.append(float(grad[m].mean()))
    sig = (grad[band].mean() - np.median(nulls)) / (np.std(nulls) or 1)
    print(f"видимость перехода (НЧ-градиент fog=0): в ленте пера {grad[band].mean():.2f} | "
          f"вне {grad[~band].mean():.2f} | ноль {np.median(nulls):.2f} "
          f"({min(nulls):.2f}…{max(nulls):.2f}) → {sig:+.2f} σ")
    print("вывод: кадр не мерит «декаль под туманом» (там нет подложки); лента мерит "
          "видимость перехода — это AC 7.")


if __name__ == "__main__":
    main()

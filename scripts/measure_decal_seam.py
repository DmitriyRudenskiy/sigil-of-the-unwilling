#!/usr/bin/env python3
"""Замер тонального шага «декаль перехода vs база соседней клетки» (T-136).

Две меры, обе — ΔE76 до среднего Lab по альфе:

1. **Рампа вариантов базы** — шаг между четырьмя вариантами одного биома. Это тот
   член, на который указывал тикет: декаль печатается материалом `mat_<biome>_0`,
   а сосед стоит любым из четырёх.
2. **Линия стыка** — декаль стороны `e` (полоса у правого края клетки) против левого
   края базы соседа: те два ряда пикселей, которые в кадре стоят вплотную. Плюс L*
   обоих, чтобы видеть направление шага (декаль темнее базы или светлее).

Порог «не читается как граница биома» — `frame.min_biome_contrast_de`. Мера покадровая
по атласу, геометрию сторон гекса (кроме восток/запад) не учитывает.

    python3 scripts/measure_decal_seam.py
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from measure_palette_band import de76, tone_lab  # noqa: E402  (общая метрика палитры §4.6)
from check_map_art import NEIGH_EVEN, NEIGH_ODD  # noqa: E402  (соседи offset-рядов)

# Порядок биомов = TileAtlas.BIOME_NAMES: по нему paint_transitions решает, кто
# из пары красит переход (младший красит в свою клетку материал старшего).
BIOME_ORDER = ["grass", "sand", "snow", "swamp", "water", "rock", "mud", "road"]

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ATLAS = os.path.join(ROOT, "game/assets/tiles")
GATES = os.path.join(ROOT, "game/data/config/map_art_gates.json")
INSET = 0.30     # у базы отбрасываем край клетки: на границе уже чужой тайл
BAND = 0.12      # доля ширины полосы у линии стыка


def _mean_lab(px: np.ndarray):
    """Среднее Lab по альфе: полупрозрачный край декаля — как раз то, что на стыке."""
    a = px[..., 3].astype(np.float64) / 255.0
    if a.sum() <= 0:
        return None
    rgb = (px[..., :3].astype(np.float64) * a[..., None]).sum((0, 1)) / a.sum()
    return tone_lab(tuple(rgb))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--atlas", default=ATLAS)
    ap.add_argument("--shot", default="", help="снимок карты (рядом лежит .cells.json)")
    ap.add_argument("--t", type=float, default=0.50,
                    help="доля пути к центру соседней клетки, где брать полосу")
    a = ap.parse_args()
    with open(GATES, encoding="utf-8") as f:
        threshold = float(json.load(f)["frame"]["min_biome_contrast_de"])
    if a.shot:
        return shot_seam(a.shot, threshold, a.t)
    with open(os.path.join(a.atlas, "world_map_atlas.json"), encoding="utf-8") as f:
        man = json.load(f)
    img = np.asarray(Image.open(os.path.join(a.atlas, man["image"])).convert("RGBA"),
                     dtype=np.uint8)
    cells, t = man["cells"], int(man["tile"])

    def crop(cell, x0, y0, x1, y1) -> np.ndarray:
        x, y = cell["atlas"][0] * t, cell["atlas"][1] * t
        return img[y + int(y0 * t):y + int(y1 * t), x + int(x0 * t):x + int(x1 * t)]

    def pick(kind, biome, **want):
        out = [c for c in cells if c["kind"] == kind and c["biome"] == biome
               and all(c.get(k) == v for k, v in want.items())]
        return out[0] if out else None

    print(f"порог «не читается как граница биома»: ΔE ≥ {threshold:.1f}\n")
    print(f"{'биом':7} {'рампа базы':>10} {'стык v0':>8} {'стык v3':>8} "
          f"{'L* базы':>8} {'L* декаля':>10}")
    for biome in sorted({c["biome"] for c in cells}):
        bases = [pick("base", biome, variant=v) for v in range(4)]
        lb = [_mean_lab(crop(b, INSET / 2, INSET / 2, 1 - INSET / 2, 1 - INSET / 2))
              for b in bases]
        ramp = max(de76(a, b) for a in lb for b in lb)
        edge = pick("edge", biome, side="e")
        le = _mean_lab(crop(edge, 1 - BAND, 0, 1, 1))
        left = [_mean_lab(crop(b, 0, 0, BAND, 1)) for b in bases]
        l_base = _mean_lab(crop(bases[0], 0.4, 0.4, 0.6, 0.6))[0]
        l_edge = le[0]
        print(f"{biome:7} {ramp:10.1f} {de76(le, left[0]):8.1f} {de76(le, left[3]):8.1f} "
              f"{l_base:8.1f} {l_edge:10.1f}")
    print("\nрампа базы = шаг между самыми разными вариантами одного биома (член, который "
          "тикет считал главным);\nстык v0/v3 = шаг декаля к левому краю базы 0-го/3-го "
          "варианта — если оба большие и близкие, виноват не вариант.")
    return 0


def shot_seam(shot: str, threshold: float, t: float = 0.50) -> int:
    """То же — по снимку карты: где декаль реально наедает чужую клетку.

    Декаль биома B лежит внутри клетки биома A (map_renderer.paint_transitions),
    поэтому полоса берётся у общего ребра, со стороны A, и сравнивается со средним
    обоих биомов: с чужим она обязана совпадать (иначе — чужеродная линия), со своим
    отличаться вправе (это и есть переход)."""
    geo = json.load(open(f"{shot}.cells.json", encoding="utf-8"))
    tile = int(geo["tile"][0])
    cells = geo["cells"]
    img = np.asarray(Image.open(shot).convert("RGB"), dtype=np.float64)
    means, strips = {}, []
    for biome in sorted({v[2] for v in cells.values()}):
        px = [img[max(0, v[1] - 12):v[1] + 12, max(0, v[0] - 12):v[0] + 12].reshape(-1, 3)
              for v in cells.values() if v[2] == biome]
        means[biome] = np.concatenate(px).mean(0)
    for key, val in cells.items():
        cx, cy = map(int, key.split(","))
        for d in (NEIGH_ODD if cy % 2 else NEIGH_EVEN):
            nb = cells.get(f"{cx + d[0]},{cy + d[1]}")
            if not nb or val[2] == nb[2]:
                continue
            a, b = val[2], nb[2]                       # декаль b лежит внутри клетки a
            if BIOME_ORDER.index(b) <= BIOME_ORDER.index(a):
                continue                    # красит сосед, не эта клетка
            mx, my = int(val[0] + t * (nb[0] - val[0])), int(val[1] + t * (nb[1] - val[1]))
            patch = img[max(0, my - 4):my + 4, max(0, mx - 4):mx + 4].reshape(-1, 3).mean(0)
            strips.append((de76(tone_lab(tuple(patch)), tone_lab(tuple(means[b]))),
                           de76(tone_lab(tuple(patch)), tone_lab(tuple(means[a]))), a, b))
    if not strips:
        print("в кадре нет пар биомов, где декаль вообще рисуется")
        return 0
    worst = max(strips, key=lambda s: s[0])
    print(f"пар перехода: {len(strips)}; медиана ΔE(декаль↔свой биом) = "
          f"{sorted(s[0] for s in strips)[len(strips)//2]:.1f}, "
          f"медиана ΔE(декаль↔клетка, в которую он наедает) = "
          f"{sorted(s[1] for s in strips)[len(strips)//2]:.1f}")
    print(f"худший ΔE(декаль↔свой биом) = {worst[0]:.1f} ({worst[2]}→{worst[3]}), "
          f"порог {threshold:.1f} → {'FAIL' if worst[0] > threshold else 'PASS'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

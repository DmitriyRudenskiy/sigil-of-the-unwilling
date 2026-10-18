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
import json
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from measure_palette_band import de76, tone_lab  # noqa: E402  (общая метрика палитры §4.6)

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
    with open(os.path.join(ATLAS, "world_map_atlas.json"), encoding="utf-8") as f:
        man = json.load(f)
    with open(GATES, encoding="utf-8") as f:
        threshold = float(json.load(f)["frame"]["min_biome_contrast_de"])
    img = np.asarray(Image.open(os.path.join(ATLAS, man["image"])).convert("RGBA"),
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


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Остаток T-143: пятно (`mottle`) печётся в тайл, поэтому его тёмная фаза обрывается
на ребре клетки — глаз собирает это в прямоугольные заплаты.

Гипотеза проверяется без пересъёмки: у низких частот кадра градиент должен быть
системно выше **на рёбрах клеток**, чем внутри клетки, при одном и том же содержимом
(тот же кадр, та же текстура; меняется только расстояние пикселя до границы клетки).
Если градиент от расстояния не зависит — прямоугольники в кадре не от разрыва поля.

ВЕРДИКТ (19.10, атлас 47fa6027, кадр variant-tone-t143, окна 120…480 px): разрыва нет —
|∇| на рёбрах против внутренности 0.99× без блюра и 1.05…1.07× при σ 1…6. Прямоугольники
в кадре — не разрыв поля; что именно остаётся (масштаб фактуры вариантов) — [[BASELINE]],
«Остаток 11.3». Мера здесь затем, чтобы эту ветку не проверяли второй раз.
Полоса считается разностью соседних сглаживаний; std σ4-сглаженного изображения полосой
не является (там большой градиент самого тайла — первая версия меры на этом вралялась).

  python3 scripts/measure_mottle_cut.py docs/reference/map-baseline/variant-tone-t143.png

Рёбра — гребень диаграммы Вороного центров клеток (`*.cells.json`, их печатает
`scripts/check_map_art.py --shot`): пиксель на ребре, где расстояния до двух ближайших
центров различаются меньше чем на `EDGE` пикселей.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter

sys.path.insert(0, str(Path(__file__).parent))
from measure_variant_seam import lab  # noqa: E402  (то же Lab, что в остальных замерах)

EDGE = 3.0


def boundary_distance(l: np.ndarray, centers: np.ndarray) -> np.ndarray:
    """Расстояние пикселя до ближайшего ребра Вороного, в пикселях."""
    h, w = l.shape
    yy, xx = np.mgrid[0:h, 0:w]
    pts = np.stack([yy.ravel(), xx.ravel()], 1).astype(np.float64)
    gap = np.empty(len(pts))
    for i in range(0, len(pts), 200_000):
        chunk = pts[i:i + 200_000]
        d = np.sort(((chunk[:, None, :] - centers[None, :, :]) ** 2).sum(-1), axis=1)[:, :2]
        gap[i:i + 200_000] = np.sqrt(d[:, 1]) - np.sqrt(d[:, 0])
    return gap.reshape(h, w)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("shot", nargs="?",
                    default="docs/reference/map-baseline/variant-tone-t143.png")
    a = ap.parse_args()
    meta = json.loads(Path(f"{a.shot}.cells.json").read_text())
    cells = meta["cells"]
    centers = np.array([[v[1], v[0]] for v in cells.values()], dtype=float)
    l = lab(Image.open(a.shot))[..., 0]

    # Низкие частоты: то, что глаз читает как «тон пятна», а не как зерно.
    low = gaussian_filter(l, 6.0)
    gy, gx = np.gradient(low)
    grad = np.hypot(gx, gy)

    gap = boundary_distance(l, centers)
    print(f"кадр {a.shot}: {len(cells)} клеток, рёбра Вороного, порог {EDGE} px")
    print(f"{'полоса от ребра':<20}{'медиана |∇| низких':>20}{'p90':>10}{'n':>12}")
    bands = [(0.0, EDGE, "на ребре"), (EDGE, 8.0, "1–8 px"),
             (8.0, 16.0, "8–16 px"), (16.0, 1e9, "внутри клетки")]
    med = {}
    for lo, hi, name in bands:
        m = (gap >= lo) & (gap < hi)
        if m.sum() < 500:
            continue
        med[name] = float(np.median(grad[m]))
        print(f"{name:<20}{med[name]:>20.3f}{np.percentile(grad[m], 90):>10.3f}"
              f"{int(m.sum()):>12}")
    if "на ребре" in med and "внутри клетки" in med:
        inside = med["внутри клетки"] or 1e-9
        print(f"\nотношение ребро/внутренность: {med['на ребре'] / inside:.2f}×")
        print("≈1.0 — разрыва поля на рёбрах нет; >1.2 — пятно обрывается на границе "
              "клетки, прямоугольники рисует именно он")
    return 0


if __name__ == "__main__":
    sys.exit(main())

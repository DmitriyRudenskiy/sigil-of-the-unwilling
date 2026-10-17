#!/usr/bin/env python3
"""Замер формулы «тёмная рама — яркое содержимое» (D-184) по файлу референса.

Формула говорит: рама (панели, хром, кнопки) темнее содержимого (поле, карта, бой).
Проверяется числом, а не мнением: файл режется геометрически — внешнее кольцо
(ширина = FRAME_FRAC от меньшей стороны) против внутреннего поля — и для каждой
части считается k-means-полоса (та же мера, что в [[13-art-bible]] §4.6 и в
`measure_palette_band.py`: 8 кластеров, почти-белый фон исключён, lum — WCAG,
sat — HSL).

Срез **геометрический**, а не семантический: кольцо — это прокси хрома интерфейса,
а не его точная маска. Именно поэтому прокси воспроизводим: один и тот же файл
даёт одно и то же число, и сверка «новый канон против старого» не зависит от того,
что автор замера посчитал «рамкой».

Вердикт по паре чисел:
  ПОДТВЕРЖДЕНО  — lum(поля) - lum(кольца) >= GAP
  НЕ РАЗЛИЧИМЫ  — 0 <= разница < GAP
  ИНВЕРСИЯ      — разница < 0 (кольцо светлее поля)

Запуск:
  python3 scripts/measure_frame_vs_content.py reference/*.jpeg reference/*.png
"""

from __future__ import annotations

import argparse
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from measure_palette_band import kmeans, lum, sample, sat  # noqa: E402

FRAME_FRAC = 0.10     # ширина внешнего кольца, доля меньшей стороны кадра
SAMPLE_N = 40_000     # пикселей на часть кадра
GAP = 0.15            # минимальный разрыв lum, при котором рама считается темнее поля
MIN_SHARE = 0.05      # класты тоньше этого не входят в агрегат (шум, не полоса)


def parts(path: str, frac: float = FRAME_FRAC) -> tuple[np.ndarray, np.ndarray] | None:
    """Пиксели внешнего кольца и внутреннего поля: (frame, content), (N,3) uint8."""
    im = Image.open(path).convert("RGB")
    a = np.asarray(im).astype(np.float64) / 255.0
    h, w = a.shape[:2]
    m = int(round(min(h, w) * frac))
    if m < 1 or h <= 2 * m or w <= 2 * m:
        return None
    keep = lum(a) <= 0.92                      # почти-белый фон кадра не участвует
    ring = np.ones((h, w), dtype=bool)
    ring[m:h - m, m:w - m] = False
    core = ~ring
    ring &= keep
    core &= keep
    out = []
    for mask in (ring, core):
        px = (a[mask] * 255).astype(np.uint8)
        out.append(sample(px, SAMPLE_N) if len(px) else px)
    if not len(out[0]) or not len(out[1]):
        return None
    return out[0], out[1]


def band(px: np.ndarray) -> tuple[float, float, list[str]]:
    """(lum, sat, тона) агрегированной полосы части кадра — вес по доле кластера."""
    clusters = [c for c in kmeans(px, 8) if c[1] >= MIN_SHARE]
    if not clusters:
        clusters = kmeans(px, 8)[:3]
    total = sum(c[1] for c in clusters)
    wlum = sum(c[2] * c[1] for c in clusters) / total
    wsat = sum(c[3] * c[1] for c in clusters) / total
    tones = ["{} {:.2f}/{:.2f}".format("#{0:02x}{1:02x}{2:02x}".format(*c[0]), c[2], c[3])
             for c in clusters[:3]]
    return wlum, wsat, tones


def verdict(frame_lum: float, content_lum: float) -> str:
    gap = content_lum - frame_lum
    if gap >= GAP:
        return "ПОДТВЕРЖДЕНО (рама темнее на {:.2f})".format(gap)
    if gap >= 0:
        return "НЕ РАЗЛИЧИМЫ (разрыв {:.2f} < {:.2f})".format(gap, GAP)
    return "ИНВЕРСИЯ (рама светлее на {:.2f})".format(-gap)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="+")
    ap.add_argument("--frac", type=float, default=FRAME_FRAC, help="доля меньшей стороны в кольцо")
    args = ap.parse_args()
    for path in args.files:
        if not os.path.isfile(path):
            print("MISSING  {}".format(path))
            continue
        got = parts(path, args.frac)
        if got is None:
            print("SKIP     {} (кадр слишком мал для кольца)".format(os.path.basename(path)))
            continue
        f_px, c_px = got
        fl, fs, ft = band(f_px)
        cl, cs, ct = band(c_px)
        print("{}".format(os.path.basename(path)))
        print("  кольцо  lum {:.2f}  sat {:.2f}   {}".format(fl, fs, ", ".join(ft)))
        print("  поле    lum {:.2f}  sat {:.2f}   {}".format(cl, cs, ", ".join(ct)))
        print("  вердикт: {}".format(verdict(fl, cl)))
    return 0


if __name__ == "__main__":
    sys.exit(main())

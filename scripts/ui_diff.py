#!/usr/bin/env python3
"""Попиксельная дельта двух кадров ОДНОГО экрана — по ячейкам адресной сетки.

Валидное применение: «до/после» одной и той же сцены в одном размере. Хелпер съёмки
(`game/tests/mcp/capture.py`) пинит канонический размер именно для этого, а разные
размеры — недействительный снимок, здесь он тоже отказ, а не тихий ресайз.

Мера — сигнал, не вердикт (D-228): между макетом и живым экраном она считает
сходство шрифтов, палитры и контента, которого в игре нет, и пустой серый кадр
обгоняет настоящий. Поэтому здесь нет ни PASS, ни порога остановки: инструмент
отвечает на вопрос «какие ячейки вообще сдвинулись и насколько», а решение о
приёмке экрана — разбор кадра глазом (AGENTS.md «UX-review машинным зрением»).

  python3 scripts/ui_diff.py --before /path/before.png --after /path/after.png \
      --cols 10 --rows 10 --out-dir /tmp/diff1

Выход: heatmap.png (красным на «after»), report.json (каждая ячейка: bbox, %
изменённых пикселей, средний сдвиг, SSIM), таблица худших ячеек в stdout.
"""
from __future__ import annotations

import argparse
import json
import os
import string
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ui_grid import cell_bbox  # та же математика сетки, что и у разметки кадров

try:
    from skimage.metrics import structural_similarity as _skimage_ssim

    HAVE_SKIMAGE = True
except ImportError:
    HAVE_SKIMAGE = False

# Порог «пиксел сдвинулся», 0..255. Ниже — шум сжатия и дребезжание субпикселя.
PIXEL_DELTA = 8


def cell_name(col: int, row: int) -> str:
    return f"{string.ascii_uppercase[col] if col < 26 else col + 1}{row + 1}"

def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Дельта двух кадров по ячейкам сетки.")
    p.add_argument("--before", required=True)
    p.add_argument("--after", required=True)
    p.add_argument("--cols", type=int, default=10)
    p.add_argument("--rows", type=int, default=10)
    p.add_argument("--out-dir", default="/tmp/ui-diff")
    p.add_argument("--min-change", type=float, default=0.5,
                   help="% изменённых пикселей в ячейке, ниже которой ячейка считается нетронутой")
    p.add_argument("--cell", default=None, metavar="A1",
                   help="интересует одна ячейка — напечатать только её")
    a = p.parse_args()
    if a.cols < 1 or a.rows < 1:
        p.error("--cols/--rows обязаны быть >= 1")
    return a


def gray(path: str) -> np.ndarray:
    return np.asarray(Image.open(path).convert("L"), dtype=np.float32)


def _box_blur(arr: np.ndarray, win: int) -> np.ndarray:
    """Скользящее среднее через интегральную картинку (без scipy).

    Префиксные суммы считаются по ДОПОЛНЕННОМУ массиву, поэтому и таблица префиксов
    обязана быть размера padded+1: при arr.shape префикс обрезается до индексов,
    срез `c[k:k+h]` недобирает строк, и присваивание падает ValueError (замер
    2026-10-26 на вендорском оригинале: «could not broadcast (366,646) into (360,640)»).
    """
    pad = win // 2
    padded = np.pad(arr, pad, mode="edge")
    h, w = arr.shape
    c = np.zeros((padded.shape[0] + 1, padded.shape[1] + 1), dtype=np.float64)
    c[1:, 1:] = np.cumsum(np.cumsum(padded, axis=0), axis=1)
    k = win
    s = (c[k:k + h, k:k + w] - c[0:h, k:k + w] - c[k:k + h, 0:w] + c[0:h, 0:w])
    return (s / (k * k)).astype(np.float32)


def fallback_ssim(a: np.ndarray, b: np.ndarray) -> float:
    """SSIM на сером, окном 7; вниз по шагу — только чтобы не считать по 2 Мп."""
    if a.size == 0:
        return 1.0
    scale = max(1, int(max(a.shape) / 512))
    if scale > 1:
        a, b = a[::scale, ::scale], b[::scale, ::scale]
    win = 7
    if min(a.shape) < win + 2:
        return float(1.0 - np.mean(np.abs(a - b)) / 255.0)
    c1, c2 = (0.01 * 255) ** 2, (0.03 * 255) ** 2
    mua, mub = _box_blur(a, win), _box_blur(b, win)
    va = _box_blur(a * a, win) - mua * mua
    vb = _box_blur(b * b, win) - mub * mub
    cov = _box_blur(a * b, win) - mua * mub
    m = ((2 * mua * mub + c1) * (2 * cov + c2)) / ((mua ** 2 + mub ** 2 + c1) * (va + vb + c2))
    return float(np.clip(m.mean(), -1.0, 1.0))


def ssim(a: np.ndarray, b: np.ndarray) -> float:
    if HAVE_SKIMAGE:
        try:
            return float(_skimage_ssim(a, b, data_range=255.0))
        except (TypeError, ValueError):
            pass
    return fallback_ssim(a, b)


def save_heatmap(after_path: str, diff: np.ndarray, path: str) -> None:
    base = np.asarray(Image.open(after_path).convert("RGB"), dtype=np.float32)
    alpha = np.clip(diff / 128.0, 0.0, 0.85)
    red = np.zeros_like(base)
    red[..., 0] = 220.0
    out = base * (1 - alpha[..., None]) + red * alpha[..., None]
    Image.fromarray(out.astype(np.uint8)).save(path)


def main() -> int:
    a = parse_args()
    before, after = Image.open(a.before).convert("RGB"), Image.open(a.after).convert("RGB")
    if before.size != after.size:
        print(f"[ui_diff] ОТКАЗ: размер кадров разный: {before.size} vs {after.size}. "
              "Ресайз подменяет меру: сравнивать можно только кадры одного канона "
              "(game/tests/mcp/capture.py: verify_frame).", file=sys.stderr)
        return 2

    g0, g1 = gray(a.before), gray(a.after)
    for name, g in (("before", g0), ("after", g1)):
        if float(g.mean()) < 3.0:
            print(f"[ui_diff] ОТКАЗ: кадр {name} почти чёрный (средняя яркость < 3) — "
                  "съёмка шла без дисплея (--headless → dummy rasterizer).", file=sys.stderr)
            return 2

    diff = np.abs(g0 - g1)
    changed = diff > PIXEL_DELTA
    w, h = after.size
    cells = []
    for j in range(a.rows):
        for i in range(a.cols):
            x0, y0, bw, bh = cell_bbox(after.size, a.cols, a.rows, i, j)
            x1, y1 = x0 + bw, y0 + bh
            d, c = diff[y0:y1, x0:x1], changed[y0:y1, x0:x1]
            pct = float(c.mean() * 100.0)
            cells.append({
                "cell": cell_name(i, j),
                "bbox": [x0, y0, bw, bh],
                "changed_pct": round(pct, 2),
                "mean_delta": round(float(d.mean()), 2),
                "ssim": round(ssim(g0[y0:y1, x0:x1], g1[y0:y1, x0:x1]), 4),
                "touched": pct >= a.min_change,
            })

    os.makedirs(a.out_dir, exist_ok=True)
    heatmap = os.path.join(a.out_dir, "heatmap.png")
    report = os.path.join(a.out_dir, "report.json")
    save_heatmap(a.after, diff, heatmap)

    touched = [c["cell"] for c in cells if c["touched"]]
    payload = {
        "before": os.path.abspath(a.before),
        "after": os.path.abspath(a.after),
        "size": [w, h],
        "grid": [a.cols, a.rows],
        "engine": "skimage-ssim" if HAVE_SKIMAGE else "fallback-ssim",
        "pixel_delta": PIXEL_DELTA,
        "min_change_pct": a.min_change,
        "overall_changed_pct": round(float(changed.mean() * 100.0), 2),
        "overall_ssim": round(ssim(g0, g1), 4),
        "touched_cells": touched,
        "cells": cells,
    }
    with open(report, "w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2)

    print(f"[ui_diff] движок: {payload['engine']} | кадров: {w}×{h} | сетка {a.cols}×{a.rows}")
    print(f"[ui_diff] всего изменённых пикселей: {payload['overall_changed_pct']}% "
          f"| SSIM целиком: {payload['overall_ssim']}")
    rows = [c for c in cells if (a.cell is None or c["cell"] == a.cell.upper())]
    if a.cell is not None:
        rows = rows[:1]
    else:
        rows = sorted(cells, key=lambda c: -c["changed_pct"])[:10]
    print("[ui_diff] ячейки (bbox x,y,w,h):")
    for c in rows:
        print(f"    {c['cell']:>4}  {c['changed_pct']:>6.2f}%  Δ{c['mean_delta']:>6.2f}  "
              f"ssim {c['ssim']:.4f}  {c['bbox']}{'  ← тронута' if c['touched'] else ''}")
    print(f"[ui_diff] heatmap -> {heatmap}")
    print(f"[ui_diff] report  -> {report}")
    shown = touched[:20]
    more = f" …и ещё {len(touched) - len(shown)} (полный список — в report.json)" if len(touched) > len(shown) else ""
    print(f"[ui_diff] ТРОНУТЫЕ ЯЧЕЙКИ: {', '.join(shown) if shown else 'нет'}{more}")
    print("[ui_diff] памятка: это дельта, а не приёмка. Вердикт — разбор кадра глазом; "
          "между макетом и игрой пиксельная мера не вердикт (D-228).")
    return 0


if __name__ == "__main__":
    sys.exit(main())

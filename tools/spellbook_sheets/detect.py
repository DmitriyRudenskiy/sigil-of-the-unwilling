#!/usr/bin/env python3
"""Детекция 12 иллюстраций на развороте и геометрия кропа.

Сетка даёт адрес, SAM даёт бокс: маски SAM 3.1 (текстовый промпт) раскладываются
по ячейкам 4×3, которые восстанавливаются по разрывам центров масок — ни границ
страницы, ни ориентации разворота не нужно. В каждую ячейку идёт самая большая
попавшая в неё маска; это же заменяет слияние разрезанного объекта.

Алгоритм — перенос прототипа, замеренного на всех 22 листах пула (22/22 режим
`sam`, пустых ячеек 0): openspec/changes/spellbook-icon-sheets/qc/.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

VISIONFLOW = "/Users/user/PycharmProjects/VisionFlow"
CHECKPOINT = f"{VISIONFLOW}/models/sam3.1_multiplex.pt"
PROMPT = "illustration"
MIN_FRAC = 0.35   # минимальная доля площади листа у маски, %
PAD = 0.04        # расширение бокса под мягкий край (дымка, лучи), доля стороны
COLS, ROWS = 4, 3


def _bbox(mask):
    ys, xs = np.nonzero(mask)
    return [int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1, int(mask.sum())]


def _cuts(values, k):
    """k границ сетки по k крупнейшим разрывам отсортированных центров."""
    v = np.sort(np.asarray(values, dtype=float))
    idx = np.argsort(np.diff(v))[::-1][:k]
    return sorted((v[i] + v[i + 1]) / 2 for i in idx)


def _grid_boxes(w, h):
    x0, y0, x1, y1 = int(.06 * w), int(.10 * h), int(.94 * w), int(.90 * h)
    cw, ch = (x1 - x0) / COLS, (y1 - y0) / ROWS
    return [[int(x0 + q * cw), int(y0 + r * ch), int(x0 + (q + 1) * cw), int(y0 + (r + 1) * ch), 0]
            for r in range(ROWS) for q in range(COLS)]


def detect(predict, im, prompt=PROMPT, min_frac=MIN_FRAC):
    """`predict(im, prompt) -> список bool-масок`. -> 12 боксов по ячейкам 4×3, способ, число масок."""
    w, h = im.size
    masks = predict(im, prompt)
    boxes = [_bbox(m) for m in masks if m.sum() >= min_frac / 100 * w * h]
    if len(boxes) < COLS * ROWS:
        return _grid_boxes(w, h), "fallback-grid", len(boxes)

    xs = _cuts([(b[0] + b[2]) / 2 for b in boxes], COLS - 1)
    ys = _cuts([(b[1] + b[3]) / 2 for b in boxes], ROWS - 1)
    best = {}
    for b in boxes:
        key = (sum((b[0] + b[2]) / 2 > t for t in xs), sum((b[1] + b[3]) / 2 > t for t in ys))
        if key not in best or b[4] > best[key][4]:
            best[key] = b

    mode = "sam"
    if len(best) < COLS * ROWS:
        mode = f"grid-cells:{len(best)}"
        grid = _grid_boxes(w, h)
        for r in range(ROWS):
            for q in range(COLS):
                best.setdefault((q, r), grid[r * COLS + q])
    return [best[(q, r)] for r in range(ROWS) for q in range(COLS)], mode, len(boxes)


def square(box, w, h, pad=PAD):
    """Бокс -> квадрат со стороной max(w,h), расширенный на pad и зажатый в лист.

    -> (l, t, r, b, clamped)
    """
    bw, bh = box[2] - box[0], box[3] - box[1]
    cx, cy = (box[0] + box[2]) / 2, (box[1] + box[3]) / 2
    side = int(round(max(bw, bh) * (1 + pad)))
    side = min(side, w, h)
    x, y = int(round(cx - side / 2)), int(round(cy - side / 2))
    clamped = x < 0 or y < 0 or x + side > w or y + side > h
    x, y = max(0, min(w - side, x)), max(0, min(h - side, y))
    return x, y, x + side, y + side, clamped


def overlay(im, boxes):
    d = im.copy()
    dr = ImageDraw.Draw(d)
    for i, b in enumerate(boxes):
        dr.rectangle(b[:4], outline=(220, 0, 0), width=5)
        dr.text((b[0] + 6, b[1] + 6), str(i + 1), fill=(220, 0, 0))
    return d


def contact_sheet(im, boxes, cell=280):
    cs = Image.new("RGB", (3 * cell, 4 * cell), "white")
    for i, b in enumerate(boxes):
        sq = square(b, *im.size)
        cs.paste(im.crop(sq[:4]).resize((cell, cell), Image.LANCZOS), ((i % 3) * cell, (i // 3) * cell))
    return cs


def client(device="mps"):
    """SAM 3.1 из VisionFlow -> `predict(im, prompt)`.

    Обёртка над приватными `_predictor`/`_predict_prompts`: публичный
    `crop_image` пишет временные файлы и подмешивает фон (247,247,247), а нам
    нужны голые маски. Чекпоинт 3.3 GB грузится один раз на прогон.
    """
    if VISIONFLOW not in sys.path:
        sys.path.insert(0, VISIONFLOW)
    import torch  # noqa: F401
    from src.infrastructure.ai.sam3_client import SAM3Client
    Image.MAX_IMAGE_PIXELS = None
    sam = SAM3Client(model_path=CHECKPOINT, device=device)

    def predict(im, prompt=PROMPT):
        sam._predictor.set_image(im)
        return sam._predict_prompts([prompt])

    return predict


if __name__ == "__main__":
    # самопроверка геометрии: квадрат, кламп, сетка-фолбэк, порядок ячеек
    b = [100, 100, 200, 160, 1]
    l, t, r, bo, cl = square(b, 1000, 800)
    assert r - l == bo - t and not cl and r - l == 104, (l, t, r, bo)  # 100 px + 4%
    l, t, r, bo, cl = square([10, 10, 120, 60, 1], 1000, 800)
    assert t == 0 and cl and r - l == bo - t == 114, (l, t, r, bo, cl)  # верх срезан краем листа
    g = _grid_boxes(1000, 800)
    assert len(g) == 12 and g[0][:2] == [60, 80] and g[5][:2] == [g[4][0] + 220, g[4][1]]
    assert _cuts([10, 20, 300, 310, 600, 610], 2) == [160.0, 455.0]
    print("ok")

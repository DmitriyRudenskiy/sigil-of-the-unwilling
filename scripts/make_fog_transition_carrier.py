#!/usr/bin/env python3
"""Носитель AC 8 (круг 13, редакция 2): полоса пера биомов ∩ сигнал тумана.

Повод редакции 2. Ревьюер круга 13 дал FAIL носителю: «пурпурный контур не лежит в полосе
перехода, он смещён от кромки тумана». Претензия по форме верна, и из неё извлечено больше,
чем казалось: контур клетки-ступеньки **выглядит как отметка видимой границы**, а границей не
является — он отмечает сетку клеток, у которых сосед другого биома. Проверка выравнивания
(`--verify`) это подтвердила: шаг цвета подложки на таком контуре 32.0 против 35.4 у
**случайного** набора клеток того же размера (12 проб, 34.0…36.6) — то есть ступенька клеток
не несёт пиксельного признака перехода, настоящий переход размазан пером T-138. Носитель,
приглашающий прочитать ступеньку как границу, — дефект носителя, а не дефекта глаза.

Что делает редакция 2:

* маска — **полоса пера**, а не клетки: пиксели не дальше `feather × тайл` (по умолчанию
  0.22 × 82 ≈ 18 px) от линии смены биома; рисуется полупрозрачной заливкой, а не контуром,
  чтобы не читалась как граница;
* кромка тумана (граница области нулевой разности) рисуется **циановым контуром 1px** —
  это та геометрия, с которой контур сравнивали в круге 13, и она подписана;
* к числам добавлен **нулевой контроль**: та же мера для 12 случайных наборов равной площади.
  Без него «внутри полосы выше фона» не отличимо от «внутри чего угодно выше фона».

Вход — два кадра `tools/map_shot.gd` при одном seed, 1:1 (команды — в `make_fog_carriers.py`):

    python3 scripts/make_fog_transition_carrier.py /tmp/z1_on.png /tmp/z1_off.png out.png [--verify]
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageOps
from scipy.ndimage import binary_dilation, distance_transform_edt

FEATHER = 0.22  # полоса пера в тайлах, канон T-138
NULL_TRIALS = 12


def cells_of(png: Path) -> dict[tuple[int, int], tuple[int, int, str]]:
    with open(png.with_suffix(png.suffix + ".cells.json"), encoding="utf-8") as f:
        raw = json.load(f)["cells"]
    return {
        tuple(int(p) for p in k.split(",")): (int(v[0]), int(v[1]), str(v[2]))
        for k, v in raw.items()
    }


def pitch(geo: dict) -> int:
    cols: dict[int, list[tuple[int, int]]] = {}
    for (cx, cy), (px, _py, _b) in geo.items():
        cols.setdefault(cy, []).append((cx, px))
    d = [abs(x1 - x0) for col in cols.values() for (c0, x0), (c1, x1) in zip(sorted(col), sorted(col)[1:]) if c1 - c0 == 1]
    return int(np.median(d)) if d else sys.exit("нет соседних по x клеток")


def label_map(geo: dict, tile: int, shape: tuple[int, int]) -> np.ndarray:
    """Биом каждого пикселя по центру клетки (значения — коды имён, −1 вне сетки)."""
    h, w = shape
    names = sorted({b for _x, _y, b in geo.values()})
    code = {n: i for i, n in enumerate(names)}
    lab = np.full((h, w), -1, dtype=np.int16)
    for (cx, cy), (px, py, biome) in geo.items():
        lab[max(0, py - tile // 2):py + tile // 2, max(0, px - tile // 2):px + tile // 2] = code[biome]
    return lab


def feather_band(lab: np.ndarray, tile: int) -> np.ndarray:
    """Полоса шириной `FEATHER × тайл` вокруг линии смены биома (не вокруг клетки)."""
    valid = lab >= 0
    diff = np.zeros_like(valid)
    for ax in (0, 1):
        d = np.not_equal(lab, np.roll(lab, 1, axis=ax)) & valid & np.roll(valid, 1, axis=ax)
        diff |= np.roll(d, -1, axis=ax) | d
    radius = max(1, int(round(FEATHER * tile)))
    return binary_dilation(diff, iterations=radius) & valid


def fog_edge(diff: np.ndarray) -> np.ndarray:
    """Граница видимой (незатронутой туманом) области — нулевая разность."""
    vis = diff < 1
    edge = np.zeros_like(vis)
    edge[1:, :] |= vis[1:, :] != vis[:-1, :]
    edge[:, 1:] |= vis[:, 1:] != vis[:, :-1]
    return edge


def step_across(mask: np.ndarray, img: np.ndarray) -> float:
    """Средний шаг цвета через контур маски (±12 px по нормали) — проверка, что контур
    лежит на видимой границе, а не на произвольной ступеньке сетки."""
    edge = np.zeros_like(mask)
    edge[1:, :] |= mask[1:, :] != mask[:-1, :]
    edge[:, 1:] |= mask[:, 1:] != mask[:, :-1]
    ys, xs = np.nonzero(edge)
    keep = (xs > 14) & (xs < img.shape[1] - 14) & (ys > 14) & (ys < img.shape[0] - 14)
    ys, xs = ys[keep], xs[keep]
    d = np.maximum(
        np.abs(img[ys, xs - 12] - img[ys, xs + 12]).mean(axis=1),
        np.abs(img[ys - 12, xs] - img[ys + 12, xs]).mean(axis=1),
    )
    return float(d.mean())


def cell_mask(geo: dict, tile: int, shape, keys) -> np.ndarray:
    m = np.zeros(shape, bool)
    for (cx, cy) in keys:
        px, py, _b = geo[(cx, cy)]
        m[max(0, py - tile // 2):py + tile // 2, max(0, px - tile // 2):px + tile // 2] = True
    return m


def stats(values: np.ndarray) -> tuple[float, float, float]:
    return float(values.mean()), float(np.percentile(values, 99)), float(values.max())


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("fog_on", type=Path)
    ap.add_argument("fog_off", type=Path)
    ap.add_argument("out", type=Path)
    ap.add_argument("--verify", action="store_true", help="нулевой контроль выравнивания маски")
    a = ap.parse_args()

    geo = cells_of(a.fog_on)
    on = np.asarray(Image.open(a.fog_on).convert("RGB"), dtype=np.float64)
    off = np.asarray(Image.open(a.fog_off).convert("RGB"), dtype=np.float64)
    if on.shape != off.shape:
        sys.exit("кадры разного размера")
    h, w = on.shape[:2]
    tile = pitch(geo)

    diff = np.abs(on - off).mean(axis=2)
    base = np.asarray(Image.open(a.fog_off).convert("L"), dtype=np.float64)
    norm = diff / np.maximum(base, 1.0)

    band = feather_band(label_map(geo, tile, (h, w)), tile)
    mi, pi, xi = stats(diff[band])
    mo, po, xo = stats(diff[~band])
    ni, _, _ = stats(norm[band])
    no, _, _ = stats(norm[~band])
    print(f"FOG ∩ FEATHER  tile={tile}px  полоса {FEATHER} тайла ≈ {max(1, round(FEATHER * tile))}px")
    print(f"  площадь полосы: {band.mean():.1%} кадра;  массы разности в ней: {diff[band].sum() / diff.sum():.1%}")
    print(f"  средняя разность: в полосе {mi:.2f} / вне {mo:.2f} → {mi / mo:.3f}")
    print(f"  p99:              {pi:.2f} / {po:.2f} → {pi / po:.3f};  максимум {xi:.0f} / {xo:.0f}")
    print(f"  нормировано по яркости базы: {ni:.3f} / {no:.3f} → {ni / no:.3f}")

    if a.verify:
        # Нулевой контроль: та же мера на случайных замаскированных областях равной площади.
        rng = np.random.default_rng(1)
        target = int(band.sum())
        nulls = []
        for _ in range(NULL_TRIALS):
            m = np.zeros((h, w), bool)
            while m.sum() < target:  # площадь добирается случайными квадратами, перебор ≤ пары процентов
                y, x = int(rng.integers(0, h)), int(rng.integers(0, w))
                m[max(0, y - tile):y + tile, max(0, x - tile):x + tile] = True
            nulls.append(float(diff[m].mean()))
        print(f"  нулевой контроль ({NULL_TRIALS} случайных областей ≈{target / (h * w):.0%} площади): "
              f"медиана {np.median(nulls):.2f}, разброс {min(nulls):.2f}…{max(nulls):.2f}")
        print(f"  сигнал полосы против нуля: {(mi - np.median(nulls)) / (np.std(nulls) or 1):+.2f} σ")

        # Второй нулевой контроль — выравнивание: почему редакция 1 (клетки-ступеньки) снята.
        lab = label_map(geo, tile, (h, w))
        tkeys = [
            k for k in geo
            if any((n := geo.get((k[0] + dx, k[1] + dy))) and n[2] != geo[k][2]
                   for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        ]
        keys = list(geo)
        stair = step_across(cell_mask(geo, tile, (h, w), tkeys), off)
        rnd = [
            step_across(cell_mask(geo, tile, (h, w), [keys[i] for i in rng.choice(len(keys), len(tkeys), replace=False)]), off)
            for _ in range(NULL_TRIALS)
        ]
        print(f"  выравнивание: шаг цвета на контуре клеток перехода {stair:.2f} против "
              f"{np.median(rnd):.2f} у случайных ({min(rnd):.1f}…{max(rnd):.1f}) — ступенька клеток "
              f"не несёт признака перехода, поэтому маска = полоса пера, а не клетки")

    vis = ImageOps.autocontrast(Image.fromarray(diff.astype(np.uint8), mode="L")).convert("RGB")
    overlay = np.asarray(vis, dtype=np.float64)
    overlay[band] = 0.55 * overlay[band] + 0.45 * np.array([255, 0, 255])
    vis = Image.fromarray(overlay.astype(np.uint8))
    ys, xs = np.nonzero(fog_edge(diff))
    for y, x in zip(ys.tolist(), xs.tolist()):
        vis.putpixel((x, y), (0, 255, 255))
    draw = ImageDraw.Draw(vis)
    try:
        font = ImageFont.load_default(size=16)
    except TypeError:  # Pillow < 10.1
        font = ImageFont.load_default()
    # Кириллицу bitmap-шрифт Pillow не рисует (квадратики) — подпись носителя латиницей.
    title = (f"AC8  |fog=1 - fog=0|  feather band={band.mean():.0%}area  ratio={mi / mo:.2f} "
             f"(norm {ni / no:.2f})   MAGENTA = biome feather band, CYAN = fog edge")
    draw.rectangle([0, 0, w - 1, 20], fill=(0, 0, 0))
    draw.text((4, 3), title, fill=(255, 255, 255), font=font)
    a.out.parent.mkdir(parents=True, exist_ok=True)
    vis.save(a.out)
    print(f"  носитель: {a.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

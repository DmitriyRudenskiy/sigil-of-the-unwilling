#!/usr/bin/env python3
"""Третий носитель 11.3-B (AC 8): footprint тумана ∩ геометрия переходов.

Зачем. `fog-footprint-1x.png` = |fog=1 − fog=0| мерит **один слой** (сколько туман
затемнил). AC 8 — утверждение о **пересечении двух слоёв**: декаль не даёт локализованного
яркого ореола *ровно там, где полоса перехода биомов*, сверх фонового затемнения. На
unary-носителе эти два состояния неразличимы по построению (вердикт ревьюера, круг 12).

Носитель делает то, чего не делает footprint: размечает геометрию перехода прямо на
разностном кадре и печатает числовую пару «внутри полосы / вне полосы». Если AC 8
нарушена, разность внутри полосы системно выше фона; если нет — отношения близки к 1.

Вход — два кадра `tools/map_shot.gd` при одном seed, один в один, плюс геометрия клеток
(`.cells.json` пишется рядом с PNG):

    godot --path game -s tools/map_shot.gd -- --seed=4242 --size=40 --zoom=1 --fog=1 --out=/tmp/f1.png
    godot --path game -s tools/map_shot.gd -- --seed=4242 --size=40 --zoom=1 --fog=0 --out=/tmp/f0.png
    python3 scripts/make_fog_transition_carrier.py /tmp/f1.png /tmp/f0.png out.png

Маска перехода: клетка, у которой хотя бы один 4-сосед — другой биом (то же определение
соседства, что `check_map_art._interior`, наоборот). Полоса пера (0.22 тайла, T-138)
лежит внутри этих клеток, поэтому маска — верхняя граница области перехода, а не её
точная форма: число «внутри» консервативно завышает долю перехода.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageOps


def cells_of(path: Path) -> dict[tuple[int, int], tuple[int, int, str]]:
    """`<кадр>.cells.json`: "cx,cy" -> (центр_x, центр_y, биом). Биом — имя, не индекс."""
    with open(path, encoding="utf-8") as f:
        raw = json.load(f)["cells"]
    out: dict[tuple[int, int], tuple[int, int, str]] = {}
    for key, val in raw.items():
        cx, cy = (int(p) for p in key.split(","))
        out[(cx, cy)] = (int(val[0]), int(val[1]), str(val[2]))
    return out


def pitch(cells: dict) -> int:
    """Сторона клетки в пикселях по соседним центрам (медиана |dx| по x-соседям)."""
    xs: dict[int, list[int]] = {}
    for (cx, _cy), (px, _py, _b) in cells.items():
        xs.setdefault(_cy, []).append((cx, px))
    deltas = []
    for col in xs.values():
        col.sort()
        for (c0, x0), (c1, x1) in zip(col, col[1:]):
            if c1 - c0 == 1:
                deltas.append(abs(x1 - x0))
    if not deltas:
        sys.exit("не удалось вывести размер клетки: нет соседних по x")
    return int(np.median(deltas))


def transition_keys(cells: dict) -> list[tuple[int, int]]:
    keys = []
    for (cx, cy), (_px, _py, biome) in cells.items():
        neigh = [cells.get((cx + dx, cy + dy)) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))]
        if any(n is not None and n[2] != biome for n in neigh):
            keys.append((cx, cy))
    return keys


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("fog_on", type=Path, help="кадр --fog=1")
    ap.add_argument("fog_off", type=Path, help="кадр --fog=0")
    ap.add_argument("out", type=Path)
    ap.add_argument("--no-title", action="store_true")
    a = ap.parse_args()

    geo = cells_of(a.fog_on.with_suffix(a.fog_on.suffix + ".cells.json"))
    img_on = np.asarray(Image.open(a.fog_on).convert("RGB"), dtype=np.int16)
    img_off = np.asarray(Image.open(a.fog_off).convert("RGB"), dtype=np.int16)
    if img_on.shape != img_off.shape:
        sys.exit("кадры разного размера — сравнение невозможно")
    h, w = img_on.shape[:2]

    # Разность = чистый сигнал тумана (целостность пути проверяется отдельно: md5 fog=0
    # обязана совпадать с байтовым эталоном T-137, иначе в разность попал не только туман).
    diff = np.abs(img_on - img_off).mean(axis=2).astype(np.float64)

    tile = pitch(geo)
    tkeys = transition_keys(geo)
    mask = np.zeros((h, w), dtype=bool)
    for (cx, cy) in tkeys:
        px, py, _b = geo[(cx, cy)]
        x0, y0 = px - tile // 2, py - tile // 2
        x1, y1 = x0 + tile, y0 + tile
        if x1 <= 0 or y1 <= 0 or x0 >= w or y0 >= h:
            continue
        mask[max(0, y0):min(h, y1), max(0, x0):min(w, x1)] = True

    # Нормировка по яркости базы: туман — умножение (×0.45), поэтому |on − off| пропорционален
    # яркости подложки. Без нормировки более пёстрая полоса перехода даёт ложное «светится».
    base = np.asarray(Image.open(a.fog_off).convert("L"), dtype=np.float64)
    norm = diff / np.maximum(base, 1.0)

    inside, outside = diff[mask], diff[~mask]
    n_in, n_out = norm[mask], norm[~mask]
    mi, mo = float(inside.mean()), float(outside.mean())
    ratio = mi / mo if mo > 0 else float("inf")
    p99i, p99o = float(np.percentile(inside, 99)), float(np.percentile(outside, 99))
    mass_share = float(inside.sum() / diff.sum()) if diff.sum() else 0.0
    area_share = float(mask.mean())

    print(f"FOG-TRANSITION  seed-кадры {a.fog_on.name}/{a.fog_off.name}  tile={tile}px")
    print(f"  клеток перехода: {len(tkeys)} из {len(geo)} ({len(tkeys)/len(geo):.1%} геометрии)")
    print(f"  площадь маски на кадре: {area_share:.1%};  массы разности внутри: {mass_share:.1%}")
    print(f"  средняя разность: внутри {mi:.2f} / вне {mo:.2f}  → отношение {ratio:.3f}")
    print(f"  p99 разности:     внутри {p99i:.2f} / вне {p99o:.2f}  → отношение {p99i/p99o:.3f}")
    print(f"  максимум:         внутри {inside.max():.0f} / вне {outside.max():.0f}")
    r_norm = float(n_in.mean() / n_out.mean())
    print(f"  нормировано по яркости базы (×0.45 — чистое умножение): "
          f"внутри {n_in.mean():.3f} / вне {n_out.mean():.3f} → отношение {r_norm:.3f}")
    print("  ЧТЕНИЕ: отношение ≈ 1 → ореол перехода не отличается от фона (AC 8 не нарушена);")
    print("  отношение > 1 с заметным p99 → под туманом в полосе перехода светится что-то ещё;")
    print("  сырое отношение > 1 при нормированном ≈ 1 → это не ореол, а более светлая подложка.")

    vis = ImageOps.autocontrast(Image.fromarray(diff.astype(np.uint8), mode="L")).convert("RGB")
    overlay = ImageDraw.Draw(vis)
    # Контур маски: 1px там, где маска меняется (геометрия перехода размечена НА разности).
    edge = np.zeros_like(mask)
    edge[1:, :] |= mask[1:, :] != mask[:-1, :]
    edge[:, 1:] |= mask[:, 1:] != mask[:, :-1]
    ys, xs = np.nonzero(edge)
    for y, x in zip(ys.tolist(), xs.tolist()):
        vis.putpixel((x, y), (255, 0, 255))
    if not a.no_title:
        font = ImageFont.load_default()
        title = (f"FOG ∩ TRANSITION 1:1  |fog=1 - fog=0|  ratio(mean)={ratio:.2f} "
                 f"p99={p99i/p99o:.2f}  mask={area_share:.0%}area/{mass_share:.0%}mass  (magenta = переход)")
        overlay.rectangle([0, 0, w - 1, 14], fill=(0, 0, 0))
        overlay.text((4, 3), title, fill=(255, 255, 255), font=font)
    a.out.parent.mkdir(parents=True, exist_ok=True)
    vis.save(a.out)
    print(f"  носитель: {a.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

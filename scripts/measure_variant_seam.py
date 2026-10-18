#!/usr/bin/env python3
"""T-143: стык вариантов базы — чем различаются варианты и видно ли ребро клетки.

Это НЕ гейт, а контроль, по которому решается, может ли вообще существовать мера
`frame/variant-seam` (AC 1 тикета). Урок снятой `frame/edge-step`: прежде чем
объявлять меру «ловящей» дефект, прогнать тот же профиль там, где дефекта заведомо
нет. Контролем здесь служат рёбра соседних клеток с ОДНИМ вариантом — там стыка
вариантов нет по построению, остаётся только внутренняя полоса тайла.

Два замера:

  atlas — чем именно отличаются варианты одного биома: тоном (низкие частоты;
          `variant_shift` сдвигает пороги рампы → меняются доли тонов) или зерном
          (высокие частоты). Если тоном, шаг через ребро клетки заложен в саму
          идею вариативности, и «свести стык» значит убрать разнообразие.
  frame — профиль L* через общее ребро двух соседей одного биома, сгруппированный
          по «вариант совпал» (контроль) / «разошёлся» (тест). Вариант клетки —
          ближайший тайл варианта из атласа по L* внутренности гекса.

  python3 scripts/measure_variant_seam.py docs/reference/map-baseline/baseline.png

**Вердикт круга 16: меры `frame/variant-seam` не будет.** Контроль неотличим от теста
(кадр: p90 4.2 против 5.3; сборка тайлов встык: контроль `A|A` без шва p90 13.8 против
теста `A|B` 11.2) — внутреннее низкочастотное пятно тайла шумит громче стыка. Мера
посажена в атлас (`atlas/variant-tone` в `check_map_art.py`), где контроль тривиален, а
причина (разъехавшийся **средний** тон варианта) устранена в `gen_map_art --assemble`.
Ещё один урок замера: ядро клетки шире ~40 px задевает чёрные щели гексов, и их вклад в
разброс среднего тона больше самого дефекта — мёрить только маленьким ядром с отсевом.
Режим `frame` после правки исторический: опознавать вариант клетки по L\* больше нельзя,
средние сравнены (совпадение варианта становится случайным, n контрольной группы —
подделка).
"""
from __future__ import annotations

import argparse
import json
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from check_map_art import NEIGH_EVEN, NEIGH_ODD, _cell_crop, _interior, _unfogged  # noqa: E402
from measure_palette_band import de76, rgb_to_lab  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ATLAS = os.path.join(ROOT, "game/assets/tiles")
PLATEAU = (0.10, 0.26)   # доли пути A→B, на которых берётся плато каждой клетки
EDGE = (0.44, 0.56)      # доля пути — полоса общего ребра
CROSS = 3                # пикселей поперёк линии, медиана по ним гасит зерно


def lab(img: Image.Image) -> np.ndarray:
    return rgb_to_lab(np.asarray(img.convert("RGB"), dtype=np.float64) / 255.0)


def _blur(a: np.ndarray) -> np.ndarray:
    """Размытие 3×3 (граница — продолжением края); numpy, без режима "F" в PIL."""
    p = np.pad(a, 1, mode="edge")
    return sum(p[j:j + a.shape[0], i:i + a.shape[1]]
               for j in range(3) for i in range(3)) / 9.0


def grain(l: np.ndarray) -> float:
    """Высокочастотная составляющая: разброс L* минус её же размазанная версия."""
    return float((l - _blur(l)).std())


def atlas_stats() -> dict[str, list[dict]]:
    """Варианты базы каждого биома: тон (L*), зерно и средний RGB для присвоения."""
    with open(os.path.join(ATLAS, "world_map_atlas.json"), encoding="utf-8") as f:
        man = json.load(f)
    tile = int(man["tile"])
    sheet = Image.open(os.path.join(ATLAS, man["image"])).convert("RGB")
    out: dict[str, list[dict]] = {}
    for cell in man["cells"]:
        if cell["kind"] != "base":
            continue
        ax, ay = cell["atlas"]
        t = sheet.crop((ax * tile, ay * tile, (ax + 1) * tile, (ay + 1) * tile))
        # Внутренность гекса — та же область, что видит кадр (CELL_CROP), иначе
        # присвоение варианта сравнивает тайл с тайлом наполовину из пикселей соседа.
        half = max(1, int(tile * 0.6) // 2)
        c = t.crop((tile // 2 - half, tile // 2 - half, tile // 2 + half, tile // 2 + half))
        l = lab(c)
        out.setdefault(cell["biome"], []).append({
            "variant": int(cell["variant"]), "lab": l.reshape(-1, 3).mean(0),
            "L": float(l[..., 0].mean()), "grain": grain(l[..., 0]),
        })
    for variants in out.values():
        variants.sort(key=lambda v: v["variant"])
    return out


def line(l: np.ndarray, a: tuple[int, int], b: tuple[int, int], t0: float, t1: float) -> float:
    """Медиана L* поперёк отрезка a→b на долях [t0, t1] (поперёк — ±CROSS px)."""
    ax, ay = a
    bx, by = b
    n = max(2, int(round(0.25 * abs(bx - ax + by - ay))))
    ts = np.linspace(t0, t1, n)
    us = np.linspace(-CROSS, CROSS, 2 * CROSS + 1)
    xs = ax + (bx - ax) * ts[:, None]
    ys = ay + (by - ay) * ts[:, None]
    dx, dy = bx - ax, by - ay
    d = max(1.0, float(np.hypot(dx, dy)))
    px, py = -(dy / d) * us[None, :], (dx / d) * us[None, :]
    xi = np.clip(np.round(xs + px).astype(int), 0, l.shape[1] - 1)
    yi = np.clip(np.round(ys + py).astype(int), 0, l.shape[0] - 1)
    return float(np.median(l[yi, xi]))


def frame_stats(shot: str, variants: dict[str, list[dict]]) -> list[dict]:
    with open(shot + ".cells.json", encoding="utf-8") as f:
        geo = json.load(f)
    cells = geo["cells"]
    tile = geo["tile"]
    tile = int(tile[0] if isinstance(tile, list) else tile)
    img = Image.open(shot).convert("RGB")
    l = lab(img)
    rows = []
    for biome in sorted({v[2] for v in cells.values()}):
        keys = _unfogged(img, _interior(cells, biome), cells, tile)
        if len(keys) < 20 or biome not in variants:
            continue
        ref = np.array([v["lab"] for v in variants[biome]])
        assign = {}
        for k in keys:
            x, y = cells[k][:2]
            cell_lab = lab(_cell_crop(img, x, y, tile)).reshape(-1, 3).mean(0)
            assign[k] = int(np.argmin(de76(cell_lab[None, :], ref)))
        for k in keys:
            cx, cy = (int(p) for p in k.split(","))
            for d in (NEIGH_ODD if cy % 2 else NEIGH_EVEN):
                other = f"{cx + d[0]},{cy + d[1]}"
                if other not in assign or (cx, cy) >= tuple(int(p) for p in other.split(",")):
                    continue        # каждую пару — один раз
                a = tuple(cells[k][:2])
                b = tuple(cells[other][:2])
                if abs(b[0] - a[0]) > tile or abs(b[1] - a[1]) > tile:
                    continue
                plateau = abs(line(l, a, b, *PLATEAU) - line(l, b, a, *PLATEAU))
                edge = line(l, a, b, *EDGE)
                rows.append({"biome": biome, "same": assign[k] == assign[other],
                             "tone_step": plateau,
                             "edge_overshoot": min(abs(edge - line(l, a, b, *PLATEAU)),
                                                   abs(edge - line(l, b, a, *PLATEAU)))})
    return rows


def strip_stats(variants: dict[str, list[dict]]) -> list[dict]:
    """Синтетический контроль без рендера и без угадывания варианта: два тайла биома
    встык (A | B), профиль L* через их общий шов.

    Контроль — A|A: атлас шьётся wrap-safe (`make_wrap`), поэтому у одинаковых
    тайлов шва нет по построению, и всё, что останется, — внутренняя полоса тайла
    на масштабе окна. Тест — A|B, A≠B: ровно тот стык, который рисует карта, когда
    соседние клетки получили разные варианты."""
    with open(os.path.join(ATLAS, "world_map_atlas.json"), encoding="utf-8") as f:
        man = json.load(f)
    tile = int(man["tile"])
    sheet = Image.open(os.path.join(ATLAS, man["image"])).convert("RGB")
    tiles: dict[str, list[np.ndarray]] = {}
    for cell in man["cells"]:
        if cell["kind"] != "base":
            continue
        ax, ay = cell["atlas"]
        t = sheet.crop((ax * tile, ay * tile, (ax + 1) * tile, (ay + 1) * tile))
        tiles.setdefault(cell["biome"], []).append(lab(t)[..., 0])
    rows = []
    for biome, ts in tiles.items():
        for i, a in enumerate(ts):
            for j, b in enumerate(ts):
                strip = np.concatenate([a, b], axis=1)
                rows.append({"biome": biome, "same": i == j,
                             **_strip_profile(strip, tile)})
    return rows


def _strip_profile(l: np.ndarray, tile: int) -> dict[str, float]:
    """Профиль через вертикальный шов посередине полосы: плато каждого тайла и отрыв
    середины. Плато — медиана столбцов в [0.10, 0.26] тайла от шва (тот же масштаб,
    что в кадре: доля пути между центрами клеток)."""
    med = np.median(l, axis=0)
    n = l.shape[1]
    half = n // 2
    a = float(np.median(med[half - int(0.26 * tile):half - int(0.10 * tile)]))
    b = float(np.median(med[half + int(0.10 * tile):half + int(0.26 * tile)]))
    edge = float(np.median(med[half - 4:half + 5]))
    return {"tone_step": abs(a - b), "edge_overshoot": min(abs(edge - a), abs(edge - b))}


def report(name: str, rows: list[float]) -> str:
    if not rows:
        return f"{name:>28}: нет рёбер"
    a = np.array(rows, dtype=np.float64)
    return (f"{name:>28}: n={len(a):<4} p50={np.percentile(a, 50):5.1f} "
            f"p90={np.percentile(a, 90):5.1f} max={a.max():5.1f}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--strip", action="store_true", help="только синтетический контроль")
    ap.add_argument("shot", nargs="?",
                    default=os.path.join(ROOT, "docs/reference/map-baseline/baseline.png"))
    args = ap.parse_args()

    variants = atlas_stats()
    print("== атлас: чем различаются варианты (Δ по вариантам внутри биома) ==")
    print(f"{'биом':>10} {'вариантов':>10} {'размах L*':>10} {'ΔE max пара':>12} "
          f"{'зерно min..max':>18}")
    for biome, vs in sorted(variants.items()):
        ls = np.array([v["lab"] for v in vs])
        d = de76(ls[:, None, :], ls[None, :, :])
        g = [v["grain"] for v in vs]
        print(f"{biome:>10} {len(vs):>10} {max(v['L'] for v in vs) - min(v['L'] for v in vs):>10.1f} "
              f"{d.max():>12.1f} {min(g):>8.1f}..{max(g):<8.1f}")

    sources = {"strip": ("атлас встык (A|A контроль, A|B тест)", strip_stats(variants)),
               "shot": (f"кадр {os.path.basename(args.shot)}", frame_stats(args.shot, variants))}
    for mode in (["strip"] if args.strip else ["strip", "shot"]):
        label, rows = sources[mode]
        print(f"\n== {label}: профиль через общее ребро ==")
        for key, title in (("tone_step", "шаг тона плато"), ("edge_overshoot", "отрыв середины")):
            print(f"-- {title} (ΔL*)")
            print("   " + report("КОНТРОЛЬ вариант=вариант", [r[key] for r in rows if r["same"]]))
            print("   " + report("ТЕСТ вариант≠вариант", [r[key] for r in rows if not r["same"]]))
            for biome in sorted({r["biome"] for r in rows}):
                print("   " + report(f"  {biome} тест",
                                     [r[key] for r in rows if not r["same"] and r["biome"] == biome]))
        same = sum(1 for r in rows if r["same"])
        print(f"\nрёбер: контроль {same}, тест {len(rows) - same}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

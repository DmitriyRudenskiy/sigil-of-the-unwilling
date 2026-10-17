#!/usr/bin/env python3
"""Машинные гейты графики карты (openspec: world-map-art-variety).

Четыре семейства проверок:

  frame      — по снимку живого рендера (`game/tools/map_shot.gd`): доля различных
               клеток-тайлов внутри биома, периодичность кадра, контраст биоминов.
  atlas      — по файлу атласа + манифесту: вариантов на биом, различимость тайлов.
  objects    — по файлу атласа объектов: дельта-канал, силуэт, якорь по нижней кромке.
  provenance — по `game/assets/PROVENANCE.md`: у каждого носителя есть режим генерации
               и источник, источник лежит в репозитории.

Пороги — в `game/data/config/map_art_gates.json`, откалиброваны по базовой линии
(`docs/reference/map-baseline/`), на которой гейт обязан быть красным.

  python3 scripts/check_map_art.py                      # всё, что найдено
  python3 scripts/check_map_art.py --shot shot.png      # только frame-меры по кадру
  python3 scripts/check_map_art.py --json               # машиночитаемый отчёт
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from measure_palette_band import (  # noqa: E402  (общая метрика палитры §4.6)
    DOM_SHARE,
    de76,
    kmeans,
    load_pixels,
    parse_hex,
    tone_lab,
)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONFIG = os.path.join(ROOT, "game/data/config/map_art_gates.json")
ATLAS = os.path.join(ROOT, "game/assets/tiles/world_map_atlas.json")
OBJECTS = os.path.join(ROOT, "game/assets/objects/world_map_objects.json")
PROVENANCE = os.path.join(ROOT, "game/assets/PROVENANCE.md")
PATCH = 8          # во сколько сжимается патч клетки перед сравнением
COLOR_BITS = 5     # квант канала в патче: 5 бит гасит шум сжатия, но не склеивает тайлы


def _patch(img: Image.Image, x: int, y: int, tile: int) -> bytes:
    """Патч клетки → сравнимая подпись: усреднение до PATCH×PATCH и квант канала."""
    half = tile // 2
    box = (max(0, x - half), max(0, y - half),
           min(img.width, x + half), min(img.height, y + half))
    small = img.crop(box).convert("RGB").resize((PATCH, PATCH), Image.BOX)
    px = (np.asarray(small, dtype=np.uint8).reshape(-1, 3)
          >> (8 - COLOR_BITS)).astype(np.uint8)
    return px.tobytes()


def _mean(img: Image.Image, x: int, y: int, tile: int) -> np.ndarray:
    half = tile // 2
    box = (max(0, x - half), max(0, y - half),
           min(img.width, x + half), min(img.height, y + half))
    return np.asarray(img.crop(box).convert("RGB"), dtype=np.float64).reshape(-1, 3).mean(0)


def frame_checks(shot: str, cfg: dict) -> list[tuple[str, bool, str]]:
    with open(shot + ".cells.json", encoding="utf-8") as f:
        geo = json.load(f)
    tile = int(geo["tile"][0])
    img = Image.open(shot)
    cells = {k: v for k, v in geo["cells"].items()}
    out: list[tuple[str, bool, str]] = []
    fcfg = cfg["frame"]

    # — доля различных клеток-тайлов внутри биома (красный на одном тайле на биом) —
    by_biome: dict[str, list[str]] = {}
    for key, val in cells.items():
        by_biome.setdefault(val[2], []).append(key)
    min_cells = int(fcfg["min_biome_cells"])
    worst = None
    for biome, keys in sorted(by_biome.items()):
        if len(keys) < min_cells:
            continue
        uniq = len({_patch(img, *cells[k][:2], tile) for k in keys}) / len(keys)
        if worst is None or uniq < worst[1]:
            worst = (biome, uniq, len(keys))
    if worst is None:
        out.append(("frame/variety", False,
                    f"в кадре нет биома с ≥{min_cells} клеток — кадр не показателен"))
    else:
        biome, uniq, n = worst
        out.append(("frame/variety", uniq >= float(fcfg["min_variant_uniqueness"]),
                    f"{biome}: {uniq:.2f} различных из {n} (порог "
                    f"≥{float(fcfg['min_variant_uniqueness']):.2f})"))

    # — периодичность: кадр совпадает сам с собой со сдвигом на вектор решётки?
    # Мера — доля пикселей, повторенных с точностью до шума сжатия: при одном тайле
    # на биом внутренности биомов повторяются бит-в-бит, и доля близка к единице.
    shifts = _lattice_shifts(cells)
    arr = np.asarray(img.convert("RGB"), dtype=np.int16)
    best = (-1.0, (0, 0))
    for dx, dy in shifts:
        if abs(dx) >= arr.shape[1] or abs(dy) >= arr.shape[0]:
            continue
        a = arr[max(0, dy):arr.shape[0] + min(0, dy), max(0, dx):arr.shape[1] + min(0, dx)]
        b = arr[max(0, -dy):arr.shape[0] + min(0, -dy),
                max(0, -dx):arr.shape[1] + min(0, -dx)]
        score = float((np.abs(a - b).max(axis=2) <= int(fcfg["identical_epsilon"])).mean())
        if score > best[0]:
            best = (score, (dx, dy))
    periodicity = max(0.0, best[0]) if shifts else 0.0
    out.append(("frame/periodicity", periodicity <= float(fcfg["max_periodicity"]),
                f"повторено кадром {periodicity:.2f} при сдвиге {best[1]} (порог "
                f"≤{float(fcfg['max_periodicity']):.2f})"))

    # — контраст биоминов: самые близкие по среднему цвету биомы кадра —
    means = {}
    for biome, keys in by_biome.items():
        patch = np.stack([_mean(img, *cells[k][:2], tile) for k in keys])
        means[biome] = patch.mean(0)
    closest = None
    names = sorted(means)
    for i, a in enumerate(names):
        for b in names[i + 1:]:
            d = float(de76(tone_lab(tuple(means[a])), tone_lab(tuple(means[b]))))
            if closest is None or d < closest[0]:
                closest = (d, a, b)
    if closest is None:
        out.append(("frame/contrast", False, "в кадре меньше двух биомов"))
    else:
        d, a, b = closest
        out.append(("frame/contrast", d >= float(fcfg["min_biome_contrast_de"]),
                    f"{a}↔{b} ΔE={d:.1f} (порог ≥{float(fcfg['min_biome_contrast_de']):.1f})"))
    return out


def _lattice_shifts(cells: dict) -> list[tuple[int, int]]:
    """Частые векторы между центрами клеток — кандидаты периода тайлинга."""
    pts = [(v[0], v[1]) for v in cells.values()]
    counts: dict[tuple[int, int], int] = {}
    for i, (x1, y1) in enumerate(pts):
        for x2, y2 in pts[i + 1:]:
            d = (x2 - x1, y2 - y1)
            if d == (0, 0):
                continue
            if d[0] < 0 or (d[0] == 0 and d[1] < 0):
                d = (-d[0], -d[1])
            counts[d] = counts.get(d, 0) + 1
    return [d for d, _ in sorted(counts.items(), key=lambda kv: -kv[1])[:3]]


def atlas_checks(manifest_path: str, cfg: dict) -> list[tuple[str, bool, str]]:
    with open(manifest_path, encoding="utf-8") as f:
        manifest = json.load(f)
    img = Image.open(os.path.join(os.path.dirname(manifest_path), manifest["image"])).convert("RGB")
    tile = int(manifest["tile"])
    out: list[tuple[str, bool, str]] = []
    acfg = cfg["atlas"]

    def cell_image(atlas_xy) -> np.ndarray:
        x, y = int(atlas_xy[0]) * tile, int(atlas_xy[1]) * tile
        return np.asarray(img.crop((x, y, x + tile, y + tile)), dtype=np.uint8)

    def signature(atlas_xy) -> bytes:
        small = Image.fromarray(cell_image(atlas_xy)).resize((PATCH, PATCH), Image.BOX)
        return (np.asarray(small, dtype=np.uint8) >> (8 - COLOR_BITS)).astype(np.uint8).tobytes()

    bases = [c for c in manifest["cells"] if c["kind"] == "base"]
    by_biome: dict[str, list] = {}
    for c in bases:
        by_biome.setdefault(c["biome"], []).append(c)
    thin = {b: len(v) for b, v in by_biome.items() if len(v) < int(acfg["min_variants_per_biome"])}
    out.append(("atlas/variants", not thin,
                f"биомов: {len(by_biome)}, мин. вариантов {min(len(v) for v in by_biome.values())}"
                f" (порог ≥{int(acfg['min_variants_per_biome'])})"
                + (f"; тонкие: {sorted(thin)}" if thin else "")))

    sigs = [signature(c["atlas"]) for c in bases]
    share = len(set(sigs)) / len(sigs)
    out.append(("atlas/distinct", share >= float(acfg["min_distinct_share"]),
                f"различных базовых тайлов {share:.2f} (порог "
                f"≥{float(acfg['min_distinct_share']):.2f})"))

    flat = [c for c in bases if float(cell_image(c["atlas"]).std()) < float(acfg["min_cell_std"])]
    out.append(("atlas/not-flat", not flat,
                f"плоских (дисперсия <{float(acfg['min_cell_std']):.1f}): {len(flat)}"
                + (f" — {flat[:4]}" if flat else "")))

    # — палитра: доминирующие тона атласа против полосы M (носитель — канонический
    #   кадр кампании, пиксель локален, потому тона записаны в конфиге) —
    band = [parse_hex(t) for t in cfg["palette"]["band_m"]]
    px = load_pixels(os.path.join(os.path.dirname(manifest_path), manifest["image"]))
    if px is None:
        out.append(("atlas/palette", False, "атлас не читается — палитра не измерена"))
        return out
    worst, worst_tone = 0.0, "—"
    for tone, share, _l, _s in kmeans(px):
        if share < DOM_SHARE:
            continue
        d = float(min(de76(tone_lab(tone), tone_lab(t)) for t in band))
        if d > worst:
            worst, worst_tone = d, f"#{tone[0]:02x}{tone[1]:02x}{tone[2]:02x}"
    out.append(("atlas/palette", worst <= float(cfg["palette"]["max_delta_e"]),
                f"max ΔE до полосы M {worst:.1f} (тон {worst_tone}); порог "
                f"≤{float(cfg['palette']['max_delta_e']):.0f}"))
    return out


def object_checks(manifest_path: str, cfg: dict) -> list[tuple[str, bool, str]]:
    with open(manifest_path, encoding="utf-8") as f:
        manifest = json.load(f)
    img = Image.open(
        os.path.join(os.path.dirname(manifest_path), manifest["image"])).convert("RGBA")
    tile = int(manifest["tile"])
    ocfg = cfg["objects"]
    out: list[tuple[str, bool, str]] = []
    thin, fat, anchor = [], [], []
    for c in manifest["cells"]:
        x, y = int(c["atlas"][0]) * tile, int(c["atlas"][1]) * tile
        alpha = np.asarray(img.crop((x, y, x + tile, y + tile)))[:, :, 3]
        cover = float((alpha > 16).mean())
        if not float(ocfg["min_silhouette_coverage"]) <= cover <= float(ocfg["max_silhouette_coverage"]):
            (thin if cover < float(ocfg["min_silhouette_coverage"]) else fat).append(c["id"])
        # якорь по нижней кромке: сама нижняя строка тайла — пустой прозрачной полосы
        if float((alpha[-max(1, tile // 20):, :] > 16).mean()) > 1.0 - float(ocfg["anchor_transparent"]):
            anchor.append(c["id"])
    out.append(("objects/coverage", not thin and not fat,
                f"пустых {len(thin)}, залитых {len(fat)} из {len(manifest['cells'])}; "
                f"полоса {float(ocfg['min_silhouette_coverage']):.2f}–"
                f"{float(ocfg['max_silhouette_coverage']):.2f}"))
    out.append(("objects/anchor", not anchor,
                f"без прозрачной нижней кромки: {len(anchor)}" + (f" — {anchor[:4]}" if anchor else "")))
    return out


def provenance_check(cfg: dict) -> list[tuple[str, bool, str]]:
    with open(PROVENANCE, encoding="utf-8") as f:
        text = f.read()
    out: list[tuple[str, bool, str]] = []
    missing, ghost = [], []
    for rel in cfg["provenance"]["required_files"]:
        row = next((line for line in text.splitlines() if rel in line), None)
        if row is None:
            missing.append(rel)
            continue
        if not re.search(r"comfyui|procedural|procgen|image-clone", row, re.I):
            ghost.append(rel + " (нет режима генерации)")
        if not os.path.exists(os.path.join(ROOT, "game/assets", rel)):
            ghost.append(rel + " (файла нет на диске)")
    out.append(("provenance/rows", not missing and not ghost,
                f"строк не хватает: {missing or 'нет'}; проблемных: {ghost or 'нет'}"))
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--shot", help="PNG снимка карты (рядом лежит .cells.json)")
    ap.add_argument("--config", default=CONFIG)
    ap.add_argument("--atlas", default=ATLAS)
    ap.add_argument("--objects", default=OBJECTS)
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--allow-missing", action="store_true",
                    help="не считать отсутствующую зону падением (для калибровки)")
    args = ap.parse_args()

    with open(args.config, encoding="utf-8") as f:
        cfg = json.load(f)
    checks: list[tuple[str, bool, str]] = []
    if args.shot and os.path.exists(args.shot):
        checks += frame_checks(args.shot, cfg)
    elif not args.allow_missing:
        checks.append(("frame/*", False, f"нет снимка {args.shot} — гейт не может молчать"))
    if os.path.exists(args.atlas):
        checks += atlas_checks(args.atlas, cfg)
    elif not args.allow_missing:
        checks.append(("atlas/*", False, f"нет манифеста {args.atlas}"))
    if os.path.exists(args.objects):
        checks += object_checks(args.objects, cfg)
    elif not args.allow_missing:
        checks.append(("objects/*", False, f"нет манифеста {args.objects}"))
    checks += provenance_check(cfg)

    failed = [name for name, ok, _ in checks if not ok]
    if args.json:
        print(json.dumps([{
            "name": n, "ok": ok, "detail": d} for n, ok, d in checks], ensure_ascii=False, indent=2))
    else:
        for name, ok, detail in checks:
            print(f"{'PASS' if ok else 'FAIL'}  {name:<20} {detail}")
        print(f"{'GATE=0' if not failed else 'GATE=1'}  ({len(checks) - len(failed)}/{len(checks)})")
    return 0 if not failed else 1


if __name__ == "__main__":
    sys.exit(main())

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
    image_path = os.path.join(os.path.dirname(manifest_path), manifest["image"])
    full = Image.open(image_path)
    img = full.convert("RGB")
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

    # — структура: имена, кратность, пересечения, вес —
    bad_names = [c["id"] for c in manifest["cells"] if not re.fullmatch(r"[a-z0-9_]+", c["id"])]
    out.append(("atlas/naming", not bad_names,
                f"имен вне `category_name_variant` (нижний регистр): {len(bad_names)}"
                + (f" — {bad_names[:3]}" if bad_names else "")))

    cols, rows = (int(x) for x in manifest["grid"])
    slots = {(int(c["atlas"][0]), int(c["atlas"][1])): c["id"] for c in manifest["cells"]}
    outside = [i for (x, y), i in slots.items() if not (0 <= x < cols and 0 <= y < rows)]
    dupes = len(manifest["cells"]) - len(slots)
    fits = full.size == (cols * tile, rows * tile)
    kb = os.path.getsize(image_path) / 1024.0
    weight_max = float(cfg["atlas"]["max_weight_kb"])
    out.append(("atlas/structure", fits and not outside and not dupes and kb <= weight_max,
                f"{full.size[0]}×{full.size[1]} при сетке {cols}×{rows}×{tile}"
                f"{' — размер не кратен тайлу' if not fits else ''}"
                f"{f'; вне сетки {outside[:3]}' if outside else ''}"
                f"{f'; наложений {dupes}' if dupes else ''}"
                f"; вес {kb:.0f} КБ (потолок {weight_max:.0f})"
                + ("" if kb <= weight_max else " — ПРЕВЫШЕН")))

    # — разрешение материала: тайл 82 px выкроен из окна ≥ 4× (иначе это даунскейл мыла) —
    thin_src = []
    for c in bases:
        box = c.get("src_box")
        if not box:
            continue
        if min(int(box[2]), int(box[3])) < tile * int(cfg["atlas"]["min_source_scale"]):
            thin_src.append(c["id"])
    no_src = [c["id"] for c in bases if not c.get("src_box")]
    out.append(("atlas/resolution", not thin_src and not no_src,
                f"окон материала меньше {tile}×{int(cfg['atlas']['min_source_scale'])} px: "
                f"{len(thin_src)}" + (f" — {thin_src[:3]}" if thin_src else "")
                + (f"; без источника {len(no_src)}" if no_src else "")))

    # — бесшовность базы: противоположные кромки тайла обязаны продолжаться (wrap-крой) —
    seams = []
    for c in bases:
        cell = np.asarray(Image.fromarray(cell_image(c["atlas"])).convert("RGB"), dtype=np.int16)
        lr = float(np.abs(cell[:, 0] - cell[:, -1]).mean())
        tb = float(np.abs(cell[0] - cell[-1]).mean())
        if max(lr, tb) > float(cfg["atlas"]["max_seam_mad"]):
            seams.append(f"{c['id']}({max(lr, tb):.0f})")
    out.append(("atlas/seamless", not seams,
                f"рваных швов {len(seams)} из {len(bases)} (порог "
                f"{float(cfg['atlas']['max_seam_mad']):.0f} MAD)"
                + (f" — {seams[:4]}" if seams else "")))

    # — непрозрачность базы: база закрывает клетку целиком, иначе под ней дыра —
    rgba = full.convert("RGBA")
    holes = []
    for c in bases:
        x, y = int(c["atlas"][0]) * tile, int(c["atlas"][1]) * tile
        alpha = np.asarray(rgba.crop((x, y, x + tile, y + tile)))[:, :, 3]
        if float((alpha >= 250).mean()) < float(cfg["atlas"]["min_base_opacity"]):
            holes.append(c["id"])
    out.append(("atlas/base-opaque", not holes,
                f"прозрачных баз {len(holes)} из {len(bases)} (порог "
                f"{float(cfg['atlas']['min_base_opacity']):.2f} непрозрачных пикселей)"
                + (f" — {holes[:4]}" if holes else "")))

    # — замыкание переходов: у каждого биома все шесть направлений (см. test_tile_transitions) —
    # Словарь сторон = рёбра остроконечного шестиугольника: сетка odd-r
    # (city_arena_view._hex_to_pixel: x = size·√3·(col + 0.5·(row&1)), y = size·1.5·row),
    # соседи E/W/NE/NW/SE/SW, поэтому стороны смотрят на E, W и четыре наклонных.
    # Прежний набор {N, NE, SE, S, SW, NW} описывал retired 5×5 лист вручную сделанных
    # картинок (4 ребра + 4 угла), а не геометрию клетки.
    sides = {"e", "ne", "nw", "w", "sw", "se"}
    edges: dict[str, set] = {}
    for c in manifest["cells"]:
        if c["kind"] == "edge":
            edges.setdefault(c["biome"], set()).add(c["side"])
    gaps = {b: sorted(sides - v) for b, v in edges.items() if v != sides}
    out.append(("atlas/edge-closure", bool(edges) and not gaps,
                f"биомов с переходами {len(edges)} из {len(by_biome)}"
                + (f"; дыры {dict(list(gaps.items())[:2])}" if gaps else "")))

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


# ---------------------------------------------------------------- self-test
# Мутационная проверка гардов (задача 2.3, урок фазы 5): гард, который нельзя
# покраснить конкретным дефектом, — не гард. Синтетический чистый атлас обязан
# проходить целиком, каждая мутация — валить ровно свой гейт.

FIXTURE_BIOMES = ("grass", "water")
FIXTURE_SIDES = ("N", "NE", "SE", "S", "SW", "NW")


def _fixture(cfg: dict, workdir: str) -> str:
    """Чистый атлас-образец: периодический узор в тонах полосы M, объекты с силуэтом."""
    tile, cols, rows = 82, 6, 4
    band = [parse_hex(t) for t in cfg["palette"]["band_m"]]
    yy, xx = np.mgrid[0:tile, 0:tile].astype(np.float64) / tile
    # периодический по обеим осям узор => противоположные кромки совпадают точно
    wave = 0.5 + 0.5 * np.sin(2 * np.pi * xx) * np.cos(2 * np.pi * yy)

    def tone(mix: np.ndarray) -> np.ndarray:
        a = np.array(band[4], dtype=np.float64)
        b = np.array(band[5], dtype=np.float64)
        return (a + (b - a) * mix[..., None]).clip(0, 255).astype(np.uint8)

    cells, canvas = [], np.zeros((rows * tile, cols * tile, 4), dtype=np.uint8)
    obj_canvas = np.zeros_like(canvas)

    def put(x: int, y: int, rgba: np.ndarray, *, on_objects: bool = False) -> None:
        target = obj_canvas if on_objects else canvas
        target[y * tile:(y + 1) * tile, x * tile:(x + 1) * tile] = rgba

    def opaque(rgb: np.ndarray) -> np.ndarray:
        return np.dstack([rgb, np.full(rgb.shape[:2], 255, dtype=np.uint8)])

    for i, biome in enumerate(FIXTURE_BIOMES):
        for v in range(4):
            x, y = (i * 4 + v) % cols, (i * 4 + v) // cols
            put(x, y, opaque(tone(wave * (0.2 + 0.2 * v) + 0.06 * v + 0.13 * i)))
            cells.append({"id": f"base_{biome}_{v}", "kind": "base", "biome": biome,
                          "variant": v, "atlas": [x, y], "src_box": [0, 0, 400, 400]})
        for d, side in enumerate(FIXTURE_SIDES):
            x, y = (i * 6 + d) % cols, (i * 6 + d) // cols + 2
            put(x, y, opaque(tone(wave * 0.6 + 0.2 * d / 6 + 0.1 * i)))
            cells.append({"id": f"edge_{biome}_{side.lower()}", "kind": "edge",
                          "biome": biome, "side": side, "atlas": [x, y]})

    # объекты: силуэт ~40% площади и пустая прозрачная нижняя кромка
    obj_cells, blob = [], np.zeros((tile, tile, 4), dtype=np.uint8)  # объекты — свой лист
    yy2, xx2 = np.mgrid[0:tile, 0:tile]
    blob[(((xx2 - tile // 2) ** 2 + (yy2 - tile // 2) ** 2) < (tile * 0.36) ** 2)] = (*band[2], 255)
    blob[-4:, :] = 0
    for i in range(3):
        x, y = i % cols, i // cols
        put(x, y, blob, on_objects=True)
        obj_cells.append({"id": f"obj_tree_{i}", "atlas": [x, y]})
    img = Image.fromarray(canvas)
    obj_img = Image.fromarray(obj_canvas)

    os.makedirs(workdir, exist_ok=True)
    atlas = os.path.join(workdir, "atlas")
    objects = os.path.join(workdir, "objects")
    os.makedirs(atlas, exist_ok=True)
    os.makedirs(objects, exist_ok=True)
    img.save(os.path.join(atlas, "atlas.webp"), lossless=True)
    obj_img.save(os.path.join(objects, "objects.webp"), lossless=True)
    with open(os.path.join(atlas, "atlas.json"), "w", encoding="utf-8") as f:
        json.dump({"tile": tile, "grid": [cols, rows], "image": "atlas.webp",
                   "cells": cells}, f)
    with open(os.path.join(objects, "objects.json"), "w", encoding="utf-8") as f:
        json.dump({"tile": tile, "grid": [cols, rows], "image": "objects.webp",
                   "cells": obj_cells}, f)
    return atlas, objects


def self_test(cfg: dict) -> int:
    import shutil
    import tempfile
    work = tempfile.mkdtemp(prefix="map_art_selftest_")
    try:
        atlas, objects = _fixture(cfg, work)
        cfg = json.loads(json.dumps(cfg))   # мутации не должны трогать пороги
        cfg["provenance"]["required_files"] = []

        def gates() -> dict[str, bool]:
            out = {}
            for name, ok, _ in (atlas_checks(atlas + "/atlas.json", cfg)
                                + object_checks(objects + "/objects.json", cfg)):
                out[name] = ok
            return out

        bad = [g for g, ok in gates().items() if not ok]
        print(f"{'PASS' if not bad else 'FAIL'}  selftest/clean      "
              f"чистый образец: {bad or 'все гарды зелёные'}")
        results = [not bad]

        mutations = [
            ("atlas/seamless", "разорвать шов",
             lambda: _mutate(atlas, shift_edges=True)),
            ("atlas/resolution", "понизить разрешение материала",
             lambda: _mutate(atlas, src_box=[0, 0, 120, 120])),
            ("objects/coverage", "залить фон объекта",
             lambda: _mutate(objects, fill=True)),
            ("atlas/palette", "подменить носитель полосы",
             lambda: _mutate(atlas, repaint=(255, 0, 128))),
            ("atlas/base-opaque", "пробить базу насквозь",
             lambda: _mutate(atlas, punch=True)),
            ("atlas/edge-closure", "снять переход",
             lambda: _mutate(atlas, drop_edge=True)),
        ]
        for guard, what, apply in mutations:
            apply()
            caught = not gates().get(guard, False)
            print(f"{'PASS' if caught else 'FAIL'}  selftest/{guard:<18} {what} → "
                  f"{'пойман' if caught else 'ПРОПУЩЕН'}")
            results.append(caught)
            apply.__self__ if False else None
            _fixture(cfg, work)      # чистый образец обратно, мутации независимы
        return 0 if all(results) else 1
    finally:
        shutil.rmtree(work, ignore_errors=True)


def _mutate(root: str, *, shift_edges=False, src_box=None, fill=False,
            repaint=None, punch=False, drop_edge=False) -> None:
    """Одна мутация образца: пиксели и/или манифест."""
    manifest = os.path.join(root, os.path.basename(root) + ".json")
    with open(manifest, encoding="utf-8") as f:
        data = json.load(f)
    path = os.path.join(root, data["image"])
    img = Image.open(path)
    tile = int(data["tile"])
    if src_box is not None:
        for c in data["cells"]:
            c["src_box"] = src_box
    if drop_edge:
        data["cells"] = [c for c in data["cells"] if not (
            c.get("kind") == "edge" and c.get("side") == "N")]
    if repaint is not None or punch or fill or shift_edges:
        arr = np.asarray(img.convert("RGBA")).copy()
        for c in data["cells"]:
            x, y = int(c["atlas"][0]) * tile, int(c["atlas"][1]) * tile
            if repaint is not None and c.get("kind") == "base":
                arr[y:y + tile, x:x + tile, :3] = repaint
            if punch and c.get("kind") == "base":
                arr[y:y + tile, x:x + tile, 3] = 0
            if fill:
                arr[y:y + tile, x:x + tile] = (10, 20, 30, 255)
            if shift_edges and c.get("kind") == "base":
                # кромка перестаёт продолжать противоположную (сдвиг окна кроя из
                # не-бесшовного материала); циклический сдвиг гард не ловит — он бесшовен
                arr[y:y + tile, x:x + 6, :3] = 255 - arr[y:y + tile, x:x + 6, :3]
        img = Image.fromarray(arr)
        img.save(path, lossless=True)
    with open(manifest, "w", encoding="utf-8") as f:
        json.dump(data, f)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--shot", help="PNG снимка карты (рядом лежит .cells.json)")
    ap.add_argument("--config", default=CONFIG)
    ap.add_argument("--atlas", default=ATLAS)
    ap.add_argument("--objects", default=OBJECTS)
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--self-test", action="store_true",
                    help="мутационная проверка гардов на синтетическом образце")
    args = ap.parse_args()

    with open(args.config, encoding="utf-8") as f:
        cfg = json.load(f)
    if args.self_test:
        return self_test(cfg)
    checks: list[tuple[str, bool, str]] = []
    skipped: list[tuple[str, str]] = []

    # Отсутствующий носитель — явный SKIP с причиной, а не молчание и не FAIL:
    # слой ещё не сгенерирован, но «гейт промолчал» и «носителя нет» — разные вердикты.
    if args.shot:
        if os.path.exists(args.shot):
            checks += frame_checks(args.shot, cfg)
        else:
            skipped.append(("frame/*", f"снимка нет по пути {args.shot}"))
    else:
        skipped.append(("frame/*", "нет --shot: базовый снимок не переснят"))
    for label, path, run in (("atlas/*", args.atlas, atlas_checks),
                             ("objects/*", args.objects, object_checks)):
        if os.path.exists(path):
            checks += run(path, cfg)
        else:
            skipped.append((label, f"манифеста нет по пути {path} — слой ещё не сгенерирован"))
    checks += provenance_check(cfg)

    failed = [name for name, ok, _ in checks if not ok]
    if args.json:
        print(json.dumps([{
            "name": n, "ok": ok, "detail": d, "skipped": False} for n, ok, d in checks]
            + [{"name": n, "ok": True, "detail": r, "skipped": True} for n, r in skipped],
            ensure_ascii=False, indent=2))
    else:
        for name, ok, detail in checks:
            print(f"{'FAIL' if not ok else 'PASS'}  {name:<20} {detail}")
        for name, reason in skipped:
            print(f"SKIP  {name:<20} {reason}")
        print(f"{'GATE=1' if failed else 'GATE=0'}  ({len(failed)} падений из "
              f"{len(checks)} проверено, {len(skipped)} пропущено явно)")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())

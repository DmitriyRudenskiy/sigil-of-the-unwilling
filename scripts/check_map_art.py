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
import math
import os
import random
import re
import sys
from collections import Counter

import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_map_art import hex_mask          # noqa: E402  геометрия клетки — одна на генератор и гейт
from measure_palette_band import (  # noqa: E402  (общая метрика палитры §4.6)
    DOM_SHARE,
    de76,
    kmeans,
    load_pixels,
    parse_hex,
    rgb_to_lab,
    tone_lab,
)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONFIG = os.path.join(ROOT, "game/data/config/map_art_gates.json")
ATLAS = os.path.join(ROOT, "game/assets/tiles/world_map_atlas.json")
OBJECTS = os.path.join(ROOT, "game/assets/objects/world_map_objects.json")
PROVENANCE = os.path.join(ROOT, "game/assets/PROVENANCE.md")
PATCH = 8          # во сколько сжимается патч клетки перед сравнением
COLOR_BITS = 5     # квант канала в патче: 5 бит гасит шум сжатия, но не склеивает тайлы
ORIENT_BINS = 18   # бинов ориентации градиента по 180° (не направленная, шаг 10°)


# Клетка гекса вписана в тайл, и квадратный кроп целого тайла на четверть состоит
# из пикселей соседей — поэтому все клеточные меры берут внутренность гекса.
CELL_CROP = 0.6
CELL_PATCH = 4     # подпись variety: 4×4 по 4 бита — шум webp не расщепляет один тайл
CELL_BITS = 4
FOG_CUT = 0.75     # клетка темнее 0.75·медианы биома — туман войны, а не другой тайл

# смещения соседей offset-рядов (odd_row_shift_right=true — калибровка HexGrid)
NEIGH_EVEN = [(1, 0), (0, -1), (-1, -1), (-1, 0), (-1, 1), (0, 1)]
NEIGH_ODD = [(1, 0), (1, -1), (0, -1), (-1, 0), (0, 1), (1, 1)]


def _cell_crop(img: Image.Image, x: int, y: int, tile: int) -> Image.Image:
    half = max(1, int(tile * CELL_CROP) // 2)
    return img.crop((max(0, x - half), max(0, y - half),
                     min(img.width, x + half), min(img.height, y + half))).convert("RGB")


def _cell_rgb(img: Image.Image, x: int, y: int, tile: int) -> np.ndarray:
    return np.asarray(_cell_crop(img, x, y, tile), dtype=np.float64).reshape(-1, 3).mean(0)


def _cell_sig(img: Image.Image, x: int, y: int, tile: int) -> bytes:
    small = _cell_crop(img, x, y, tile).resize((CELL_PATCH, CELL_PATCH), Image.BOX)
    px = (np.asarray(small, dtype=np.uint8).reshape(-1, 3)
          >> (8 - CELL_BITS)).astype(np.uint8)
    return px.tobytes()


def _interior(cells: dict, biome: str) -> list[str]:
    """Клетки биома, у которых все шесть соседей — тот же биом.

    Клетка на границе показывает чужой тайл, а затуманенная — затемнение: и то и
    другое меняет пиксели, но не тайл, поэтому разнообразие считается по внутренним.
    """
    out = []
    for key, val in cells.items():
        if val[2] != biome:
            continue
        cx, cy = map(int, key.split(","))
        if all(cells.get(f"{cx + d[0]},{cy + d[1]}", [0, 0, biome])[2] == biome
               for d in (NEIGH_ODD if cy % 2 else NEIGH_EVEN)):
            out.append(key)
    return out


def _unfogged(img: Image.Image, keys: list[str], cells: dict, tile: int) -> list[str]:
    lum = [_cell_rgb(img, *cells[k][:2], tile).mean() for k in keys]
    med = float(np.median(lum))
    return [k for k, v in zip(keys, lum) if v > FOG_CUT * med]


def _neigh_dirs(cells: dict, key: str) -> list[tuple[int, int]]:
    return NEIGH_ODD if int(key.split(",")[1]) % 2 else NEIGH_EVEN


def frame_checks(shot: str, cfg: dict) -> list[tuple[str, bool, str]]:
    with open(shot + ".cells.json", encoding="utf-8") as f:
        geo = json.load(f)
    tile = int(geo["tile"][0])
    img = Image.open(shot)
    cells = {k: v for k, v in geo["cells"].items()}
    out: list[tuple[str, bool, str]] = []
    fcfg = cfg["frame"]

    # — разнообразие: 1 − доля модального тайла биома. Красный, когда биом держится
    # на одном тайле; порог 0.75 = «ни один вариант не занимает больше четверти».
    # Считается по внутренним клеткам вне тумана (см. _interior / _unfogged).
    min_cells = int(fcfg["min_biome_cells"])
    min_sampled = int(fcfg.get("min_sampled_cells", 20))
    biomes = sorted({v[2] for v in cells.values()})
    variety = {}
    for biome in biomes:
        if sum(1 for v in cells.values() if v[2] == biome) < min_cells:
            continue
        keys = _unfogged(img, _interior(cells, biome), cells, tile)
        if len(keys) < min_sampled:
            continue
        sigs = Counter(_cell_sig(img, *cells[k][:2], tile) for k in keys)
        variety[biome] = (1.0 - sigs.most_common(1)[0][1] / len(keys), len(keys))
    if not variety:
        out.append(("frame/variety", False,
                    f"в кадре нет биома с ≥{min_cells} клеток, из которых ≥{min_sampled} "
                    f"внутренние вне тумана, — кадр не показателен "
                    f"({img.width}×{img.height})"))
    else:
        worst = min(variety, key=lambda b: variety[b][0])
        out.append(("frame/variety", variety[worst][0] >= float(fcfg["min_variant_uniqueness"]),
                    "1 − доля модального тайла: "
                    + ", ".join(f"{b}={v[0]:.2f}/{v[1]}кл" for b, v in sorted(variety.items()))
                    + f" (худший {worst}, порог ≥{float(fcfg['min_variant_uniqueness']):.2f})"))

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

    # — контраст биоминов: самые близкие по среднему цвету биомы кадра. Среднее —
    # по внутренности гекса (CELL_CROP), затуманенные клетки исключены: и то и
    # другое подтягивает средний цвет биома к соседу/тьме, а не измеряет тайл.
    means = {}
    for biome in biomes:
        keys = _unfogged(img, [k for k, v in cells.items() if v[2] == biome], cells, tile)
        if not keys:
            continue
        means[biome] = np.stack([_cell_rgb(img, *cells[k][:2], tile)
                                 for k in keys]).mean(0)
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
                    f"{a}↔{b} ΔE={d:.1f} по внутренности гекса "
                    f"(порог ≥{float(fcfg['min_biome_contrast_de']):.1f})"))

    # — шов перехода: перо на ребре двух биомов не выбивается за тон обоих соседей (T-142) —
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
    rgba = full.convert("RGBA")
    tile = int(manifest["tile"])
    out: list[tuple[str, bool, str]] = []
    acfg = cfg["atlas"]

    def cell_image(atlas_xy) -> np.ndarray:
        x, y = int(atlas_xy[0]) * tile, int(atlas_xy[1]) * tile
        return np.asarray(img.crop((x, y, x + tile, y + tile)), dtype=np.uint8)

    def signature(atlas_xy) -> bytes:
        small = Image.fromarray(cell_image(atlas_xy)).resize((PATCH, PATCH), Image.BOX)
        return (np.asarray(small, dtype=np.uint8) >> (8 - COLOR_BITS)).astype(np.uint8).tobytes()

    # Видимая часть базового тайла — гекс движка, а не квадрат 82×82: под
    # прозрачными углами webp хранит обнулённый (premultiplied) RGB, и тон,
    # дисперсия и шов, померенные по квадрату, считают мусор вместо карты.
    hex_in = np.asarray(Image.fromarray(np.asarray(hex_mask(tile), dtype=np.uint8))
                        .filter(ImageFilter.MinFilter(5))) > 0
    hex_out = np.asarray(Image.fromarray(np.asarray(hex_mask(tile), dtype=np.uint8))
                         .filter(ImageFilter.MaxFilter(5))) < 250

    def cell_hex(atlas_xy) -> np.ndarray:
        """RGB видимых пикселей клетки: (N,3)."""
        x, y = int(atlas_xy[0]) * tile, int(atlas_xy[1]) * tile
        cell = np.asarray(rgba.crop((x, y, x + tile, y + tile)))
        return cell[hex_in][:, :3]

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

    # — тон вариантов: варианты одного биома не имеют права различаться СРЕДНИМ тоном.
    # Разница средних — это не «разнообразие», а тоновая заплата с прямым швом по
    # ребру клетки (T-143, глазной вердикт 11.3 «налепанные заплаты»): на кадре такой
    # шаг неотличим от внутренней полосы тайла (замер: контроль A|A p90 13.8 против
    # теста A|B p90 14.1), поэтому он меряется по атласу, где контроль тривиален.
    # Разнообразие оставляют низкочастотное пятно и зерно — они здесь не меряются.
    tone: dict[str, list[np.ndarray]] = {}
    for c in bases:
        lab_tile = rgb_to_lab(cell_hex(c["atlas"]).astype(np.float64) / 255.0)
        tone.setdefault(c["biome"], []).append(lab_tile.reshape(-1, 3).mean(0))
    worst_biome, worst_de = "", 0.0
    for biome, means in tone.items():
        for i in range(len(means)):
            for j in range(i + 1, len(means)):
                d = float(de76(means[i], means[j]))
                if d > worst_de:
                    worst_biome, worst_de = biome, d
    limit = float(acfg["max_variant_tone_de"])
    out.append(("atlas/variant-tone", worst_de <= limit,
                f"макс. ΔE средних тонов вариантов одного биома: {worst_de:.1f} "
                f"({worst_biome}) при пороге ≤{limit:.1f}"))

    flat = [c for c in bases
            if float(cell_hex(c["atlas"]).std()) < float(acfg["min_cell_std"])]
    out.append(("atlas/not-flat", not flat,
                f"плоских (дисперсия <{float(acfg['min_cell_std']):.1f}): {len(flat)}"
                + (f" — {flat[:4]}" if flat else "")))

    # — направление мазка у вариантов (T-143, круг 18): равный средний тон ткани не
    # ровняет. Четыре независимых рисунка на бим глаз собирает в диагональную «ёлочку»,
    # и ни одна тон-мера, ни `frame/variety`, ни `measure_mottle_cut.py` этого не видят
    # (все трое меряют тон или средний профиль, а не ориентацию). Гистограмма
    # ориентации градиента по гексу движка, вес — модуль градиента; мера — худшее
    # попарное L1-расхождение внутри биома. Порог 0.30: атлас «четыре рисунка» даёт
    # 0.35…0.70 (песок 0.70), атлас фаз — 0.07…0.18 (носитель
    # `review-11-3/phase-variants-t143.png`).
    def orientation(atlas_xy) -> np.ndarray:
        cell = cell_image(atlas_xy)
        lum = rgb_to_lab(cell.astype(np.float64) / 255.0)[..., 0]
        gy, gx = np.gradient(lum)
        ang = np.degrees(np.arctan2(gy, gx)) % 180.0
        hist, _ = np.histogram(ang[hex_in], bins=ORIENT_BINS, range=(0.0, 180.0),
                               weights=np.hypot(gx, gy)[hex_in])
        return hist / max(float(hist.sum()), 1e-9)

    fabric: dict[str, list[np.ndarray]] = {}
    for c in bases:
        fabric.setdefault(c["biome"], []).append(orientation(c["atlas"]))
    worst_biome, worst_l1 = "", 0.0
    for biome, hists in fabric.items():
        for i in range(len(hists)):
            for j in range(i + 1, len(hists)):
                d = float(np.abs(hists[i] - hists[j]).sum())
                if d > worst_l1:
                    worst_biome, worst_l1 = biome, d
    limit = float(acfg["max_variant_orientation_l1"])
    out.append(("atlas/orientation", worst_l1 <= limit,
                f"макс. L1-расхождение направления мазка вариантов: {worst_l1:.2f} "
                f"({worst_biome}) при пороге ≤{limit:.2f}"))

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

    # — бесшовность базы: противоположные кромки тайла обязаны продолжаться (wrap-крой).
    # Меряется только вертикальная пара сторон: у гекса с остриём сверху рёбра W/E
    # лежат на кромках тайла, а остальные четыре сходятся в вершины, то есть
    # «верх↔низ» в пространстве тайла больше не общее ребро (T-143).
    seams = []
    for c in bases:
        x, y = int(c["atlas"][0]) * tile, int(c["atlas"][1]) * tile
        cell = np.asarray(rgba.crop((x, y, x + tile, y + tile)), dtype=np.int16)
        both = (cell[:, 0, 3] >= 250) & (cell[:, -1, 3] >= 250)
        lr = float(np.abs(cell[both, 0, :3] - cell[both, -1, :3]).mean()) if both.any() else 0.0
        if lr > float(cfg["atlas"]["max_seam_mad"]):
            seams.append(f"{c['id']}({lr:.0f})")
    out.append(("atlas/seamless", not seams,
                f"рваных швов {len(seams)} из {len(bases)} на сторонах W/E (порог "
                f"{float(cfg['atlas']['max_seam_mad']):.0f} MAD)"
                + (f" — {seams[:4]}" if seams else "")))

    # — форма клетки: каждый тайл атласа обязан быть вырезан тем же гексом, что
    # рисует движок. Квадратная (непрозрачная по всему кваду) клетка в гекс-
    # тайлсете красит прямые углы поверх соседей: ряды кладутся с шагом 3/4 высоты,
    # квады наезжают, и по карте идёт сетка прямоугольников (T-143, глазной вердикт
    # 11.3 «налепанные заплаты»). Меряются и базы, и декали границы — дефект один.
    bad = []
    for c in manifest["cells"]:
        x, y = int(c["atlas"][0]) * tile, int(c["atlas"][1]) * tile
        alpha = np.asarray(rgba.crop((x, y, x + tile, y + tile)))[:, :, 3]
        opaque = float(alpha[hex_in].mean()) / 255.0 >= float(cfg["atlas"]["min_base_opacity"])
        corner = float(alpha[hex_out].max()) <= float(cfg["atlas"]["max_base_corner_alpha"])
        # Внутри гекса декаль обязан полупрозрачным пером — это его природа
        # (`atlas/decal-tone`), поэтому требовать от него непрозрачности нельзя.
        if not corner or (c["kind"] == "base" and not opaque):
            bad.append(c["id"])
    out.append(("atlas/hex-shape", not bad,
                f"клеток вне гекса {len(bad)} из {len(manifest['cells'])} (порог "
                f"{float(cfg['atlas']['min_base_opacity']):.2f} непрозрачных внутри гекса, "
                f"угол ≤{float(cfg['atlas']['max_base_corner_alpha']):.0f})"
                + (f" — {bad[:4]}" if bad else "")))

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

    # — тон декаля: перо перехода — материал своего биома, а не тёмная полоса.
    # Полоса 0.3 ≤ α ≤ 0.9 — тем и декаль наедает чужую клетку; если её RGB темнее
    # базы биома сильнее, чем шаг между двумя биомами, переход читается границей.
    # Так и было: `paste(тайл, позиция, тайл)` в gen_map_art предумножал RGB на альфу
    # (маска-изображение смешивает с прозрачным чёрным) — 13–21 ΔE тёмной кромки.
    def _cell_px(c: dict) -> np.ndarray:
        x, y = int(c["atlas"][0]) * tile, int(c["atlas"][1]) * tile
        return np.asarray(rgba.crop((x, y, x + tile, y + tile)), dtype=np.uint8)

    limit = float(cfg["frame"]["min_biome_contrast_de"])
    worst_de, worst_biome = 0.0, "—"
    for biome in sorted({c["biome"] for c in manifest["cells"]}):
        group = [c for c in manifest["cells"] if c["biome"] == biome]
        base = np.concatenate([_cell_px(c).reshape(-1, 4) for c in group
                               if c["kind"] == "base"])
        edge = np.concatenate([_cell_px(c).reshape(-1, 4) for c in group
                               if c["kind"] == "edge"])
        feather = (edge[:, 3] >= 77) & (edge[:, 3] <= 230)
        if feather.sum() < 8:
            continue            # переход целиком непрозрачен — мерить нечего
        d = float(de76(tone_lab(tuple(edge[feather][:, :3].mean(0))),
                       tone_lab(tuple(base[:, :3].mean(0)))))
        if d > worst_de:
            worst_de, worst_biome = d, biome
    out.append(("atlas/decal-tone", worst_de <= limit,
                f"худший ΔE(перо декаля ↔ база биома) {worst_de:.1f} ({worst_biome}); "
                f"порог ≤{limit:.1f}"))

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
FIXTURE_SIDES = ("E", "NE", "NW", "W", "SW", "SE")  # рёбра odd-r гекса, как в гейте


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

    def hexed(rgb: np.ndarray) -> np.ndarray:
        """База образца — гексом, как её рисует движок (иначе «чистый образец»
        сам нарушает `atlas/base-hex`)."""
        return np.dstack([rgb, np.asarray(hex_mask(rgb.shape[0]), dtype=np.uint8)])

    for i, biome in enumerate(FIXTURE_BIOMES):
        # ткань биома одна, варианты — её фазы (как в `gen_map_art` после круга 18):
        # разный рисунок у вариантов — это ровно тот дефект, который ловит
        # `atlas/orientation`, и «чистый образец» не имеет права его нарушать
        fabric = [0.5 + (0.5 * np.sin(2 * np.pi * (xx + v / 4.0)) * np.cos(2 * np.pi * yy))
                  for v in range(4)]
        for v in range(4):
            x, y = (i * 4 + v) % cols, (i * 4 + v) // cols
            # варианты различаются фазой узора, но НЕ средним тоном:
            # `atlas/variant-tone` требует равных средних, иначе «чистый образец» сам
            # нарушает тот гард, который обязан ловить мутацией
            put(x, y, hexed(tone(0.5 + (fabric[v] - 0.5) * 0.6 + 0.13 * i)))
            cells.append({"id": f"base_{biome}_{v}", "kind": "base", "biome": biome,
                          "variant": v, "atlas": [x, y], "src_box": [0, 0, 400, 400]})
        for d, side in enumerate(FIXTURE_SIDES):
            x, y = (i * 6 + d) % cols, (i * 6 + d) // cols + 2
            put(x, y, hexed(tone(wave * 0.6 + 0.2 * d / 6 + 0.1 * i)))
            cells.append({"id": f"edge_{biome}_{side.lower()}", "kind": "edge",
                          "biome": biome, "side": side.lower(), "atlas": [x, y]})

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
    return atlas, objects, _fixture_shot(cfg, workdir)


def _fixture_shot(cfg: dict, workdir: str) -> str:
    """Снимок-образец для frame-мер: два биома по 9×9 клеток offset-решётки.

    Клетки одного биома отличаются вариантом базы (ступенька тона), решётка —
    как у живого рендера (шаг 82×123, нечётный ряд сдвинут на полшага). Блоки
    биомов **смежные** (без столбца-щели) и **без горизонтальных щелей**: иначе в
    образце нет ни одного общего ребра между биомами, а середина диагонального
    ребра попадает в чёрный зазор, и `frame/edge-step` мерит не переход, а дыру.
    """
    tile, pitch_y, side = 82, 123, 9
    band = [parse_hex(t) for t in cfg["palette"]["band_m"]]
    base = {FIXTURE_BIOMES[0]: np.array(band[4], dtype=np.float64),
            FIXTURE_BIOMES[1]: np.array(band[6], dtype=np.float64)}
    cols = side * 2
    rows = side
    canvas = np.zeros((rows * pitch_y + tile // 2, cols * tile + tile // 2, 3), dtype=np.uint8)
    cells, rng = {}, random.Random(7)
    yy, xx = np.mgrid[0:pitch_y, 0:tile].astype(np.float64) / tile
    wave = 1.0 + 0.25 * np.sin(6 * np.pi * xx) * np.cos(6 * np.pi * yy)
    for bi, biome in enumerate(FIXTURE_BIOMES):
        for r in range(rows):
            for c in range(side):
                col = bi * side + c
                x = col * tile + (tile // 2 if r % 2 else 0)
                y = r * pitch_y
                v = rng.randrange(4)
                rgb = (base[biome] * (1.0 + 0.14 * v) * wave[..., None]).clip(0, 255).astype(np.uint8)
                canvas[y:y + pitch_y, x:x + tile] = rgb
                cells[f"{col},{r}"] = [x + tile // 2, y + tile // 2, biome]
    shot = os.path.join(workdir, "shot", "shot.png")
    os.makedirs(os.path.dirname(shot), exist_ok=True)
    Image.fromarray(canvas).save(shot)
    with open(shot + ".cells.json", "w", encoding="utf-8") as f:
        json.dump({"seed": 0, "tile": [tile, tile], "cells": cells}, f)
    return shot


def _mutate_shot(shot: str, cfg: dict, *, single_variant=False,
                 merge_biomes=False) -> None:
    """Мутации кадра: один вариант на биом / рампа биома сведена к соседнему."""
    with open(shot + ".cells.json", encoding="utf-8") as f:
        cells = json.load(f)["cells"]
    img = Image.open(shot).convert("RGB")
    arr = np.asarray(img, dtype=np.uint8).copy()
    tile = 82
    pitch_y = 123
    band = [parse_hex(t) for t in cfg["palette"]["band_m"]]
    src = {(int(k.split(",")[0]), int(k.split(",")[1])): (v[0], v[1], v[2])
           for k, v in cells.items()}
    side = (max(c[0] for c in src) + 1) // 2   # ширина блока клеток в образце
    half = tile // 2
    for (col, row), (cx, cy, biome) in src.items():   # в cells.json — центры клеток
        x, y = cx - half, cy - half
        if single_variant and biome == FIXTURE_BIOMES[0]:
            arr[y:y + pitch_y, x:x + tile] = np.array(band[4], dtype=np.uint8)
        if merge_biomes and biome == FIXTURE_BIOMES[1]:
            # копия соседнего биома клетка-в-клетку: та же рампа, тот же узор
            sx, sy, _ = src[(col - side, row)]
            arr[y:y + pitch_y, x:x + tile] = arr[sy - half:sy - half + pitch_y,
                                                 sx - half:sx - half + tile]
    Image.fromarray(arr).save(shot)


def self_test(cfg: dict) -> int:
    import shutil
    import tempfile
    work = tempfile.mkdtemp(prefix="map_art_selftest_")
    try:
        atlas, objects, shot = _fixture(cfg, work)
        cfg = json.loads(json.dumps(cfg))   # мутации не должны трогать пороги
        cfg["provenance"]["required_files"] = []

        def gates() -> dict[str, bool]:
            out = {}
            for name, ok, _ in (frame_checks(shot, cfg)
                                + atlas_checks(atlas + "/atlas.json", cfg)
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
            ("atlas/hex-shape", "пробить базу насквозь",
             lambda: _mutate(atlas, punch=True)),
            ("atlas/hex-shape", "вернуть квадратную базу",
             lambda: _mutate(atlas, square=True)),
            ("atlas/edge-closure", "снять переход",
             lambda: _mutate(atlas, drop_edge=True)),
            ("atlas/decal-tone", "предумножить RGB декаля на альфу",
             lambda: _mutate(atlas, premultiply=True)),
            ("atlas/variant-tone", "разнести варианты по среднему тону",
             lambda: _mutate(atlas, variant_tone=True)),
            ("atlas/distinct", "свернуть все варианты в один",
             lambda: _mutate(atlas, collapse_variants=True)),
            ("atlas/orientation", "вернуть четыре разных рисунка на биом",
             lambda: _mutate(atlas, variant_art=True)),
            ("frame/variety", "оставить один вариант на биом",
             lambda: _mutate_shot(shot, cfg, single_variant=True)),
            ("frame/contrast", "свести рампу биома к соседней",
             lambda: _mutate_shot(shot, cfg, merge_biomes=True)),
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
            repaint=None, punch=False, drop_edge=False, premultiply=False,
            variant_tone=False, collapse_variants=False, square=False,
            variant_art=False) -> None:
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
            c.get("kind") == "edge" and c.get("side") == "e")]
    if (repaint is not None or punch or fill or shift_edges or premultiply or variant_tone
            or collapse_variants or square or variant_art):
        arr = np.asarray(img.convert("RGBA")).copy()
        for c in data["cells"]:
            x, y = int(c["atlas"][0]) * tile, int(c["atlas"][1]) * tile
            if repaint is not None and c.get("kind") == "base":
                arr[y:y + tile, x:x + tile, :3] = repaint
            if punch and c.get("kind") == "base":
                arr[y:y + tile, x:x + tile, 3] = 0
            if square:
                # регресс T-143: клетка снова непрозрачна по всему кваду — движок
                # рисует её квадратом, и по карте идёт сетка прямоугольников
                arr[y:y + tile, x:x + tile, 3] = 255
            if fill:
                arr[y:y + tile, x:x + tile] = (10, 20, 30, 255)
            if premultiply and c.get("kind") == "edge":
                # тот же дефект, что ушёл в атлас: полупрозрачный край с RGB, уже
                # умноженным на альфу, — глазами это тёмная кайма перехода
                a = np.linspace(1.0, 0.0, tile)[None, :].repeat(tile, axis=0)
                cell = arr[y:y + tile, x:x + tile].astype(np.float64)
                cell[..., 3] = a * 255.0
                cell[..., :3] *= a[..., None]
                arr[y:y + tile, x:x + tile] = np.rint(cell).astype(np.uint8)
            if variant_tone and c.get("kind") == "base":
                # тот же дефект, что чинит T-143: варианты одного биома разъезжаются
                # средним тоном (полярность по чётности варианта), пятно и зерно целы
                f = 1.18 if int(c.get("variant", 0)) % 2 else 0.86
                cell = arr[y:y + tile, x:x + tile, :3].astype(np.float64) * f
                arr[y:y + tile, x:x + tile, :3] = np.clip(cell, 0, 255).astype(np.uint8)
            if variant_art and c.get("kind") == "base":
                # регресс T-143 круга 18: у каждого варианта свой рисунок со своим
                # направлением мазка (в сырье это были четыре независимых арта). Здесь —
                # полоса под углом 30°·variant: ориентация гистограммы разъезжается,
                # средний тон и дисперсия остаются прежними
                v = int(c.get("variant", 0))
                ang = math.radians(30.0 * v)
                yy, xx = np.mgrid[0:tile, 0:tile]
                phase = (xx * math.cos(ang) + yy * math.sin(ang)) * (2 * math.pi / 9.0)
                cell = arr[y:y + tile, x:x + tile, :3].astype(np.float64)
                cell = np.clip(cell + 40.0 * np.sign(np.sin(phase))[..., None], 0, 255)
                arr[y:y + tile, x:x + tile, :3] = cell.astype(np.uint8)
            if shift_edges and c.get("kind") == "base":
                # кромка перестаёт продолжать противоположную (сдвиг окна кроя из
                # не-бесшовного материала); циклический сдвиг гард не ловит — он бесшовен
                arr[y:y + tile, x:x + 6, :3] = 255 - arr[y:y + tile, x:x + 6, :3]
        img = Image.fromarray(arr)
        if collapse_variants:
            # «все варианты свёрнуты в один»: клетка варианта копируется в нулевой
            # вариант своего биома побайтово — атлас теряет разнообразие по-настоящему
            first = {c["biome"]: c["atlas"] for c in data["cells"]
                     if c.get("kind") == "base" and int(c.get("variant", 0)) == 0}
            for c in data["cells"]:
                if c.get("kind") == "base" and int(c.get("variant", 0)) > 0:
                    sx, sy = first[c["biome"]]
                    x, y = int(c["atlas"][0]) * tile, int(c["atlas"][1]) * tile
                    arr[y:y + tile, x:x + tile] = arr[sy * tile:sy * tile + tile,
                                                      sx * tile:sx * tile + tile]
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
        # Знаменатель обязан означать ровно измеряемое (урок T-138, где заголовок
        # «17/17» читали как покрытие тумана войны). Охват печатается вместе с вердиктом,
        # чтобы ни один лог не выглядел шире, чем то, что в нём мерили.
        print("      охват: ΔE/структурные меры кадра и атласа. Проверок тумана войны "
              "здесь нет ни одной и в мутациях --self-test тоже: туман в этом скрипте — "
              "только фильтр исключения затемнённых клеток (_unfogged, FOG_CUT) и FAIL-"
              "гард «кадр не показателен». Зелёный GATE о тумане не утверждает ничего "
              "(T-137).")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())

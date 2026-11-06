#!/usr/bin/env python3
"""Шаг 0 измерения (2): сколько оттенков на кадр просит палитра, и где в кадре
игровая зона. D-309 требует k-средних по k=2..8 на все 63 кадра, D-310 требует
реестра с коэффициентом даунскейла; оба числа здесь и никуда не деваются.

Второй режим (`--cells`) меряет **вторую половину вопроса — переиспользование**:
профиль кластеров тайлов в Lab по маске гекса (D6) при RMS ∈ {2, 8, 16, 32}, на
материале **без нарисованных линий** (вердикт Q-M135 → (б)) и рядом — базлайн «до
удаления»; PSNR-потолок пути A (по тайлу на клетку, 1.4); расхождение палитры
клеток с полосой M и то, снимается ли оно перекраской (1.5). Меряется только на
сценах с принятой геометрией (`cell_fit.accepted`, D-311) — без решётки непонятно,
где клетка, а выдумывать её корреляцией уже запрещено.

Игровая зона ищется по энергии отклика «тёмкая тонкая линия»: декоративная оправа
рисуется мягче и без сетки, поэтому полоса с сеткой отделяется порогом по сглаженной
плотности отклика — без подгонки решётки, то есть независимо от того, каким способом
потом будут резать (вопрос о способе — Q-M136, он не блокирует это измерение).

    python3 scripts/measure_scene_clusters.py                 # все кадры, отчёт + реестр
    python3 scripts/measure_scene_clusters.py --scene=<файл>  # один кадр
    python3 scripts/measure_scene_clusters.py --cells --all --update
    python3 scripts/measure_scene_clusters.py --self-test     # проверка на синтетике

Выход — JSON-строка на кадр; `--update` пишет поле `clusters` (или `cell_profile`
в режиме `--cells`) в game/data/config/scene_slices.json.
"""
from __future__ import annotations

import argparse
import json
import math
import statistics
import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import fit_scene_cells as F
import measure_palette_band as P
import measure_scene_lattice as L
from gen_map_art import TILE, hex_mask, lab_to_rgb

DEFAULTS = {
    "k_min": 2,
    "k_max": 8,
    "samples": 60_000,          # пикселей на кадр — k-means по подвыборке, не по кадру
    "energy_quantile": 60.0,    # плотность отклика выше этого квантиля = игровая зона
    "energy_blur_frac": 0.06,   # окно сглаживания плотности (доля от меньшей стороны)
    "roi_min_area": 0.15,
    "seed": 7,
}


def grid_energy(rgb: np.ndarray) -> np.ndarray:
    """Сглаженная плотность «тёмких тонких линий»: где нарисована сетка, там тепло."""
    resp = L.line_response(rgb, L.DEFAULTS)
    m = resp > np.percentile(resp, 90.0)
    dens = cv2.boxFilter(m.astype(np.float32), -1, (45, 45), normalize=True)
    return dens / max(float(dens.max()), 1e-6)


def play_area(rgb: np.ndarray, cfg: dict) -> tuple[int, int, int, int, float]:
    """Прямоугольник игровой зоны и доля кадра, которую он занимает."""
    dens = grid_energy(rgb)
    h, w = dens.shape
    thr = np.percentile(dens, float(cfg["energy_quantile"]))
    on = (dens > max(thr, 1e-3)).astype(np.uint8)
    k = int(max(3, min(h, w) * float(cfg["energy_blur_frac"])))
    on = cv2.morphologyEx(on, cv2.MORPH_CLOSE,
                          cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (k, k)))
    n, lab, st, _ = cv2.connectedComponentsWithStats(on, 8)
    if n <= 1:
        return 0, 0, w, h, 1.0
    i = 1 + int(np.argmax(st[1:, cv2.CC_STAT_AREA]))
    x, y, rw, rh = (int(st[i, j]) for j in range(4))
    if rw * rh < float(cfg["roi_min_area"]) * w * h:
        return 0, 0, w, h, 1.0
    return x, y, rw, rh, round(rw * rh / (w * h), 3)


def kmeans_inertia(px: np.ndarray, k: int, seed: int) -> float:
    crit = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 30, 1.0)
    _, lab, center = cv2.kmeans(px, k, None, crit, 3, cv2.KMEANS_PP_CENTERS, seed)
    d = px - center[lab.flatten()]
    return float((d * d).sum() / len(px))


def palette_drift(rgb: np.ndarray, cfg: dict) -> dict:
    """Разъезд палитры по частям кадра (D-310: «палитра не разъезжается»).

    Мера — не «среднее по кадру» (оно всегда спокойно), а разброс средних девяти
    частей: если левый верх зелёный, а правый низ охра, это видно сразу и это тот
    самый брак, который нельзя ловить глазами.
    """
    h, w = rgb.shape[:2]
    means = []
    for i in range(3):
        for j in range(3):
            cell = rgb[i * h // 3:(i + 1) * h // 3, j * w // 3:(j + 1) * w // 3]
            means.append([float(v) for v in cell.reshape(-1, 3).mean(axis=0)])
    m = np.array(means)
    return {"cell_means": [[round(v, 1) for v in row] for row in m],
            "spread_px": round(float(np.linalg.norm(m.max(axis=0) - m.min(axis=0))), 1)}


def measure(rgb: np.ndarray, cfg: dict) -> dict:
    h, w = rgb.shape[:2]
    x, y, rw, rh, share = play_area(rgb, cfg)
    zone = rgb[y:y + rh, x:x + rw]
    px = zone.reshape(-1, 3).astype(np.float32)
    rng = np.random.default_rng(int(cfg["seed"]))
    take = rng.choice(len(px), size=min(int(cfg["samples"]), len(px)), replace=False)
    px = px[take]
    curve = {str(k): round(kmeans_inertia(px, k, int(cfg["seed"])), 1)
             for k in range(int(cfg["k_min"]), int(cfg["k_max"]) + 1)}
    # локоть — точка максимального прогиба относительно хорды первых и последних k;
    # кривая выпуклая, поэтому берём максимальную площадь треугольника
    ks = sorted(int(k) for k in curve)
    v = np.array([curve[str(k)] for k in ks], float)
    p = np.stack([np.array(ks, float), v], axis=1)
    chord = p[-1] - p[0]
    nrm = np.array([-chord[1], chord[0]])
    dist = np.abs((p - p[0]) @ nrm) / max(float(np.linalg.norm(nrm)), 1e-9)
    elbow = int(ks[int(np.argmax(dist[1:-1]) + 1)])
    # сколько к нужно, чтобы объяснить 85% дисперсии (проверка «ок» ниже — по этому же)
    total = float(((px - px.mean(axis=0)) ** 2).sum() / len(px) * 3) or 1.0
    explained = {str(k): round(1.0 - curve[str(k)] / total, 3) for k in ks}
    k85 = next((k for k in ks if explained[str(k)] >= 0.85), None)
    return {
        "play_area": [x, y, rw, rh],
        "play_area_share": share,
        "inertia": curve,
        "explained": {str(k): explained[str(k)] for k in ks},
        "elbow_k": elbow,
        "k_at_85pct": k85,
        "palette": palette_drift(rgb, cfg),
    }


# ---------------------------------------------------------------- режим `--cells`
# Профиль переиспользования (1.3), PSNR-потолок пути A (1.4) и палитра vs полоса M
# (1.5). Мера расстояния — RMS по Lab-каналам по маске гекса движка (D6): угловые
# треугольники квадрата — это соседи, в метрике они врут. Единицы — сами Lab-каналы
# (L 0…100, a/b ±128), никаких придуманных пересчётов: лестница порогов {2, 8, 16, 32}
# из ТЗ читается в них же, и это записано в реестре рядом с числом.
CELL_RMS = (2.0, 8.0, 16.0, 32.0)
# Для нормализованных клеток RMS в единицах Dis не читается: после (x−μ)/σ у любой клетки
# среднее 0 и разброс 1, поэтому RMS двух *несвязанных* полей равен √2 — и порог «2»
# проходит сам собой. Шкала переведена в корреляцию полей: RMS² = 2(1−r), то есть
# «одна ткань» = поля рельефа коррелируют не ниже r.
NORM_CORR = ((0.90, "corr_90"), (0.75, "corr_75"), (0.50, "corr_50"), (0.25, "corr_25"))
GATES = json.loads((Path(__file__).resolve().parent.parent
                    / "game/data/config/map_art_gates.json").read_text())
DEFAULT_CELLS = {"band_m": [h.lower() for h in GATES["palette"]["band_m"]],
                 "max_delta_e": float(GATES["palette"]["max_delta_e"]),
                 "dom_share": P.DOM_SHARE, "seed": DEFAULTS["seed"]}
CELL_MAX_PIXELS = 120_000      # пикселей соты на кадр в kmeans палитры
REUSE_RMS = 8.0                # порог, на котором считается «ткань одна и та же»


def lab(a: np.ndarray) -> np.ndarray:
    """uint8 RGB → Lab в единицах приёмки (L 0…100, a/b ±128), та же метрика, что в гейтах."""
    return P.rgb_to_lab(a.astype(np.float64) / 255.0)


def cell_mask(size: int) -> np.ndarray:
    return np.asarray(hex_mask(size), dtype=np.uint8) > 127


def normalize_cells(l: np.ndarray, mask: np.ndarray) -> np.ndarray:
    """Снять с каждой клетки её краску: минус среднее и деление на разброс по Lab внутри
    маски. Остаётся рисунок рельефа — светотень, зерна, направление мазка.

    Зачем: D6-мера меряет и структуру, и краску вместе, а комплект написан разными
    палитрами (палитра в полосе M — 8.5% против 87.6% после перекраски, см. профиль).
    Разделив эти две причины, видно, есть ли переиспользование на самом деле: если после
    normalization ткани схлопнутся, то расхождение в D6-мере — краска, а не рельеф, и
    носителем раскраски должен быть слой поверх тайла, а не отдельный тайл."""
    out = l.copy()
    for i in range(len(l)):
        px = l[i][mask]
        mu = px.mean(axis=0)
        sd = px.std(axis=0)
        sd[sd < 1.0] = 1.0
        out[i][mask] = (px - mu) / sd
    return out


def remove_lines(rgb: np.ndarray, mask: np.ndarray, iters: int = 12) -> np.ndarray:
    """Детерминированный ремонт по маске линий (Q-M135 → (б)): изъятый пиксель получает
    значение ближайшего сохранившегося, итерацией по соседям. Полигон кадра не меняется,
    исходник на диске не правится — ремонт живёт в памяти прогона.

    Не `cv2.inpaint`: диффузия (Telea/NS) при ширине разрыва в 5 px затягивает клетку
    краской соседней клетки — на синтетике с четырьмя известными тканями это стоило трёх
    лишних кластеров из четырнадцати, то есть политика «удалить» вносила бы в меру больше,
    чем сами линии. Размножение соседа галола не даёт: цвет внутри соты остаётся её."""
    out = rgb.copy()
    unknown = mask.astype(bool)
    for _ in range(iters):
        if not unknown.any():
            break
        src = np.where(unknown[..., None], 0, out).astype(np.float32)
        acc = cv2.boxFilter(src, -1, (3, 3), normalize=False)
        cnt = cv2.boxFilter((~unknown).astype(np.float32), -1, (3, 3), normalize=False)
        take = unknown & (cnt > 0)
        if not take.any():
            break
        out[take] = np.clip((acc / np.maximum(cnt, 1)[..., None])[take], 0, 255).astype(np.uint8)
        unknown &= ~take
    return out


def greedy_clusters(tiles: np.ndarray, mask: np.ndarray, thr: float) -> list[list[int]]:
    """Жадная кластеризация тайлов по RMS в Lab (D6): первый встретившийся представитель
    ближе порога — тайл в его кластер. Детерминировано порядком обхода, без k и без
    случайных стартов: k здесь и не нужен — вопрос «сколько тканей у сцены», а не
    «как разложить по k корзинам».

    Тайл — (82,82,3), маска — (82,82): индекс применяется к осям изображения, а не к
    номеру тайла, поэтому вектором кладеётся плоский след (N, видимых·3).
    """
    vec = tiles[:, mask].astype(np.float64).reshape(len(tiles), -1)
    reps: list[np.ndarray] = []
    out: list[list[int]] = []
    for i in range(len(vec)):
        j = -1
        if reps:
            d = np.sqrt(((np.asarray(reps) - vec[i]) ** 2).mean(axis=1))
            k = int(np.argmin(d))
            j = k if float(d[k]) <= thr else -1
        if j < 0:
            reps.append(vec[i])
            out.append([i])
        else:
            out[j].append(i)
    return out


def cluster_stats(clusters: list[list[int]], tiles: np.ndarray, mask: np.ndarray) -> dict:
    """Числа профиля при одном пороге RMS.

    `cover80_clusters` — сколько крупнейших кластеров покрывают 80% клеток: это форма
    вопроса AC1 («не менее 80% клеток из ограниченного набора тайлов ≤ N»). В паре с
    `singleton_share` (доля клеток без пары) отвечает на вопрос «есть ли набор»: если
    cover80 остаётся сопоставимым с числом клеток, набора нет, есть калейдоскоп.
    """
    sizes = sorted((len(c) for c in clusters), reverse=True)
    total = max(sum(sizes), 1)
    need, cover, i = 0.8 * total, 0, len(sizes)
    for i, n in enumerate(sizes, 1):
        cover += n
        if cover >= need:
            break
    rep = [tiles[c[0]][mask].astype(np.float64) for c in clusters]
    inter = float(np.mean(np.linalg.norm(np.asarray(rep) - np.mean(rep, axis=0), axis=1))) \
        if len(rep) > 1 else 0.0
    return {"clusters": len(clusters),
            "max_cluster": sizes[0],
            "max_cluster_share": round(sizes[0] / total, 3),
            "median_cluster": int(statistics.median(sizes)),
            "cover80_clusters": i,
            "singleton_share": round(sizes.count(1) / total, 3),
            "tone_spread": round(inter, 1)}


def band_check(px: np.ndarray, band: list[str], max_de: float, dom: float) -> dict:
    """Доминирующие тона сот vs полоса M (§8.5): какая доля пикселей в ΔE ≤ порога и
    какой она становится после перекраски. Перекраска — ровно `recolor_cell` из
    генератора: ближайший тон-кластер тянется к ближайшему тону полосы сдвигом в Lab,
    зерно остаётся. Это и есть ответ 1.5 «снимается ли расхождение существующим
    --recolor», а не рассуждение про него."""
    k = len(band)
    bl = np.array([P.tone_lab(P.parse_hex(h)) for h in band])

    def share(fam: list) -> float:
        s = 0.0
        for tone, sh, _l, _sat in fam:
            d = np.linalg.norm(bl - P.tone_lab(tone), axis=1)
            if sh >= dom and float(d.min()) <= max_de:
                s += sh
        return round(s, 3)

    fam = P.kmeans(px, k)
    cl = np.array([P.tone_lab(t) for t, *_ in fam])
    tones = []
    for j, (tone, sh, _l, _sat) in enumerate(fam):
        d = np.linalg.norm(bl - cl[j], axis=1)
        if sh >= dom:
            tones.append({"tone": P.hexs(tone), "share": round(sh, 3),
                          "de": round(float(d.min()), 1), "band": band[int(d.argmin())],
                          "in_band": bool(float(d.min()) <= max_de)})
    near = np.linalg.norm(cl[:, None, :] - bl[None], axis=2).argmin(axis=1)
    lp = lab(px)
    assign = np.linalg.norm(lp[:, None, :] - cl[None], axis=2).argmin(axis=1)
    moved = lab_to_rgb(bl[near][assign] + (lp - cl[assign]))
    remap = np.clip(np.round(moved * 255.0), 0, 255).astype(np.uint8)
    return {"k": k, "dom_share_min": dom, "max_delta_e": max_de, "dominant": tones,
            "in_band_share": share(fam), "in_band_share_recolored": share(P.kmeans(remap, k))}


def cell_tiles(rgb: np.ndarray, clean: np.ndarray, fit: dict) -> tuple[dict, list]:
    """Клетки решётки → кропы 82×82 (D3: единственное понижение, интерполяций дальше нет).

    Соты кадра прогоняются обратной гомографией в «плоскость решётки»: там каждая
    клетка — одинаковый прямоугольный кроп, и все клетки сравнимы между собой, а не
    каждая со своим перспективным искажением. Параллельно считается PSNR пути A:
    тайл 82, возвращённый на нативный размер клетки, — потолок того, что может дать
    «по тайлу на клетку» (1.4).
    """
    C, R = float(fit["col_step_px"]), float(fit["radius_px"])
    ox, oy = (float(v) for v in fit["origin"])
    roi = tuple(int(v) for v in fit["roi"])
    h, w = rgb.shape[:2]
    back = np.linalg.inv(np.array(fit["homography"], dtype=np.float64))
    plane = {"raw": cv2.warpPerspective(rgb, back, (w, h)),
             "clean": cv2.warpPerspective(clean, back, (w, h))}
    rstep, x0, y0, x1, y1 = 1.5 * R, *[roi[0], roi[1], roi[0] + roi[2], roi[1] + roi[3]]
    tiles, psnr = {"raw": [], "clean": []}, []
    for r in range(int((y0 - oy) / rstep) - 1, int((y1 - oy) / rstep) + 2):
        shift = C / 2 if r % 2 else 0.0
        for c in range(int((x0 - ox - shift) / C) - 1, int((x1 - ox - shift) / C) + 2):
            cx, cy = c * C + shift + ox, r * rstep + oy
            box = (int(round(cx - C / 2)), int(round(cy - R)),
                   int(round(cx + C / 2)), int(round(cy + R)))
            if box[0] < 0 or box[1] < 0 or box[2] > w or box[3] > h:
                continue
            for kind in ("raw", "clean"):
                src = plane[kind][box[1]:box[3], box[0]:box[2]]
                tiles[kind].append(cv2.resize(src, (TILE, TILE), interpolation=cv2.INTER_AREA))
            native = plane["clean"][box[1]:box[3], box[0]:box[2]]
            wh = (native.shape[1], native.shape[0])
            recon = cv2.resize(tiles["clean"][-1], wh, interpolation=cv2.INTER_LINEAR)
            m_cell = np.asarray(hex_mask(TILE).resize(wh), dtype=np.uint8) > 127
            d = lab(native) - lab(recon)
            mse = float((d[..., 0] ** 2 * m_cell).sum() / max(m_cell.sum(), 1))
            psnr.append(99.0 if mse < 1e-6 else float(10 * math.log10(100.0 ** 2 / mse)))
    return tiles, psnr


def profile(rgb: np.ndarray, fit: dict, cfg: dict) -> dict:
    """Одна сцена → профиль переиспользования (1.3), PSNR-потолок A (1.4), палитра vs M (1.5)."""
    roi = tuple(int(v) for v in fit["roi"])
    lines = F.line_mask(rgb, roi)
    clean = remove_lines(rgb, lines)
    # Сколько пикселей зона сдала под «линии» — диагностическое число политики «удалить»:
    # правило маски («тёмное и малонасыщенное», граница по Otsu кадра) на тёмном рельефе
    # способно съесть сам террейн, и видно это только по доле.
    share = float(lines[roi[1]:roi[1] + roi[3], roi[0]:roi[0] + roi[2]].mean())
    tiles, psnr = cell_tiles(rgb, clean, fit)
    if not tiles["clean"]:
        return {"cells": 0, "reason": "клеток решётки в зоне не нашлось"}
    t = {k: np.stack(v) for k, v in tiles.items()}
    m = cell_mask(TILE)
    lm, lraw = lab(t["clean"]), lab(t["raw"])
    ln = normalize_cells(lm, m)
    res: dict = {"cells": int(len(t["clean"])),
                 "cell_px": [round(float(fit["col_step_px"]), 1),
                             round(2 * float(fit["radius_px"]), 1)],
                 "downscale": [round(TILE / float(fit["col_step_px"]), 4),
                               round(TILE / (2 * float(fit["radius_px"])), 4)],
                 "rms_units": "RMS по Lab без пересчёта (L 0…100, a/b ±128)",
                 "lines_removed": True, "line_share": round(share, 3),
                 "with_lines": {}, "no_lines": {}, "normalized": {}}
    for thr in CELL_RMS:
        key = f"rms_{thr:g}"
        res["with_lines"][key] = cluster_stats(greedy_clusters(lraw, m, thr), lraw, m)
        res["no_lines"][key] = cluster_stats(greedy_clusters(lm, m, thr), lm, m)
    for r, key in NORM_CORR:
        res["normalized"][key] = cluster_stats(greedy_clusters(ln, m, math.sqrt(2 * (1 - r))), ln, m)
    res["normalized_note"] = "RMS² = 2(1−r) по нормированным полям Lab; corr_75 = r ≥ 0.75"
    reuse = res["no_lines"][f"rms_{REUSE_RMS:g}"]
    res["reuse"] = {"rms": REUSE_RMS, "tiles": reuse["clusters"], "cells": res["cells"],
                    "verdict": f"{res['cells']} клеток → {reuse['clusters']} тканей"}
    res["psnr_path_a"] = {"median_db": round(float(np.median(psnr)), 1),
                          "p10_db": round(float(np.percentile(psnr, 10)), 1),
                          "cells": len(psnr),
                          "note": "путь A: по тайлу 82 на клетку, возврат на нативный размер"}
    px = np.concatenate([a[m].reshape(-1, 3) for a in t["clean"]])
    if len(px) > CELL_MAX_PIXELS:
        px = np.random.default_rng(int(cfg["seed"])).choice(px, CELL_MAX_PIXELS, replace=False)
    res["palette_band"] = band_check(px, cfg["band_m"], float(cfg["max_delta_e"]),
                                     min(float(cfg["dom_share"]), 2.0 / len(cfg["band_m"])))
    return res


def synthetic_cells(draw_lines: bool = True) -> tuple[np.ndarray, dict]:
    """Синтетика для `--cells`: 4×4 клетки четырёх известных тканей, нарисованные
    рёбра, лёгкая перспектива и шум. Ответ замера предсказуем: четыре ткани. Второй
    вызов без рёбер даёт тот же кадр «до рисования сетки» — на нём видно, вернулся ли
    материал после ремонта или измеритель что-то подмешал."""
    C, R = 105.0, 52.0
    rstep = 1.5 * R
    cols, rows = 4, 4
    pw, ph = int(cols * C + C / 2 + 4), int(rows * rstep + 2 * R + 4)
    img = np.zeros((ph, pw, 3), np.uint8)
    # Ткани средние по яркости: на тёмной палитре проверялся бы порог Otsu маски линий,
    # а не измеритель. Риск тёмного рельефа меряется отдельно — `line_share` в реестре.
    tones = [(146, 162, 106), (205, 190, 155), (120, 140, 90), (170, 150, 120)]
    for r in range(rows + 1):
        for c in range(cols + 1):
            cx, cy = c * C + (C / 2 if r % 2 else 0) + 2, r * rstep + R + 2
            poly = np.round(F.hex_ring(C, R, cx, cy)).astype(np.int32)
            cv2.fillPoly(img, [poly], tones[(c + r) % len(tones)])
    if draw_lines:
        for r in range(rows + 1):
            for c in range(cols + 1):
                cx, cy = c * C + (C / 2 if r % 2 else 0) + 2, r * rstep + R + 2
                ring = np.round(F.hex_ring(C, R, cx, cy)).astype(np.int32)
                cv2.polylines(img, [ring], True, (35, 33, 30), 3)
    hq = np.array([[0, 0], [pw, 0], [0, ph], [pw, ph]], np.float32)
    H = cv2.getPerspectiveTransform(hq, np.array(
        [[6, 0], [pw, 5], [0, ph], [pw - 8, ph - 4]], np.float32))
    img = cv2.warpPerspective(img, H, (pw, ph))
    rng = np.random.default_rng(3)
    img = np.clip(img.astype(np.float32) + rng.normal(0, 2, img.shape), 0, 255).astype(np.uint8)
    fit = {"col_step_px": C, "radius_px": R, "origin": [2.0, R + 2], "homography": H.tolist(),
           "roi": [int(C / 2), int(R), int(pw - C), int(ph - 2 * R)],
           "cells": 0, "accepted": True}
    return img, fit


def cells_self_test() -> list[tuple[str, bool, str]]:
    cfg = dict(DEFAULT_CELLS)
    key = f"rms_{REUSE_RMS:g}"
    drawn, fit = synthetic_cells(draw_lines=True)
    m = profile(drawn, fit, cfg)
    clean, _ = synthetic_cells(draw_lines=False)
    base = profile(clean, fit, cfg)
    # Допуск в один кластер и 0.15 доли: поле после (+45) совпадает с исходным с точностью
    # до округления uint8, а пограничная пара при пороге может качнуться. Направление
    # проверки от этого не меняется: норме перекраска не указывает новых тканей вовсе.
    # тот же кадр, но трём клеткам изменена только краска (+45 яркости внутри соты)
    paint = drawn.copy()
    C, R = fit["col_step_px"], fit["radius_px"]
    for (r, c) in ((1, 1), (1, 2), (2, 1)):
        cx, cy = c * C + (C / 2 if r % 2 else 0) + 2, r * 1.5 * R + R + 2
        mm = np.zeros(drawn.shape[:2], np.uint8)
        cv2.fillPoly(mm, [np.round(F.hex_ring(C, R, cx, cy)).astype(np.int32)], 1)
        sel = mm.astype(bool)
        paint[sel] = np.clip(paint[sel].astype(np.int16) + 45, 0, 255).astype(np.uint8)
    paintm = profile(paint, fit, cfg)
    got, truth = m["no_lines"][key]["clusters"], base["no_lines"][key]["clusters"]
    b_low = base["no_lines"]["rms_2"]["clusters"]
    checks = [
        ("клетки найдены", m["cells"] >= 12, f"{m['cells']}"),
        ("материал без сетки даёт четыре ткани", 3 <= truth <= 5, f"{truth} кластеров при RMS ≤ {REUSE_RMS:g}"),
        # Допуск в два кластера — не трусость, а масштаб шума: при σ=2/пиксель и пороге
        # RMS 8 сама синтетика даёт 3 или 4 кластера в зависимости от семени. Смысл проверки
        # в направлении: ремонт не должен унести меру к «одной ткани» или к «уникальным».
        ("ремонт возвращает материал, а не подмешивает", abs(got - truth) <= 2, f"{got} против {truth}"),
        # Направление ошибки базлайна «до» тоже предсказуемо: одинаковые рёбра на каждой
        # клетке делают разные ткани похожими, и наивная мера *занижает* число тканей.
        ("линии скрадывают разнообразие (базлайн «до» занижает)",
         m["with_lines"]["rms_2"]["clusters"] < b_low,
         f"с линиями {m['with_lines']['rms_2']['clusters']} / без {b_low} при RMS ≤ 2"),
        # Свойство нормализованной меры — инвариантность к краске: сдвиг яркости клетки
        # это аффинное изменение её поля, а (x+Δ−μ−Δ)/σ = x. Значит кластеры после
        # перекрашенного кадра обязаны совпасть с исходным поштучно, а D6-мера (raw) —
        # перекрашенные клетки разъединить. Если это перестало выполняться, норма меряет
        # уже не рельеф.
        ("нормализация инвариантна к краске, D6 — нет",
         abs(paintm["normalized"]["corr_75"]["clusters"]
             - m["normalized"]["corr_75"]["clusters"]) <= 1
         and abs(paintm["normalized"]["corr_75"]["singleton_share"]
                 - m["normalized"]["corr_75"]["singleton_share"]) <= 0.15
         and paintm["no_lines"]["rms_2"]["clusters"] > m["no_lines"]["rms_2"]["clusters"],
         f"норма {paintm['normalized']['corr_75']['clusters']} == "
         f"{m['normalized']['corr_75']['clusters']} при r ≥ 0.75, D6 "
         f"{paintm['no_lines']['rms_2']['clusters']} > {m['no_lines']['rms_2']['clusters']} при RMS 2"),
        ("доля изъятых пикселей здрава", 0.01 <= m["line_share"] <= 0.3, f"{m['line_share']}"),
        ("PSNR-потолок пути A высок", m["psnr_path_a"]["median_db"] > 30.0,
         f"{m['psnr_path_a']['median_db']} dB"),
        ("палитра сот меряется", m["palette_band"]["k"] == 7 and "in_band_share" in m["palette_band"],
         f"в полосе {m['palette_band']['in_band_share']}"),
    ]
    # обратный случай: все клетки разных цветов → переиспользования нет
    uniq = drawn.copy()
    rng2 = np.random.default_rng(5)
    for i in range(12):
        r, c = divmod(i, 4)
        cx = c * fit["col_step_px"] + (fit["col_step_px"] / 2 if r % 2 else 0) + 2
        cy = r * 1.5 * fit["radius_px"] + fit["radius_px"] + 2
        pts = np.round(F.hex_ring(fit["col_step_px"], fit["radius_px"], cx, cy)).astype(np.int32)
        cv2.fillPoly(uniq, [pts], tuple(int(v) for v in rng2.integers(0, 255, 3)))
    u = profile(uniq, fit, cfg)
    checks.append(("разнородный материал не называется тканью",
                   u["no_lines"]["rms_2"]["clusters"] > 0.8 * u["cells"],
                   f"{u['no_lines']['rms_2']['clusters']} кластеров при {u['cells']} клетках"))
    return checks


def synthetic(cfg: dict) -> np.ndarray:
    """Кадр с известным числом оттенков: k полос + игровая зона с сеткой."""
    rng = np.random.default_rng(11)
    img = np.zeros((720, 1080, 3), np.uint8)
    shades = [(40, 90, 40), (60, 130, 60), (200, 170, 110), (150, 120, 80),
              (90, 90, 100), (30, 30, 40), (180, 60, 60), (60, 180, 180),
              (120, 120, 120), (220, 220, 200)]
    for i, c in enumerate(shades[:6]):
        img[:, i * 180:(i + 1) * 180] = c
    img = np.clip(img.astype(np.float32) + rng.normal(0, 6, img.shape), 0, 255).astype(np.uint8)
    cv2.rectangle(img, (0, 0), (1079, 120), (200, 190, 150), -1)   # оправа без сетки
    for x in range(0, 1080, 70):
        cv2.line(img, (x, 200), (x + 30, 700), (20, 20, 20), 3)
    return np.clip(img, 0, 255).astype(np.uint8)


def self_test() -> int:
    cfg = dict(DEFAULTS)
    m = measure(synthetic(cfg), cfg)
    checks = [
        (m["play_area"][1] >= 100, f"игровая зона ниже оправы: {m['play_area']}"),
        (0.3 <= m["play_area_share"] <= 0.95, f"доля зоны {m['play_area_share']} вне здравого смысла"),
        (m["elbow_k"] in (3, 4, 5, 6), f"локоть {m['elbow_k']} для кадра с 6 оттенками"),
        (m["k_at_85pct"] is not None and m["k_at_85pct"] <= 7,
         f"k для 85% дисперсии {m['k_at_85pct']}"),
        (m["inertia"]["3"] < m["inertia"]["2"], "inertia не убывает с k"),
        (m["palette"]["spread_px"] > 50, f"разъезд палитры должен быть виден: {m['palette']['spread_px']}"),
    ]
    mf = measure(np.full((600, 900, 3), 128, np.uint8), cfg)
    checks.append((mf["palette"]["spread_px"] < 5,
                   f"однотонный кадр не должен иметь разъезда: {mf['palette']['spread_px']}"))
    bad = 0
    for ok, msg in checks:
        bad += 0 if ok else 1
        print(f"  {'ok  ' if ok else 'FAIL'} {msg}")
    for name, ok, detail in cells_self_test():
        bad += 0 if ok else 1
        print(f"  {'ok  ' if ok else 'FAIL'} клетки: {name} — {detail}")
    print("SELF-TEST:", "OK" if bad == 0 else f"FAIL ({bad})")
    return 0 if bad == 0 else 1


def policy_note() -> dict:
    """Политика шага 0 — одна запись в корне реестра, а не 63 копии.

    Шаг 2 и гейт читают её, а не пересказывают в прозе: смысл в том, чтобы «удалить
    линии», «один проход ресемплинга» и «RMS в Lab» значили в коде нарезки ровно то,
    что мерилось здесь (1.6). Значения берутся из констант модулей-измерителей, поэтому
    не могут разойтись с тем, что реально считалось."""
    return {
        "line_removal": {
            "mask": f"серое < T и насыщение < {F.LINE_SAT:g}, T = Otsu кадра × 0.8, "
                    f"ограничен [{90:g}, {200:g}]",
            "repair": "значение ближайшего сохранившегося пикселя, итерация по соседям",
            "repair_reason": "cv2.inpaint затягивает клетку краской соседней клетки",
            "source_mutated": False,
        },
        "resample": {"passes": 1, "interpolation": "INTER_AREA", "tile_px": TILE,
                     "note": "второй проход запрещён (D3); коэффициент — на сцену, в cell_profile.downscale"},
        "similarity": {"unit": "RMS по Lab без пересчёта (L 0…100, a/b ±128), только под маской гекса",
                       "cluster": "жадная склейка по первому представителю, порядок обхода детерминирован",
                       "thresholds_rms": list(CELL_RMS),
                       "reuse_rms": REUSE_RMS,
                       "normalized_scale": "RMS² = 2(1−r) по нормированным полям Lab (краска снята)"},
        "palette": {"band": GATES["palette"]["band_m"], "max_delta_e": GATES["palette"]["max_delta_e"],
                    "dominant": f"k = {len(GATES['palette']['band_m'])} (тон-кластеры, как в генераторе), "
                                f"доминантой считается тон с долей ≥ {P.DOM_SHARE:g}"},
        "cell_geometry": "точечные гексы; W = col_step_px, R = radius_px; сторона = 2R, шаг по X = W",
    }


def run_cells(a: argparse.Namespace) -> int:
    """Пачка `--cells`: только сцены с принятой геометрией, остальные — списком причины."""
    cfg = dict(DEFAULT_CELLS)
    reg = L.load_registry()
    kit = L.kit_dir(a.kit)
    names = [a.scene] if a.scene else L.kit_files(kit)
    out, skip = {}, []
    for name in names:
        fit = reg.get("scenes", {}).get(name, {}).get("cell_fit") or {}
        if not fit.get("accepted"):
            skip.append((name, fit.get("reason") or "геометрия не мерилась"))
            continue
        path = Path(name) if Path(name).is_file() else kit / name
        bgr = cv2.imread(str(path))
        if bgr is None:
            print(f"СЦЕНА {name}: НЕЧИТАЕМА", file=sys.stderr)
            return 2
        rec = profile(cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB), fit, cfg)
        rec["sha256"] = L.sha256(path)
        out[name] = rec
        print(f"ПРОФИЛЬ {name[:40]} — {json.dumps(rec['reuse'], ensure_ascii=False)}; "
              f"PSNR {rec['psnr_path_a']['median_db']} dB; "
              f"палитра в полосе {rec['palette_band']['in_band_share']} → "
              f"после перекраски {rec['palette_band']['in_band_share_recolored']}")
    if a.update and out:
        reg["policy"] = policy_note()
        scenes = reg.setdefault("scenes", {})
        for name, rec in out.items():
            scenes.setdefault(name, {})["cell_profile"] = rec
        L.REGISTRY.write_text(json.dumps(reg, ensure_ascii=False, indent=1) + "\n")
        print(f"РЕЕСТР: {L.REGISTRY} — профилей записано: {len(out)}")
    if out:
        n = [r["cells"] for r in out.values()]
        w = [r["with_lines"][f"rms_{REUSE_RMS:g}"]["clusters"] for r in out.values()]
        wo = [r["no_lines"][f"rms_{REUSE_RMS:g}"]["clusters"] for r in out.values()]
        mx = [r["no_lines"][f"rms_{REUSE_RMS:g}"]["max_cluster_share"] for r in out.values()]
        ps = [r["psnr_path_a"]["median_db"] for r in out.values()]
        ib = [r["palette_band"]["in_band_share"] for r in out.values()]
        ir = [r["palette_band"]["in_band_share_recolored"] for r in out.values()]
        print(f"\nсцен с профилем {len(out)} (пропущено {len(skip)}): клеток p50 {statistics.median(n):.0f}")
        print(f"  тканей при RMS ≤ {REUSE_RMS:g}: с линиями p50 {statistics.median(w):.0f} → "
              f"без линий p50 {statistics.median(wo):.0f}; наибольшая ткань p50 {statistics.median(mx):.2f}")
        print(f"  PSNR-потолок пути A: p50 {statistics.median(ps):.1f} dB, "
              f"мин {min(ps):.1f} dB")
        print(f"  палитра сот в полосе M (ΔE ≤ {cfg['max_delta_e']:g}): p50 {statistics.median(ib):.2f}"
              f" → после перекраски p50 {statistics.median(ir):.2f}")
    for name, why in skip:
        print(f"ПРОПУСК {name[:40]} — {why}")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--scene", default="")
    ap.add_argument("--kit", default="")
    ap.add_argument("--cells", action="store_true",
                    help="профиль переиспользования по маске гекса (1.3–1.5), а не профиль кадра")
    ap.add_argument("--update", action="store_true")
    ap.add_argument("--self-test", action="store_true")
    a = ap.parse_args()
    if a.self_test:
        return self_test()
    if a.cells:
        return run_cells(a)

    cfg = dict(DEFAULTS)
    reg = L.load_registry()
    cfg.update(reg.get("thresholds", {}))
    cfg.update({k: v for k, v in reg.get("thresholds", {}).items() if k in cfg})
    kit = L.kit_dir(a.kit)
    names = [a.scene] if a.scene else L.kit_files(kit)
    out = {}
    for name in names:
        bgr = cv2.imread(str(kit / name))
        if bgr is None:
            print(f"СЦЕНА {name}: НЕЧИТАЕМА", file=sys.stderr)
            return 2
        rec = measure(cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB), cfg)
        rec["sha256"] = L.sha256(kit / name)
        rec["size"] = list(bgr.shape[1::-1])
        out[name] = rec
        print(json.dumps({name: rec}, ensure_ascii=False))
    if a.update:
        reg["thresholds"] = {**reg.get("thresholds", {}), **{f"cl_{k}": v for k, v in cfg.items()}}
        scenes = reg.setdefault("scenes", {})
        for name, rec in out.items():
            # запись сцены дополняется, а не заменяется: решётка и кластеры —
            # разные прогоны одного кадра, последний не имеет права стирать первый
            scenes.setdefault(name, {}).update(rec)
        L.REGISTRY.write_text(json.dumps(reg, ensure_ascii=False, indent=1) + "\n")
        print(f"РЕЕСТР: {L.REGISTRY} — записей сцен: {len(reg['scenes'])}")
    if not a.scene:
        ks = [r["elbow_k"] for r in out.values()]
        k85 = [r["k_at_85pct"] for r in out.values() if r["k_at_85pct"]]
        sp = [r["palette"]["spread_px"] for r in out.values()]
        ar = [r["play_area_share"] for r in out.values()]
        print(f"\nкадров {len(out)}: локоть k — мин {min(ks)} медиана {statistics.median(ks)} макс {max(ks)}")
        print(f"                 k для 85% — медиана {statistics.median(k85) if k85 else '—'} "
              f"макс {max(k85) if k85 else '—'} (порог D-309 «к=6 и кривая не просит большего»)")
        print(f"                 разъезд палитры p50 {statistics.median(sp):.0f} макс {max(sp):.0f} px")
        print(f"                 игровая зона: доля кадра p50 {statistics.median(ar):.2f} "
              f"мин {min(ar):.2f}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Геометрия сцены по сотам: маска линий → полости-соты → решётка + гомография (Q-M136 (а)).

Шаг 0 (`docs/mvp/SCENE-SLICE-MEASURE.md`) решил «геометрия не восстанавливается». Он был
невер по причине: корреляционный фитт искал *равносторонние* шестиугольники в окне без
перспективы, а нарисованы — растянутые по горизонтали и лежащие под лёгким перспективным
искажением. Мера здесь другая и она работает: соты кадра = связные полости маски
нарисованных линий; их центры привязываются к решётке, а остаток закрывается гомографией
(замер на первой размеченной сцене: 7.1 → 1.11 px медиана, 24.6 → 2.61 px p95).

Порядок такой же, как у человека, который режет карту руками: зона из разметки, по ней
маска линий, по маске соты, по сотам решётка и поправка, остаток — вердикт.

    python3 scripts/fit_scene_cells.py --self-test
    python3 scripts/fit_scene_cells.py --scene=<файл>            # одна сцена
    python3 scripts/fit_scene_cells.py --all --update            # пачка, результат в реестр

Ручная разметка зоны — `scripts/annotate_scenes.py`, но нужна она не всем кадрам:
период измеряется по соседям сот, а декоративная оправа не образует шестиугольных
полостей и отпадает фильтром формы. Руки вызываются там, где соты не прочитались или
не привязались (очередь — поле `reason` в реестре).
"""
from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

import cv2
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import measure_scene_lattice as L  # noqa: E402  (тот же комплект, реестр, пороги)

# Маска линий: нарисованная сетка — тёмная и почти обесцвеченная поверх пёстрого рельефа.
# Ридж-фильтр с одним порогом по 63 рисункам её не находил; порог по яркости (Otsu кадра)
# и насыщенности даёт чистые линии: первый кадр — 9.2% пикселей, глаз видит сетку.
LINE_GRAY = 150          # верхняя граница «тёмного», если Otsu не задался
LINE_GRAY_AUTO = True    # граница по Otsu: кадры нарисованы в разной осветке
LINE_SAT = 60
CELL_MIN_AREA = 500        # px²: полости мельче — крап текстуры, а не сота
CELL_MIN_SHARE = 0.25      # относительно модальной площади соты
DILATE = 2                 # итерации утолщения линий: щели в рисунке иначе сливают соты
MAX_RESIDUAL_P95 = 4.0     # AC: остаток решётки после поправки, p95, px


def line_mask(rgb: np.ndarray, roi: tuple[int, int, int, int]) -> np.ndarray:
    """Тёмные малонасыщенные пиксели внутри игровой зоны — нарисованные линии сетки."""
    gray = cv2.cvtColor(rgb, cv2.COLOR_RGB2GRAY)
    g = gray.astype(np.int16)
    sat = rgb.max(axis=2).astype(np.int16) - rgb.min(axis=2).astype(np.int16)
    t = LINE_GRAY
    if LINE_GRAY_AUTO:
        x = gray[roi[1]:roi[1] + roi[3], roi[0]:roi[0] + roi[2]]
        if x.size > 1000:
            otsu, _ = cv2.threshold(x, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
            t = float(np.clip(otsu * 0.8, 90, 200))
    m = ((g < t) & (sat < LINE_SAT)).astype(np.uint8)
    x, y, w, h = roi
    keep = np.zeros_like(m)
    keep[y:y + h, x:x + w] = 1
    return m * keep


def cells_of(mask: np.ndarray) -> np.ndarray:
    """Центры сот — связные полости маски линий. Возвращает (N,2) float."""
    lines = cv2.dilate(mask, np.ones((3, 3), np.uint8), iterations=DILATE)
    holes = 1 - lines
    n, _lab, stats, cent = cv2.connectedComponentsWithStats(holes, 8)
    h, w = mask.shape
    if n <= 1:
        return np.zeros((0, 2))
    area = stats[1:, 4].astype(float)
    # Размер соты заранее неизвестен, но модальная площадь — известна из самой маски:
    # медиана по полостям мелькает на крапе текстуры (мелкие петли дают медиану 57 px²),
    # поэтому режим ищется по лог-гистограмме крупных полостей.
    big = area[area >= CELL_MIN_AREA]
    if len(big) < 6:
        return np.zeros((0, 2))
    hist, edges = np.histogram(np.log10(big), bins=12)
    modal = float(10 ** ((hist.argmax() + 0.5) * (edges[1] - edges[0]) + edges[0]))
    lo, hi = modal * CELL_MIN_SHARE, modal * 2.2
    out = []
    for i in range(1, n):
        x, y, cw, ch, a = stats[i]
        if not (lo <= a <= hi):
            continue
        if x <= 2 or y <= 2 or x + cw >= w - 2 or y + ch >= h - 2:
            continue                       # полость, прорезанная краем зоны, — не сота
        if not (0.35 <= cw / max(ch, 1) <= 1.9):   # форма соты: около квадратной
            continue
        out.append(cent[i])
    return np.asarray(out, dtype=float)


def steps(P: np.ndarray) -> tuple[float, float]:
    """Шаг колонок C и шаг строк rstep по соседям сот: гистограмма разностей.

    Offset-решётка (нечётные ряды сдвинуты на полколонки): сосед «по горизонтали» даёт
    C, сосед со сдвигом в полколонки — rstep. Строго вертикальный сосед стоит через
    два ряда (2·rstep), поэтому по нему шаг не берут — на этом читался бы двойной период.
    """
    if len(P) < 6:
        return 0.0, 0.0
    d = P[:, None, :] - P[None, :, :]

    def mode(vals: np.ndarray, lo: float, hi: float) -> float:
        v = vals[(vals > lo) & (vals < hi)]
        if len(v) < 3:
            return 0.0
        hist, edges = np.histogram(v, bins=np.arange(lo, hi + 1, 2.0))
        return float((edges[int(np.argmax(hist))] + edges[int(np.argmax(hist)) + 1]) / 2)

    same_row = np.abs(d[..., 1]) < 6
    C = mode(np.abs(d[..., 0])[same_row], 40, 220)
    half = np.abs(np.abs(d[..., 0]) - (C / 2 if C else -9)) < 6
    rstep = mode(np.abs(d[..., 1])[half], 25, 220)
    if not rstep:                       # запасной ход: вертикальный сосед через ряд
        v = np.abs(d[..., 1])[(np.abs(d[..., 0]) < 6) & (np.abs(d[..., 1]) > 25)]
        rstep = float(np.median(v) / 2) if len(v) >= 3 else 0.0
    return float(C), float(rstep)


def offset_of(P: np.ndarray, C: float, rstep: float) -> tuple[float, float]:
    """Начало решётки: мода остатков координат сот по модулю периода."""
    r = np.round((P[:, 1]) / rstep)
    x = P[:, 0] - (C / 2 * (r.astype(int) % 2))
    ox = float(np.median((x - C * np.round(x / C) + C / 2) % C - C / 2))
    oy = float(np.median((P[:, 1] - rstep * r + rstep / 2) % rstep - rstep / 2))
    return ox, oy


def match(P: np.ndarray, C: float, rstep: float, Hinv: np.ndarray,
          tol: float) -> tuple[np.ndarray, np.ndarray]:
    """Пара «узел идеальной решётки ↔ сота кадра» по ближайшему узлу.

    Соты переводятся в идеальную плоскость обратной гомографией и там округляются до
    узла: пока допуск считается в идеальных пикселях, перспектива кадра не сбрасывает
    соту в чужой узел (в плоскости кадра она гуляет на десятки пикселей).
    """
    Q = cv2.perspectiveTransform(P.reshape(-1, 1, 2), Hinv).reshape(-1, 2)
    r = np.round(Q[:, 1] / rstep)
    c = np.round((Q[:, 0] - (C / 2 * (r.astype(int) % 2))) / C)
    node = np.stack([c * C + (C / 2 * (r.astype(int) % 2)), r * rstep], axis=1)
    good = np.linalg.norm(Q - node, axis=1) < tol
    return node, good


def fit(P: np.ndarray) -> dict:
    """По центрам сот → (C, R, начало, гомография, остаток). R = rstep/1.5 — расстояние
    от центра соты до вершины по вертикали; соты растянуты, поэтому R не √3-связана с C.

    Порядок — как у человека, ведущего сетку по кадру: прикинуть шаг, привязать соты,
    по привязке поправить перспективу, привязать заново уже ровно (допуск сужается).
    """
    if len(P) < 8:
        return {"accepted": False, "reason": f"сот найдено {len(P)} (<8)"}
    C0, rs0 = steps(P)
    if not C0 or not rs0:
        return {"accepted": False, "reason": "шаг сот не измерился"}
    best = None
    # шаг по соседям читается с кратными ошибками (сосед через ряд, склейка двух мод),
    # поэтому перебираются кратные кандидаты и берётся тот, что даёт больше привязок
    for C in (C0, 2 * C0):
        for rstep in (rs0, 2 * rs0):
            H = np.eye(3, dtype=np.float64)
            for tol in (0.6, 0.45, 0.18):
                node, good = match(P, C, rstep, np.linalg.inv(H), tol * C)
                if good.sum() < 8:
                    break
                src = node[good].astype(np.float32)
                dst = P[good].astype(np.float32)
                Hn, inl = cv2.findHomography(src, dst, cv2.RANSAC, 3.0)
                if Hn is None:
                    break
                H = Hn
            node, good = match(P, C, rstep, np.linalg.inv(H), 0.12 * C)
            if good.sum() < 8:
                continue
            src = node[good].astype(np.float32)
            dst = P[good].astype(np.float32)
            pred = cv2.perspectiveTransform(src.reshape(-1, 1, 2), H).reshape(-1, 2)
            res = np.linalg.norm(pred - dst, axis=1)
            if int(good.sum()) < 0.6 * len(P) or not (0.6 <= C / (math.sqrt(3) * rstep / 1.5) <= 2.0):
                continue
            score = (int(good.sum()) - 0.002 * C * rstep, -float(np.median(res)))
            if best is None or score > best[0]:
                best = (score, C, rstep, H, good, res, src)
    if best is None:
        return {"accepted": False, "reason": "соты не привязались к решётке"}
    _, C, rstep, H, good, res, src = best
    ox, oy = offset_of(cv2.perspectiveTransform(src.reshape(-1, 1, 2), np.linalg.inv(H))
                       .reshape(-1, 2), C, rstep)
    R = rstep / 1.5
    p95 = float(np.percentile(res, 95))
    return {
        "cells": int(good.sum()),
        "cells_found": int(len(P)),
        "col_step_px": round(float(C), 2),
        "row_step_px": round(float(rstep), 2),
        "radius_px": round(float(R), 2),
        "stretch": round(float(C / (math.sqrt(3) * R)), 3),   # 1.0 = равносторонние
        "origin": [round(float(ox), 1), round(float(oy), 1)],
        "homography": [[round(float(v), 6) for v in row] for row in H],
        "residual_px": round(float(np.median(res)), 2),
        "residual_p95_px": round(p95, 2),
        "inliers": int(good.sum()),
        "coverage": round(float(good.sum()) / max(len(P), 1), 2),
        "accepted": bool(p95 <= MAX_RESIDUAL_P95 and good.sum() >= 20
                         and good.sum() >= 0.6 * len(P)),
        "reason": ("" if p95 <= MAX_RESIDUAL_P95 and good.sum() >= 20
                   and good.sum() >= 0.6 * len(P) else
                   (f"остаток p95 {p95:.2f} px > {MAX_RESIDUAL_P95} px" if p95 > MAX_RESIDUAL_P95
                    else f"сот привязано {int(good.sum())} из {len(P)}")),
    }


def warped_centers(C: float, R: float, shape, H, ox: float, oy: float) -> np.ndarray:
    """Узлы решётки, прогнанные через гомографию, — по ним и резать."""
    rstep = 1.5 * R
    rows = range(-1, int(shape[0] / rstep) + 2)
    cols = range(-1, int(shape[1] / C) + 2)
    P = np.array([[c * C + (C / 2 if r % 2 else 0) + ox, r * rstep + oy]
                  for r in rows for c in cols], np.float32)
    return cv2.perspectiveTransform(P.reshape(-1, 1, 2), H).reshape(-1, 2)


def hex_ring(C: float, R: float, cx: float, cy: float) -> np.ndarray:
    """Вершины соты: центр + шесть углов (плосковерхая в смысле рисунка — вертикальные
    рёбра по бокам), координаты кадровой системы после гомографии."""
    return np.array([[cx, cy - R], [cx + C / 2, cy - R / 2], [cx + C / 2, cy + R / 2],
                     [cx, cy + R], [cx - C / 2, cy + R / 2], [cx - C / 2, cy - R / 2]])


def self_test() -> int:
    """Синтетика с заведомой перспективой: шаг, радиус и остаток должны вернуться."""
    C, R = 107.0, 52.0
    rstep = 1.5 * R
    H = cv2.getPerspectiveTransform(
        np.array([[0, 0], [1000, 0], [0, 700], [1000, 700]], np.float32),
        np.array([[0, 20], [1010, 0], [18, 700], [990, 712]], np.float32))
    P = warped_centers(C, R, (700, 1000), H, 81.0, 18.0)
    P = P[(P[:, 0] > 60) & (P[:, 0] < 940) & (P[:, 1] > 60) & (P[:, 1] < 640)]
    rng = np.random.default_rng(0)
    P = P + rng.normal(0, 0.7, P.shape)                # дрожание рисунка, px
    P = P[rng.random(len(P)) > 0.15]                   # часть сот не читается
    got = fit(P)
    checks = [
        ("шаг колонок", abs(got.get("col_step_px", 0) - C) <= 2.0, f"{got.get('col_step_px')} vs {C}"),
        ("радиус соты", abs(got.get("radius_px", 0) - R) <= 2.0, f"{got.get('radius_px')} vs {R}"),
        ("остаток p95", got.get("residual_p95_px", 99) <= 2.0, f"{got.get('residual_p95_px')} px"),
        ("вердикт", got.get("accepted") is True, got.get("reason", "ok")),
    ]
    for name, ok, detail in checks:
        print(f"{'ok  ' if ok else 'FAIL'} {name}: {detail}")
    # и обратный ход: решётка по замеренным параметрам попадает в те же соты
    ring = hex_ring(C, R, *P[0])
    ok = len(ring) == 6 and ring[:, 0].max() - ring[:, 0].min() <= C + 1
    print(f"{'ok  ' if ok else 'FAIL'} вершина соты строится по C и R")
    return 0 if all(c[1] for c in checks) and ok else 1


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--kit", default="")
    ap.add_argument("--scene", default="")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--update", action="store_true", help="записать замеры в реестр сцен")
    ap.add_argument("--self-test", action="store_true")
    ap.add_argument("--debug", default="", help="префикс: положить маску и накладку сот")
    a = ap.parse_args()
    if a.self_test:
        return self_test()

    kit = L.kit_dir(a.kit)
    reg = L.load_registry()
    names = L.kit_files(kit) if a.all else ([a.scene] if a.scene else [])
    if not names:
        sys.exit("--scene=<файл> или --all")
    done = 0
    for name in names:
        rec0 = reg.get("scenes", {}).get(name, {})
        man = (rec0.get("manual") or {}).get("roi")
        # Ручная зона (Q-M136 (а)) — то, что разметчик подтвердил глазами. Без неё сцена
        # не пропускается, а меряется по кадру целиком: соты отсекаются по форме, декор
        # выбрасывает RANSAC, и вердикт замера сам показывает, где разметка нужна.
        whole = not man
        path = Path(name) if Path(name).is_file() else kit / name
        bgr = cv2.imread(str(path))
        if bgr is None:
            sys.exit(f"не читается кадр: {path}")
        rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
        h0, w0 = rgb.shape[:2]
        roi = tuple(int(v) for v in man) if man else (0, 0, w0, h0)
        mask = line_mask(rgb, roi)
        P = cells_of(mask)
        out = fit(P)
        out["roi"] = list(roi)
        out["roi_source"] = "whole-frame" if whole else "manual"
        out["sha256"] = L.sha256(path)
        out["size"] = [rgb.shape[1], rgb.shape[0]]
        done += 1
        flag = "РЕШЕТКА" if out.get("accepted") else "СЕТКА НЕ СОШЛАСЬ"
        if whole:
            flag += "?"
        print(f"{flag} {name[:46]} — {json.dumps(out, ensure_ascii=False)[:220]}")
        if a.debug:
            overlay = (np.dstack([mask * 255] * 3)).astype(np.uint8)
            if out.get("homography"):
                H = np.array(out["homography"], np.float32)
                for p in warped_centers(out["col_step_px"], out["radius_px"],
                                        mask.shape, H, *out["origin"]):
                    cv2.polylines(overlay, [hex_ring(out["col_step_px"], out["radius_px"],
                                                     p[0], p[1]).reshape(-1, 1, 2)
                                            .astype(np.int32)], True, (255, 0, 0), 1)
                for p in P:
                    cv2.circle(overlay, (int(p[0]), int(p[1])), 4, (0, 255, 0), -1)
            Path(a.debug).parent.mkdir(parents=True, exist_ok=True)
            cv2.imwrite(f"{a.debug}-{Path(name).stem[:18]}.png",
                        cv2.cvtColor(overlay, cv2.COLOR_RGB2BGR))
        if a.update:
            L.update_registry({name: {"cell_fit": out}})
    print(f"обработано сцен: {done} из {len(names)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

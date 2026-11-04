#!/usr/bin/env python3
"""Фитт решётки нарисованных гексов в ИИ-сцене карты (openspec: world-map-scene-slicing, D2).

Сцена — кадр игровой зоны, поверх которого нарисована гексагональная сетка. Прежде чем
резать её на тайлы движка, нужен воспроизводимый ответ на три числа: какая ориентация
рисуется (а не предполагается), каков период решётки и насколько рисунок от неё
отклоняется. Метод — детерминированный, без RNG и без ручной простановки чисел.

    python3 scripts/measure_scene_lattice.py --self-test       # синтетика, без исходников
    python3 scripts/measure_scene_lattice.py --list            # что в комплекте машины
    python3 scripts/measure_scene_lattice.py --all             # все сцены, JSON на сцену
    python3 scripts/measure_scene_lattice.py --scene=<файл> [--roi=x,y,w,h] [--update]
    python3 scripts/measure_scene_lattice.py --scene=<файл> --debug=tmp/dbg   # кадр-доказательства
    python3 scripts/measure_scene_lattice.py --all --geometry  # только период/ориентация
                                                            # по штрихам, 6 c на 63 кадра

Путь к комплекту — настройка машины `MAP_SCENE_KIT` (в репозитории путей нет, D8);
файл настроек — тот же, что читает game/run_tests.sh (`SOTU_MACHINE_ENV`).

Шаги:

1. отклик «тонкая линия» — крыша (top-hat) по яркости в **обеих** полярностях,
   взвешенная по низкой насыщенности: в комплекте линии бывают и светлыми на тёмном
   террейне, и тёмными на светлом, а служат они серыми;
2. coarse-скан периода нормированной корреляцией (TM_CCOEFF_NORMED) при связи
   `H = 2W/√3` (pointy) и `H = W√3/2` (flat) — ориентация **меряется**, какой моделью
   линии совпали лучше; нормировка нужна, что бы контраст рамки и террейна не
   перевешивал сигнал (замер на реальной сцене: чёрный black-hat давал пик на текстуре);
3. игровая зона — область, где та же корреляционная карта яркая: сетка покрыла её,
   рамка мира (лес, горы, лава) не объясняется решёткой вовсе. Это же признак
   классификации «покрыто сеткой / рамка» (шаг 2.1);
4. поле периода по девяти окнам зоны (шаг coarse_step_px) — им же измеряется
   перспектива: разброс локальных W (`width_spread_px`) растёт, а plane R² остаётся
   низким, значит рисунок лежит на плоскости земли и аффинная решётка ему не принадлежит;
5. fine-уточнение W по левой/правой половине (0.25 px, потом 0.05 px) и начало решётки;
   расхождение половин — `drift_px`, тот же шаг, что и у gates, иначе квант поиска
   (±4 px) сам выдаётся за дрейф;
6. независимая геометрия по штрихам (`stroke_geometry`): период из профиля столбцов и
   ориентация по длинам рёбер. Она не зависит от подгонки и обязана сходиться с ней там,
   где подгонка нашла сигнал; расхождение двух способов и есть честный ответ;
7. меры качества: вершина корреляции (целиком и по частям зоны — по ней видно, что
   аффинная решётка «уезжает» к краям), расстояние Патаняла от линий решётки до
   нарисованных линий, и доля нарисованных линий, объяснённых решёткой (целиком и по
   девяти зонам — `coverage_field`).

Сцена, у которой меры хуже порогов реестра, отвергается с числами, а не
«приближённой геометрией» (`world-map-scene-slicing`, «Решётка не сошлась»).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import re
import sys
from pathlib import Path

import cv2
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
REGISTRY = ROOT / "game/data/config/scene_slices.json"
SQRT3 = math.sqrt(3.0)
# Дефолты. Сила — за записанным в реестре ДО прогона набором (task 1.6); здесь они
# только для --self-test и для случая «реестра ещё нет».
DEFAULTS = {
    "line_ridge_px": 21,
    "line_threshold": 60.0,
    "roi_on_quantile": 99.9,
    "roi_min_area": 0.15,
    "width_min": 50,
    "width_max": 200,
    "coarse_scale": 2,
    "coarse_step_px": 2.0,
    "fine_span_px": 2.5,
    "fine_step_px": 0.25,
    "pin_span_px": 6.0,            # полоса вокруг ручной W: глазами лучше пикселя не ждут
    "pin_step_px": 0.25,
    "stroke_quantile": 85.0,       # порог «здесь линия» для поиска штрихов
    "stroke_len_px": 15,           # длина штриха: меньше — рваные линии, больше — ничего
    "ultra_step_px": 0.05,
    "min_peak": 0.20,
    "max_coverage_spread": 0.35,
    "max_chamfer_p95_px": 4.0,
    "min_line_coverage": 0.5,
    "max_drift_px": 1.5,
    "local_min_peak": 0.30,
}


def cfg_for(reg: dict) -> dict:
    """Пороги реестра поверх дефолтов: реестр переписывает, чего каснулся."""
    out = dict(DEFAULTS)
    out.update(reg.get("thresholds", {}))
    return out


# ------------------------------------------------------------------ источник


def machine_env() -> dict:
    """Значения настроек машины (файл вне репозитория) + окружение поверх них.

    Формат тот же, что читает game/run_tests.sh: `: "${VAR:=значение}"` — переменная
    из окружения перекрывает файл, пустая не перекрывает.
    """
    path = Path(os.environ.get("SOTU_MACHINE_ENV",
                               Path.home() / ".pi/agent/env/sotu-machine.env"))
    vals: dict[str, str] = {}
    if path.is_file():
        for m in re.finditer(r'^\s*:\s*"\$\{(\w+):=([^"}]*)\}"', path.read_text(), re.M):
            vals[m.group(1)] = os.path.expanduser(m.group(2))
    vals.update({k: v for k, v in os.environ.items() if v and k.startswith("MAP_SCENE")})
    return vals


def kit_dir(cli: str = "") -> Path:
    if cli:
        return Path(cli).expanduser()
    val = machine_env().get("MAP_SCENE_KIT", "").strip()
    if not val:
        sys.exit("MAP_SCENE_KIT не задан — путь к комплекту сцен это настройка машины "
                 "(~/.pi/agent/env/sotu-machine.env), в репозитории её нет (D8)")
    return Path(val)


def kit_files(kit: Path) -> list[str]:
    return sorted(p.name for p in kit.iterdir()
                  if p.suffix.lower() in (".png", ".jpg", ".jpeg") and p.is_file())


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for block in iter(lambda: fh.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


# ------------------------------------------------------------------ линии


def line_response(rgb: np.ndarray, cfg: dict) -> np.ndarray:
    """Отклик «тонкая линия»: top-hat по яркости в обеих полярностях × вес нейтрали.

    Служебные линии тонкие (2–3 px) и почти бесцветные; террейн цветной, а его
    прожилки режет вес по насыщенности. Ядро заведомо шире линии, поэтому в отклик
    попадают и широкие тёмные пятна — их не оплачивает согласованный фильтр по всей
    решётке. Полярность берётся максимумом: в комплекте сетка лежит и светлыми
    линиями на тёмном поле, и тёмными на светлом (замер 2026-11-08).
    """
    gray = cv2.cvtColor(rgb, cv2.COLOR_RGB2GRAY)
    k = int(cfg["line_ridge_px"]) | 1
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (k, k))
    ridge = np.maximum(cv2.morphologyEx(gray, cv2.MORPH_TOPHAT, kernel),
                       cv2.morphologyEx(gray, cv2.MORPH_BLACKHAT, kernel))
    sat = rgb.max(axis=2).astype(np.int16) - rgb.min(axis=2).astype(np.int16)
    resp = (ridge.astype(np.float32) / 255.0) * np.clip(1.0 - sat / 96.0, 0.0, 1.0)
    return cv2.GaussianBlur(resp, (0, 0), 1.2)


def line_mask(resp: np.ndarray, cfg: dict) -> np.ndarray:
    """Нарисованные линии: где отклик превысил порог. Булева — под маской индекса.

    Слабое место меры, зафиксированное намеренно: абсолютный порог по кадру не
    переносится между кадрами комплекта (штрихи по этому порогу находятся в 22 кадрах
    из 63 — `docs/mvp/SCENE-SLICE-MEASURE.md`). Замена на маску штрихов (`strokes`)
    опробована: она строже по форме, но роняет покрытие даже на синтетике 0.98 → 0.31,
    то есть требует своего порога и своего прогона. До вердикта Q-M136 остаётся
    документированная мера, а не недокалиброванная новая.
    """
    return resp * 255.0 >= float(cfg["line_threshold"])


# ------------------------------------------------------------------ решётка


def hex_size(W: float, orientation: str) -> tuple[float, float, float, float]:
    """(W, H, col_step, row_step) решётки по ширине гекса.

    pointy-top: H = 2W/√3 (H/W = 1.1547), ряды шагом 0.75H с нечётным рядом,
    сдвинутым на W/2; flat-top — поворот на 90°: H = W√3/2, столбцы шагом 0.75W со
    сдвигом на H/2. Это та же раскладка, что рисует движок (TILE_SHAPE_HEXAGON).
    """
    if orientation == "pointy":
        H = 2.0 * W / SQRT3
        return W, H, W, 0.75 * H
    H = W * SQRT3 / 2.0
    return W, H, 0.75 * W, H


def period_size(W: float, orientation: str) -> tuple[int, int]:
    """Размер окна периода узора линий: pointy — (W, 1.5H), flat — (1.5W, H)."""
    _, H, _, _ = hex_size(W, orientation)
    if orientation == "pointy":
        return int(round(W)), int(round(1.5 * H))
    return int(round(1.5 * W)), int(round(H))


def hex_centers(orientation: str, W: float, span_x: float, span_y: float) -> list[np.ndarray]:
    """Вершины всех гексов, чьи центры попали в окно с запасом в ряд."""
    _, H, cstep, rstep = hex_size(W, orientation)
    R = H / 2.0 if orientation == "pointy" else W / 2.0
    base = (90.0, 150.0, 210.0, 270.0, 330.0, 30.0) if orientation == "pointy" \
        else (0.0, 60.0, 120.0, 180.0, 240.0, 300.0)
    cos, sin = np.cos(np.radians(base)), np.sin(np.radians(base))
    out = []
    for row in range(-2, int(math.ceil(span_y / rstep)) + 2):
        for col in range(-2, int(math.ceil(span_x / cstep)) + 2):
            if orientation == "pointy":
                cx = col * cstep + (0.5 * cstep if row % 2 else 0.0)
                cy = row * rstep
            else:
                cx = col * cstep
                cy = row * rstep + (0.5 * rstep if col % 2 else 0.0)
            out.append(np.stack([cx + R * cos, cy + R * sin], axis=1).astype(np.float32))
    return out


def draw_full_lattice(shape: tuple[int, int], orientation: str, W: float,
                      origin: tuple[float, float], thickness: int = 2) -> np.ndarray:
    """Линии решётки по кадру целиком — прямой рендер (истина теста, независимая от окна)."""
    h, w = shape
    img = np.zeros((h, w), np.uint8)
    for hexes in hex_centers(orientation, W, w + W, h + W):
        pts = hexes + np.array(origin, np.float32)
        cv2.polylines(img, [pts.reshape(-1, 1, 2).astype(np.int32)], True, 1,
                      thickness=thickness)
    return img.astype(bool)


def lattice_tile(orientation: str, W: float, thickness: float = 1.0) -> np.ndarray:
    """Шаблон согласованного фильтра — окно в один период линий решётки.

    Окно целочисленное, вершины от дробного W: для шаблона это безразлично (пик
    совпадения локален), а плитка целого period-box'а накапливала бы ошибку периода.
    """
    pw, ph = period_size(W, orientation)
    return draw_full_lattice((ph, pw), orientation, W, (0.0, 0.0),
                             thickness=max(1, int(round(thickness))))


def lattice_grid(shape: tuple[int, int], orientation: str, W: float,
                 origin: tuple[float, float]) -> np.ndarray:
    """Решётка в окне заданного размера — прямой рендер от дробного периода и начала."""
    return draw_full_lattice(shape, orientation, W, origin, thickness=1)


# ------------------------------------------------------------------ подгонка


def corr_map(resp: np.ndarray, orientation: str, W: float, scale: float = 1.0):
    """Карта нормированной корреляции с шаблоном решётки (или (карта, None) мало кадра)."""
    if scale != 1.0:
        resp = cv2.resize(resp, (max(16, int(resp.shape[1] / scale)),
                                 max(16, int(resp.shape[0] / scale))),
                          interpolation=cv2.INTER_AREA)
    u8 = (np.clip(resp, 0.0, 1.0) * 255.0).astype(np.uint8)
    templ = (lattice_tile(orientation, W / scale) * 255.0).astype(np.uint8)
    if u8.shape[0] < templ.shape[0] or u8.shape[1] < templ.shape[1]:
        return None, None
    return cv2.matchTemplate(u8, templ, cv2.TM_CCOEFF_NORMED), templ


def corr_peak(resp: np.ndarray, orientation: str, W: float, scale: float = 1.0) -> float:
    """Лучшая нормированная корреляция кадра с решёткой периода W."""
    sm, _ = corr_map(resp, orientation, W, scale)
    return -1.0 if sm is None else float(sm.max())


def scan_width(resp: np.ndarray, orientation: str, lo: float, hi: float, step: float,
               scale: float = 1.0) -> tuple[float, float]:
    """Скан периода шагом → (лучший W, его вершина). Детерминированный: шаг за шагом."""
    best_W, best = lo, -1.0
    W = lo
    while W <= hi + 1e-9:
        p = corr_peak(resp, orientation, W, scale)
        if p > best:
            best_W, best = W, p
        W += step
    return best_W, best


def refine_width(resp: np.ndarray, orientation: str, W0: float, span: float,
                 step: float, ultra_step: float) -> tuple[float, float, int, int]:
    """Уточнение периода и начала: (W, вершина, dy, dx) — сначала шагом, потом тонко."""
    W, peak = scan_width(resp, orientation, max(4.0, W0 - span), W0 + span, step)
    W, peak = scan_width(resp, orientation, max(4.0, W - step), W + step, ultra_step)
    sm, templ = corr_map(resp, orientation, W)
    i, j = np.unravel_index(int(np.argmax(sm)), sm.shape)
    return W, float(sm[i, j]), int(i - templ.shape[0] + 1), int(j - templ.shape[1] + 1)


def density_map(resp: np.ndarray, orientation: str, W: float, cfg: dict) -> np.ndarray:
    """Булева карта «здесь линии совпали с решёткой периода W».

    Порог — квантиль самой карты: в зоне сетки горят соединения рёбер (~0.1% кадра),
    в рамке мира не горит ничего, и доля «объяснённых» пикселов от кадра не зависит,
    если решётка занимает хотя бы пару процентов кадра (иначе квантиль уходит выше
    собственного сигнала и зона не находится вовсе — тогда явный отказ с --roi).
    """
    sm, _ = corr_map(resp, orientation, W)
    if sm is None:
        return np.zeros(resp.shape, bool)
    on = sm > float(np.percentile(sm, float(cfg["roi_on_quantile"])))
    out = np.zeros(resp.shape, bool)
    out[:sm.shape[0], :sm.shape[1]] = on
    return out


def region_from_density(on: np.ndarray, W: float,
                        cfg: dict) -> tuple[int, int, int, int, bool, np.ndarray]:
    """Игровая зона — связная область, где решётка объясняет рисунок.

    Точечная карта склеивается закрытием в гекс, чистится открытием и отступает на
    четверть гекса: на границе зоны рисунок обрывается, и «объяснено/не объяснено»
    там ничего не значит. Прямоугольник зоны даётся по крупному компоненту, маска —
    уже внутри него (именно ей отсекается остаток, а не всему кадру).

    Рамка мира сеткой не покрыта, и корреляция с решёткой в ней падает до шума,
    поэтому граница зоны — производная от той же меры, которой фиттим, а не
    отдельное допущение. Спорит граница — сцена идёт в тикет с --roi, а не в
    «приближённую геометрию».
    """
    h, w = on.shape
    empty = (0, 0, w, h, False, np.ones((h, w), bool))
    u8 = on.astype(np.uint8)
    u8 = cv2.morphologyEx(u8, cv2.MORPH_CLOSE, np.ones((int(W), int(W)), np.uint8))
    u8 = cv2.morphologyEx(u8, cv2.MORPH_OPEN, np.ones((max(3, int(W / 2)),) * 2, np.uint8))
    u8 = cv2.erode(u8, cv2.getStructuringElement(cv2.MORPH_ELLIPSE,
                                                 (max(3, int(W / 2)),) * 2))
    n, _, stats, _ = cv2.connectedComponentsWithStats(u8, 8)
    if n < 2:
        return empty
    i = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
    x, y, bw, bh, area = stats[i]
    if area < float(cfg["roi_min_area"]) * w * h or bw < 2 * W or bh < 2 * W:
        return empty
    return int(x), int(y), int(bw), int(bh), True, u8[y:y + bh, x:x + bw].astype(bool)


def measure(rgb: np.ndarray, cfg: dict, roi: tuple[int, int, int, int] | None = None,
            manual: dict | None = None) -> dict:
    """Полный фитт: ориентация, период, начало, вершина корреляции, остаток, дрейф.

    `manual` — разметка человека (ветвь (а) Q-M136): игровая зона, период и ориентация.
    Она не отменяет фитт, а ограничивает его: W ищется в узкой полосе вокруг ручной цифры,
    чужая ориентация не сканируется, зона не ищется вовсе. Так проверка «объясняет ли
    решётка линии» остаётся автоматической, а неопределимость по текстуре уходит.
    """
    resp = line_response(rgb, cfg)
    scale = float(cfg["coarse_scale"])
    manual = manual or {}
    if roi is None and manual.get("roi"):
        roi = tuple(int(v) for v in manual["roi"])
    m_w = manual.get("W")
    m_or = manual.get("orientation")
    lo, hi = float(cfg["width_min"]), float(cfg["width_max"])
    if m_w:
        span = float(cfg["pin_span_px"])
        lo, hi = float(m_w) - span, float(m_w) + span
    fits = {}
    for orientation in ("pointy", "flat"):
        if m_or and orientation != m_or:
            continue
        step = float(cfg["pin_step_px"]) if m_w else float(cfg["coarse_step_px"])
        W, peak = scan_width(resp, orientation, lo, hi, step, scale)
        fits[orientation] = (W, peak)
    orientation = max(fits, key=lambda k: fits[k][1])
    other = "flat" if orientation == "flat" else "pointy"
    ratio = fits[orientation][1] / max(fits.get(other, (0, 1e-6))[1], 1e-6)

    auto = roi is None
    on = density_map(resp, orientation, fits[orientation][0], cfg)
    if auto:
        x0, y0, rw, rh, found, region = region_from_density(on, fits[orientation][0], cfg)
    else:
        x0, y0, rw, rh, found = (*roi, True)   # tuple + флаг: `= roi, True` распадалось бы из 2 в 5
        region = np.ones((rh, rw), bool)
    if not auto:
        roi_source = "manual"
    elif (x0, y0, rw, rh) != (0, 0, resp.shape[1], resp.shape[0]):
        roi_source = "auto" if found else "field"
    else:
        roi_source = "not-found"
    crop = resp[y0:y0 + rh, x0:x0 + rw]
    if crop.size < 4096 or not region.any():
        return {"roi": [x0, y0, rw, rh], "accepted": False, "reason": "игровая зона пуста"}

    W, peak, dy, dx = refine_width(crop, orientation, fits[orientation][0],
                                   float(cfg["fine_span_px"]), float(cfg["fine_step_px"]),
                                   float(cfg["ultra_step_px"]))

    # поле 3×3: в каждом окне — свой широкий скан периода и его вершина. Нужно это
    # не для прикрасы: аффинная решётка живёт по всему кадру одним W, а перспективный
    # рисунок объясняется только набором локальных решёток, и по полю видно, что из
    # них есть (окно с низкой вершиной — окно без решётки, т.е. рамка мира)
    def field_of_W(cut: np.ndarray) -> tuple[list[list[float]], list[list[float]]]:
        wv, pv = [], []
        for i in range(3):
            wr, pr = [], []
            for j in range(3):
                cell = cut[i * cut.shape[0] // 3:(i + 1) * cut.shape[0] // 3,
                           j * cut.shape[1] // 3:(j + 1) * cut.shape[1] // 3]
                w, p = scan_width(cell, orientation, lo, hi,
                                  float(cfg["coarse_step_px"]), scale)
                wr.append(round(float(w), 2))
                pr.append(round(float(p), 3))
            wv.append(wr)
            pv.append(pr)
        return wv, pv

    wfield, pfield = field_of_W(crop)
    if auto and not found:
        # зона по полю: окна, где решётка вообще отозвалась (перспективный рисунок
        # одно-единственной W-картой не покрывается, и корреляционная зона не росла)
        hit = [[p >= float(cfg["local_min_peak"]) for p in row] for row in pfield]
        rows_ = [i for i in range(3) if any(hit[i])]
        cols_ = [j for j in range(3) if any(hit[i][j] for i in rows_)] if rows_ else []
        if rows_ and cols_:
            nx, ny = resp.shape[1] // 3, resp.shape[0] // 3
            x0, y0 = cols_[0] * nx, rows_[0] * ny
            rw, rh = (cols_[-1] + 1) * nx - x0, (rows_[-1] + 1) * ny - y0
            crop = resp[y0:y0 + rh, x0:x0 + rw]
            region = np.ones((rh, rw), bool)
            W, peak, dy, dx = refine_width(crop, orientation, W, float(cfg["fine_span_px"]),
                                           float(cfg["fine_step_px"]),
                                           float(cfg["ultra_step_px"]))
            wfield, pfield = field_of_W(crop)
            roi_source = "field"
    if auto and found:
        # замкнутая морфологией зона шире нарисованных линий на полгекса с каждой
        # стороны, а остаток меряется там, где линии кончаются, — отступ один гекс
        region = cv2.erode(region.astype(np.uint8),
                           cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (int(W), int(W)))).astype(bool)
    pw, ph = period_size(W, orientation)
    x_start, y_start = dx % pw, dy % ph
    _, H, cstep, rstep = hex_size(W, orientation)

    # остаток: расстояние от линий решётки до нарисованных линий + полнота наоборот
    grid = lattice_grid((rh, rw), orientation, W, (x_start, y_start))
    mask = line_mask(resp, cfg)[y0:y0 + rh, x0:x0 + rw]
    dt = cv2.distanceTransform((~mask).astype(np.uint8), cv2.DIST_L2, 3)
    d = dt[grid & region]
    dt_grid = cv2.distanceTransform((~grid).astype(np.uint8), cv2.DIST_L2, 3)
    on_line = mask & region
    coverage = float((dt_grid[on_line] <= 2.0).mean()) if on_line.any() else 0.0
    p50, p95 = (float(np.percentile(d, q)) if d.size else 99.0 for q in (50, 95))
    dmax = float(d.max()) if d.size else 99.0

    # объяснено ли линий в каждой из девяти частей зоны одинаково: «уезжает» ли
    # аффинная решётка к краям (перспектива рисунка) видно по провалу на периферии
    src = np.where(on_line, dt_grid <= 2.0, np.nan)
    field = np.full((3, 3), np.nan)
    for i in range(3):
        for j in range(3):
            block = src[i * rh // 3:(i + 1) * rh // 3, j * rw // 3:(j + 1) * rw // 3]
            if np.isfinite(block).any():
                field[i, j] = float(np.nanmean(block))
    spread = float(np.nanmax(field) - np.nanmin(field)) if np.isfinite(field).any() else 0.0

    # расхождение периода по краям зоны — независимыми тонкими фиттами левой и правой
    # половин: по окнам поля 3×3 период только описывается (шаг coarse-скана грубее
    # самого допуска), а порог должен меряться тонким шагом
    half = rw // 2
    wl = wr = W
    if half >= int(2 * W):
        wl, _ = scan_width(crop[:, :half], orientation, W - 3, W + 3, 0.25)
        wr, _ = scan_width(crop[:, half:], orientation, W - 3, W + 3, 0.25)
    drift = abs(wl - wr)
    vals = [v for r in wfield for v in r if v]
    wspread = (max(vals) - min(vals)) if len(vals) > 1 else 0.0

    # плоскость периода W(x, y) по девяти окнам: объясняется ли поле перспективы
    # линейным масштабом (высокий R²) или рисунок несогласован (низкий R²)
    pts = np.array([[j - 1, i - 1, wfield[i][j]] for i in range(3) for j in range(3)
                    if pfield[i][j] >= float(cfg["local_min_peak"])]).astype(float)
    plane = None
    if pts.shape[0] >= 6:
        coef, *_ = np.linalg.lstsq(np.c_[pts[:, :2], np.ones(len(pts))], pts[:, 2],
                                   rcond=None)
        pred = np.c_[pts[:, :2], np.ones(len(pts))] @ coef
        ss = float(((pts[:, 2] - pts[:, 2].mean()) ** 2).sum())
        plane = {"gx_px": round(float(coef[0]), 3), "gy_px": round(float(coef[1]), 3),
                 "r2": round(1.0 - float(((pts[:, 2] - pred) ** 2).sum() / ss), 3) if ss > 1e-6 else 1.0,
                 "n": int(len(pts))}

    geom = stroke_geometry(resp, cfg)
    reason, reason_note = [], None
    if roi_source == "not-found":
        reason.append("ни корреляционная зона, ни зона по локальным вершинам не найдены "
                      "— нужен --roi=x,y,w,h")
    if roi_source == "field":
        reason_note = ("зона взята окнами, где решётка отозвалась (треть кадра), "
                       "граница крупная")
    if peak < float(cfg["min_peak"]):
        reason.append(f"вершина корреляции {peak:.3f} < {cfg['min_peak']} — "
                      "решётка на рисунок не похожа")
    if spread > float(cfg["max_coverage_spread"]):
        reason.append(f"объяснено линий по частям зоны неравномерно: "
                      f"{np.round(field, 2).tolist()} (разброс {spread:.2f} > "
                      f"{cfg['max_coverage_spread']}) — аффинная решётка к краям уезжает")
    if p95 > float(cfg["max_chamfer_p95_px"]):
        reason.append(f"остаток p95 {p95:.2f} px ({p95 / W:.1%} периода) > "
                      f"{cfg['max_chamfer_p95_px']} px")
    if coverage < float(cfg["min_line_coverage"]):
        reason.append(f"решётка объясняет {coverage:.0%} нарисованных линий < "
                      f"{cfg['min_line_coverage']:.0%}")
    if drift > float(cfg["max_drift_px"]):
        reason.append(f"дрейф периода по краям {drift:.2f} px > {cfg['max_drift_px']} px")
    return {
        "roi": [int(x0), int(y0), int(rw), int(rh)],
        "roi_source": roi_source,
        **geom,
        "orientation": orientation,
        "orientation_ratio": round(float(ratio), 3),
        "fits": {k: {"W": round(v[0], 2), "peak": round(v[1], 3)} for k, v in fits.items()},
        "hex_w_px": round(float(W), 2),
        "hex_h_px": round(float(H), 2),
        "hw_ratio": round(float(H / W), 4),
        "col_step_px": round(float(cstep), 2),
        "row_step_px": round(float(rstep), 2),
        "period_px": [int(pw), int(ph)],
        "origin": [int(x_start), int(y_start)],
        "row_offset": "odd-r" if orientation == "pointy" else "odd-q",
        "peak": round(float(peak), 4),
        "coverage_field": [[None if not np.isfinite(v) else round(float(v), 3)
                           for v in row] for row in field],
        "coverage_spread": round(spread, 4),
        "chamfer_px": {"p50": round(p50, 2), "p95": round(p95, 2), "max": round(dmax, 2)},
        # относительный остаток: доли периода. Абсолютный пиксель ничего не значит —
        # 4 px при W=104 и при W=166 это разная посадка, а резать надо по посадке
        "chamfer_p95_rel": round(p95 / float(W), 4),
        "width_field": wfield,
        "local_peak_field": pfield,
        "local_peak_min": round(min(v for r in pfield for v in r), 3),
        "width_plane": plane,
        "drift_px": round(float(drift), 2),
        "width_spread_px": round(float(wspread), 2),
        "line_coverage": round(coverage, 3),
        "line_density": round(float(mask.mean()), 4),
        "cells": {"cols": int(rw / cstep), "rows": int(rh / rstep)},
        "accepted": not reason,
        "reason": "; ".join(reason) or None,
        "note": reason_note,
    }


# ------------------------------------------------- геометрия без подгонки решётки


def stroke_kernels(length: int) -> list[np.ndarray]:
    """Линейные ядра по шести направлениям рёбер гекса (набор один для обеих
    ориентаций — направление ребра не говорит, какая это решётка)."""
    out = []
    for ang in (0, 30, 60, 90, 120, 150):
        k = np.zeros((length, length), np.uint8)
        c = (length - 1) / 2
        for t in np.linspace(-c, c, length):
            k[int(round(c + t * np.sin(np.radians(ang)))),
              int(round(c + t * np.cos(np.radians(ang))))] = 1
        out.append(cv2.dilate(k, np.ones((2, 2), np.uint8)))
    return out


def strokes(resp: np.ndarray, cfg: dict) -> tuple[np.ndarray, list[int]]:
    """Маска длинных штрихов + число штрихов по направлениям."""
    base = (resp > np.percentile(resp, float(cfg["stroke_quantile"]))).astype(np.uint8)
    acc = np.zeros_like(base)
    counts = []
    for se in stroke_kernels(int(cfg["stroke_len_px"])):
        one = cv2.morphologyEx(base, cv2.MORPH_OPEN, se)
        counts.append(int(one.sum()))
        acc = cv2.bitwise_or(acc, one)
    return acc.astype(bool), counts


def stroke_geometry(resp: np.ndarray, cfg: dict) -> dict:
    """Период и ориентация по штрихам, без подгонки решётки.

    Период — длина волны профиля штрихов по горизонтали (столбцы решётки), ориентация
    — по тому, какие рёбра короче/длиннее: у pointy вертикальные рёбра длиннее
    наклонных, у flat наоборот. Способ независимый от корреляционной подгонки, и он
    обязан сойтись с ней там, где подгонка вообще что-то нашла.
    """
    h, w = resp.shape
    mask, counts = strokes(resp, cfg)
    band = mask[h // 4:3 * h // 4, w // 8:7 * w // 8]
    prof = band.sum(axis=0).astype(float)
    prof -= prof.mean()
    if prof.sum() <= 0:
        return {"stroke_period_px": None, "stroke_orientation": None,
                "stroke_counts": counts, "stroke_density": 0.0}
    f = np.abs(np.fft.rfft(prof * np.hanning(len(prof))))
    lam = [len(prof) / i for i in np.argsort(f)[::-1][:12] if i > 3]
    lam = [x for x in lam if float(cfg["width_min"]) < x < float(cfg["width_max"])]
    lo = counts[0] + counts[3]            # направления 0° и 90°: вертикаль и горизонталь
    return {
        "stroke_period_px": round(float(np.median(lam)), 2) if lam else None,
        "stroke_orientation": ("pointy" if counts[3] > counts[0] else "flat") if lo else None,
        "stroke_counts": counts,
        "stroke_density": round(float(mask.mean()), 4),
    }


# ------------------------------------------------------------------ реестр


def load_registry() -> dict:
    if REGISTRY.is_file():
        return json.loads(REGISTRY.read_text())
    return {"thresholds": dict(DEFAULTS)}


def update_registry(measured: dict[str, dict]) -> None:
    reg = load_registry()
    scenes = reg.setdefault("scenes", {})
    for name, rec in measured.items():
        # запись сцены дополняется, а не заменяется: решётка и кластеры — разные
        # прогоны одного кадра, и последний не имеет права стирать первый
        scenes.setdefault(name, {}).update(rec)
    reg["thresholds"] = {k: v for k, v in reg.get("thresholds", {}).items()
                         if k in DEFAULTS}
    REGISTRY.write_text(json.dumps(reg, ensure_ascii=False, indent=1) + "\n")


# ------------------------------------------------------------------ self-test


def synthetic(W: float, x0: int, y0: int, warp: float = 0.0,
              size: tuple[int, int] = (900, 620)) -> np.ndarray:
    """Кадр с заведомо известной решёткой — как настоящая сцена комплекта.

    Устроен так, как замерено на реальном комплекте: игровое поле затемнено и почти
    однородно, а вся пестрота (рамка мира) — вне полосы сетки. Иначе тест ловил бы
    не то: шум по всему кадру даёт решётке одинаковый «мусорный» отклик и внутри,
    и снаружи зоны, и отделить зону по нему нельзя в принципе.

    Истина рисуется draw_full_lattice — кодом, отличным от шаблона фиттера, иначе
    тест проверял бы сам себя. `warp` — растяжение по x от центра кадра: им задаётся
    «рисунок не аффинный» (перспектива кадра).
    """
    h, w = size
    rng = np.random.default_rng(7)
    rgb = np.full((h, w, 3), (44, 52, 46), np.uint8)
    # шум поля по пикселю — как в реальном AI-арте: гладком на масштабе пикселя
    # (замер: на шуме σ=6 крыша ловила 8% пикселов поля против 2% самих линий)
    rgb[:, :, 0] = np.clip(rgb[:, :, 0].astype(np.int16)
                           + rng.normal(0, 3, (h, w)), 0, 255).astype(np.uint8)
    top, bot = int(h * 0.18), int(h * 0.88)
    # «рамка мира»: пёстрая текстура без решётки — ровно то, что должно отсекаться
    # низкочастотная, как настоящая рамка мира: в ней есть пятна и перепады, но нет
    # тонких линий — на шуме «по пикселю» решётка откликалась бы и в рамке
    frame = np.repeat(np.clip(150 + 40 * np.sin(np.linspace(0, 9, w))[None, :, None]
                              + rng.normal(0, 40, (h, w, 1)), 0, 255).astype(np.uint8), 3, axis=2)
    frame = cv2.GaussianBlur(frame, (0, 0), 7.0)
    frame[:, :, 1] = np.clip(frame[:, :, 1].astype(np.int16) + 30, 0, 255).astype(np.uint8)
    rgb[:top] = frame[:top]
    rgb[bot:] = frame[bot:]
    hit = draw_full_lattice((h, w), "pointy", W, (x0, y0), thickness=2)
    if warp:
        m = cv2.getRotationMatrix2D((w / 2, h / 2), 0, 1.0)
        m[0, 0] = 1.0 + warp
        m[0, 1] = warp * 0.3                     # чуть сдвига, чтобы не чистое масштаб
        hit = cv2.warpAffine(hit.astype(np.uint8), m, (w, h)).astype(bool)
    band = np.zeros((h, w), bool)
    band[top:bot, :] = True
    rgb[hit & band] = (206, 212, 210)            # светлые линии на тёмном поле
    return cv2.GaussianBlur(rgb, (0, 0), 1.0)


def self_test() -> int:
    cfg = dict(DEFAULTS)
    bad = 0

    def check(name: bool, note: str) -> None:
        nonlocal bad
        print(("  ok   " if name else "  FAIL ") + note)
        bad += 0 if name else 1

    for W, x0, y0 in ((92.0, 13, 7), (78.0, 0, 0), (104.0, 41, 23)):
        m = measure(synthetic(W, x0, y0), cfg)
        check(m["orientation"] == "pointy",
              f"ориентация pointy при W={W}: {m['orientation']} "
              f"(отношение {m['orientation_ratio']})")
        check(abs(m["hex_w_px"] - W) <= 1.0, f"период восстановлен: {m['hex_w_px']} vs {W}")
        check(abs(m["hw_ratio"] - 1.1547) < 0.02, f"H/W = {m['hw_ratio']}")
        check(m["chamfer_px"]["p95"] <= 3.0, f"остаток p95 {m['chamfer_px']['p95']} px")
        check(m["line_coverage"] > 0.6, f"объяснено линий {m['line_coverage']:.0%}")
        check(m["accepted"], f"голая решётка принята ({m['reason']})")
        rx, ry, rw, rh = m["roi"]
        fit_grid = lattice_grid((rh, rw), m["orientation"], m["hex_w_px"], tuple(m["origin"]))
        truth = draw_full_lattice((rh, rw), "pointy", W, (x0 - rx, y0 - ry), thickness=2)
        dt = cv2.distanceTransform((~truth).astype(np.uint8), cv2.DIST_L2, 3)
        check(float(np.percentile(dt[fit_grid], 95)) <= 2.0,
              f"фаза против независимого рендера: p95 "
              f"{np.percentile(dt[fit_grid], 95):.2f} px (зона {m['roi']})")

    # плоский рисунок с перспективой: аффинная решётка обязана не сойтись числом
    warped = measure(synthetic(92.0, 5, 5, warp=0.06), cfg)
    check(not warped["accepted"], f"неаффинный рисунок отвергнут: {warped['reason']}")
    check(warped["coverage_spread"] > DEFAULTS["max_coverage_spread"],
          f"неравномерность объяснения померена: {warped['coverage_spread']} "
          f"({warped['coverage_field']})")

    blank = np.full((600, 800, 3), 120, np.uint8)
    check(not measure(blank, cfg)["accepted"], "пустой кадр не годится")
    print("SELF-TEST:", "FAIL" if bad else "OK")
    return 1 if bad else 0


# ------------------------------------------------------------------ CLI


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--kit", default="", help="каталог сцен (по умолчанию MAP_SCENE_KIT)")
    ap.add_argument("--scene", default="", help="один файл (имя в комплекте или путь)")
    ap.add_argument("--all", action="store_true", help="все сцены комплекта")
    ap.add_argument("--list", action="store_true", help="список файлов комплекта")
    ap.add_argument("--roi", default="", help="x,y,w,h — вручную, если автомат не справился")
    ap.add_argument("--update", action="store_true",
                    help="дописать замеры в game/data/config/scene_slices.json")
    ap.add_argument("--debug", default="", help="префикс куда положить кадр-доказательства")
    ap.add_argument("--self-test", action="store_true")
    ap.add_argument("--manual", action="store_true",
                    help="взять зону/период/ориентацию из `manual` записи реестра")
    ap.add_argument("--geometry", action="store_true",
                    help="только независимая геометрия по штрихам (быстро, без подгонки)")
    a = ap.parse_args()
    if a.self_test:
        return self_test()

    reg = load_registry()
    cfg = cfg_for(reg)
    kit = kit_dir(a.kit)
    if a.list:
        for name in kit_files(kit):
            print(name)
        return 0
    if a.scene:
        names = [a.scene]
    elif a.all:
        names = kit_files(kit)
    else:
        sys.exit("--scene=<файл> или --all (см. --list)")
    roi = tuple(int(v) for v in a.roi.split(",")) if a.roi else None
    out: dict[str, dict] = {}
    for name in names:
        path = Path(name) if Path(name).is_absolute() else kit / name
        bgr = cv2.imread(str(path), cv2.IMREAD_COLOR)
        if bgr is None:
            sys.exit(f"не читается как изображение: {path}")
        rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
        if a.geometry:
            rec = stroke_geometry(line_response(rgb, cfg), cfg)
            rec["sha256"] = sha256(path)
            rec["size"] = list(rgb.shape[1::-1])
            out[name] = rec
            print(json.dumps({name: rec}, ensure_ascii=False))
            continue
        manual = reg.get("scenes", {}).get(name, {}).get("manual", {}) if a.manual else None
        if a.manual and not manual:
            sys.exit(f"в реестре нет manual-разметки сцены {name} — "
                     f"нанеси её: scripts/annotate_scenes.py --mark=x,y,w,h --scene=...")
        rec = measure(rgb, cfg, roi, manual=manual)
        rec["sha256"] = sha256(path)[:16]
        rec["size"] = [rgb.shape[1], rgb.shape[0]]
        out[path.name] = rec
        print(json.dumps({path.name: rec}, ensure_ascii=False), flush=True)
        if a.debug:
            resp = line_response(rgb, cfg)
            u8 = (np.clip(resp, 0, 1) * 255).astype(np.uint8)
            sm, _ = corr_map(resp, rec.get("orientation", "pointy"),
                             rec.get("hex_w_px", 90.0))
            cv2.imwrite(f"{a.debug}-lines.png", u8)
            cv2.imwrite(f"{a.debug}-corr.png",
                        (np.clip(sm, 0, None) / max(sm.max(), 1e-6) * 255).astype(np.uint8))
            canvas = cv2.cvtColor(rgb, cv2.COLOR_RGB2BGR)
            x, y, w, h = rec["roi"]
            cv2.rectangle(canvas, (x, y), (x + w, y + h), (0, 255, 0), 3)
            cv2.imwrite(f"{a.debug}-roi.png", canvas)
    if a.update:
        update_registry(out)
        print(f"РЕЕСТР: {REGISTRY} — записей сцен: {len(load_registry()['scenes'])}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

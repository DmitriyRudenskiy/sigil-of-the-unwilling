#!/usr/bin/env python3
"""Шаг 0 измерения (2): сколько оттенков на кадр просит палитра, и где в кадре
игровая зона. D-309 требует k-средних по k=2..8 на все 63 кадра, D-310 требует
реестра с коэффициентом даунскейла; оба числа здесь и никуда не деваются.

Игровая зона ищется по энергии отклика «тёмкая тонкая линия»: декоративная оправа
рисуется мягче и без сетки, поэтому полоса с сеткой отделяется порогом по сглаженной
плотности отклика — без подгонки решётки, то есть независимо от того, каким способом
потом будут резать (вопрос о способе — Q-M136, он не блокирует это измерение).

    python3 scripts/measure_scene_clusters.py                 # все кадры, отчёт + реестр
    python3 scripts/measure_scene_clusters.py --scene=<файл>  # один кадр
    python3 scripts/measure_scene_clusters.py --self-test     # проверка на синтетике

Выход — JSON-строка на кадр; `--update` пишет поле `clusters` в
game/data/config/scene_slices.json.
"""
from __future__ import annotations

import argparse
import json
import statistics
import sys
from pathlib import Path

import cv2
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import measure_scene_lattice as L

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
    img = synthetic(cfg)
    m = measure(img, cfg)
    checks = [
        (m["play_area"][1] >= 100, f"игровая зона ниже оправы: {m['play_area']}"),
        (0.3 <= m["play_area_share"] <= 0.95, f"доля зоны {m['play_area_share']} вне здравого смысла"),
        (m["elbow_k"] in (3, 4, 5, 6), f"локоть {m['elbow_k']} для кадра с 6 оттенками"),
        (m["k_at_85pct"] is not None and m["k_at_85pct"] <= 7,
         f"k для 85% дисперсии {m['k_at_85pct']}"),
        (m["inertia"]["3"] < m["inertia"]["2"], "inertia не убывает с k"),
        (m["palette"]["spread_px"] > 50, f"разъезд палитры должен быть виден: {m['palette']['spread_px']}"),
    ]
    flat = np.full((600, 900, 3), 128, np.uint8)
    mf = measure(flat, cfg)
    checks.append((mf["palette"]["spread_px"] < 5,
                   f"однотонный кадр не должен иметь разъезда: {mf['palette']['spread_px']}"))
    bad = 0
    for ok, msg in checks:
        bad += 0 if ok else 1
        print(f"  {'ok  ' if ok else 'FAIL'} {msg}")
    print("SELF-TEST:", "OK" if bad == 0 else f"FAIL ({bad})")
    return 0 if bad == 0 else 1


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--scene", default="")
    ap.add_argument("--kit", default="")
    ap.add_argument("--update", action="store_true")
    ap.add_argument("--self-test", action="store_true")
    a = ap.parse_args()
    if a.self_test:
        return self_test()

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

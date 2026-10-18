#!/usr/bin/env python3
"""Замер тонального шага «декаль перехода vs база соседней клетки» (T-136).

Две меры, обе — ΔE76 до среднего Lab по альфе:

1. **Рампа вариантов базы** — шаг между четырьмя вариантами одного биома. Это тот
   член, на который указывал тикет: декаль печатается материалом `mat_<biome>_0`,
   а сосед стоит любым из четырёх.
2. **Линия стыка** — декаль стороны `e` (полоса у правого края клетки) против левого
   края базы соседа: те два ряда пикселей, которые в кадре стоят вплотную. Плюс L*
   обоих, чтобы видеть направление шага (декаль темнее базы или светлее).

Порог «не читается как граница биома» — `frame.min_biome_contrast_de`. Мера покадровая
по атласу, геометрию сторон гекса (кроме восток/запад) не учитывает.

    python3 scripts/measure_decal_seam.py
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from measure_palette_band import de76, tone_lab  # noqa: E402  (общая метрика палитры §4.6)
from check_map_art import NEIGH_EVEN, NEIGH_ODD  # noqa: E402  (соседи offset-рядов)

# Порядок биомов = TileAtlas.BIOME_NAMES: по нему paint_transitions решает, кто
# из пары красит переход (младший красит в свою клетку материал старшего).
BIOME_ORDER = ["grass", "sand", "snow", "swamp", "water", "rock", "mud", "road"]

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ATLAS = os.path.join(ROOT, "game/assets/tiles")
GATES = os.path.join(ROOT, "game/data/config/map_art_gates.json")
INSET = 0.30     # у базы отбрасываем край клетки: на границе уже чужой тайл
BAND = 0.12      # доля ширины полосы у линии стыка


def _mean_lab(px: np.ndarray):
    """Среднее Lab по альфе: полупрозрачный край декаля — как раз то, что на стыке."""
    a = px[..., 3].astype(np.float64) / 255.0
    if a.sum() <= 0:
        return None
    rgb = (px[..., :3].astype(np.float64) * a[..., None]).sum((0, 1)) / a.sum()
    return tone_lab(tuple(rgb))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--atlas", default=ATLAS)
    ap.add_argument("--shot", default="", help="снимок карты (рядом лежит .cells.json)")
    ap.add_argument("--t", type=float, default=0.50,
                    help="доля пути к центру соседней клетки, где брать полосу")
    a = ap.parse_args()
    with open(GATES, encoding="utf-8") as f:
        threshold = float(json.load(f)["frame"]["min_biome_contrast_de"])
    if a.shot:
        return shot_seam(a.shot, threshold, a.t)
    with open(os.path.join(a.atlas, "world_map_atlas.json"), encoding="utf-8") as f:
        man = json.load(f)
    img = np.asarray(Image.open(os.path.join(a.atlas, man["image"])).convert("RGBA"),
                     dtype=np.uint8)
    cells, t = man["cells"], int(man["tile"])

    def crop(cell, x0, y0, x1, y1) -> np.ndarray:
        x, y = cell["atlas"][0] * t, cell["atlas"][1] * t
        return img[y + int(y0 * t):y + int(y1 * t), x + int(x0 * t):x + int(x1 * t)]

    def pick(kind, biome, **want):
        out = [c for c in cells if c["kind"] == kind and c["biome"] == biome
               and all(c.get(k) == v for k, v in want.items())]
        return out[0] if out else None

    print(f"порог «не читается как граница биома»: ΔE ≥ {threshold:.1f}\n")
    print(f"{'биом':7} {'рампа базы':>10} {'стык v0':>8} {'стык v3':>8} "
          f"{'L* базы':>8} {'L* декаля':>10}")
    for biome in sorted({c["biome"] for c in cells}):
        bases = [pick("base", biome, variant=v) for v in range(4)]
        lb = [_mean_lab(crop(b, INSET / 2, INSET / 2, 1 - INSET / 2, 1 - INSET / 2))
              for b in bases]
        ramp = max(de76(a, b) for a in lb for b in lb)
        edge = pick("edge", biome, side="e")
        le = _mean_lab(crop(edge, 1 - BAND, 0, 1, 1))
        left = [_mean_lab(crop(b, 0, 0, BAND, 1)) for b in bases]
        l_base = _mean_lab(crop(bases[0], 0.4, 0.4, 0.6, 0.6))[0]
        l_edge = le[0]
        print(f"{biome:7} {ramp:10.1f} {de76(le, left[0]):8.1f} {de76(le, left[3]):8.1f} "
              f"{l_base:8.1f} {l_edge:10.1f}")
    print("\nрампа базы = шаг между самыми разными вариантами одного биома (член, который "
          "тикет считал главным);\nстык v0/v3 = шаг декаля к левому краю базы 0-го/3-го "
          "варианта — если оба большие и близкие, виноват не вариант.")
    return 0


def _hf(x: np.ndarray) -> float:
    """Высокочастотная дисперсия участка: σ(p − среднее 3×3). Мера «зерна» материала."""
    s = np.zeros_like(x)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            s += np.roll(np.roll(x, dy, 0), dx, 1)
    return float(np.std(x - s / 9.0))


def _patch(img: np.ndarray, x: int, y: int, r: int = 4) -> np.ndarray:
    return img[max(0, y - r):y + r, max(0, x - r):x + r]


def _profile(img: np.ndarray, own: list, nb: list, means: dict, contrast: float):
    """Профиль тона поперёк общего ребра: где переход и насколько он размыт.

    Возвращает (t*, ширина, grain) либо None, если профиль нечитаемая (мелкий контраст).
    t=0 — центр своей клетки, t=0.5 — общее ребро (там перо непрозрачно).
    t* — где тон становится ближе к чужому биому; ширина — полоса между «ещё свой»
    (ΔE до своего ≤ 0.25 межбиомного контраста) и «уже чужой»; grain — ВЧ-дисперсия
    пера у ребра против ВЧ-дисперсии своей базы в глубине клетки.
    """
    if contrast < 8.0:
        return None
    ts = [i / 40.0 for i in range(2, 21)]
    da, db = [], []
    for t in ts:
        x, y = int(own[0] + t * (nb[0] - own[0])), int(own[1] + t * (nb[1] - own[1]))
        lab = tone_lab(tuple(_patch(img, x, y).reshape(-1, 3).mean(0)))
        da.append(de76(lab, tone_lab(tuple(means[own[2]]))))
        db.append(de76(lab, tone_lab(tuple(means[nb[2]]))))
    cross = next((t for t, u, v in zip(ts, da, db) if v < u), None)
    own_side = [t for t, u in zip(ts, da) if u <= 0.25 * contrast]
    nb_side = [t for t, v in zip(ts, db) if v <= 0.25 * contrast]
    if cross is None or not own_side or not nb_side:
        return None
    width = min(nb_side) - max(own_side)
    x0, y0 = int(own[0] + 0.10 * (nb[0] - own[0])), int(own[1] + 0.10 * (nb[1] - own[1]))
    x1, y1 = int(own[0] + 0.46 * (nb[0] - own[0])), int(own[1] + 0.46 * (nb[1] - own[1]))
    base, feather = _hf(_patch(img, x0, y0)), _hf(_patch(img, x1, y1))
    return cross, width, (feather / base if base > 1e-6 else 0.0)


def shot_seam(shot: str, threshold: float, t: float = 0.50) -> int:
    """То же — по снимку карты, плюс геометрия и фактура самого пера.

    Декаль биома B лежит внутри клетки биома A (map_renderer.paint_transitions), то есть
    у общего ребра со стороны A тон = материал B. Отсюда два разных числа, которые до
    T-138 печатались под одной подписью (урок: «ΔE(перо ↔ тон своей клетки) = 32» — это
    НЕ дефект перехода, а межбиомный контраст, который frame/contrast требует держать
    БОЛЬШЕ 12; сравнивать его с нулём — значит требовать слить биомы):

      · ΔE(перо ↔ носимый материал) — мера T-136: кромки нет, если мало;
      · ΔE(перо ↔ тон своей клетки) — межбиомный контраст на ребре, норма.

    Геометрия перехода — профилем поперёк ребра (_profile): t* и ширина полосы смешения.
    Фактура — grain: ВЧ-дисперсия пера против ВЧ-дисперсии базы того же биома."""
    geo = json.load(open(f"{shot}.cells.json", encoding="utf-8"))
    tile = int(geo["tile"][0])
    cells = geo["cells"]
    img = np.asarray(Image.open(shot).convert("RGB"), dtype=np.float64)
    means, strips, geom = {}, [], []
    for biome in sorted({v[2] for v in cells.values()}):
        px = [img[max(0, v[1] - 12):v[1] + 12, max(0, v[0] - 12):v[0] + 12].reshape(-1, 3)
              for v in cells.values() if v[2] == biome]
        means[biome] = np.concatenate(px).mean(0)
    for key, val in cells.items():
        cx, cy = map(int, key.split(","))
        for d in (NEIGH_ODD if cy % 2 else NEIGH_EVEN):
            nb = cells.get(f"{cx + d[0]},{cy + d[1]}")
            if not nb or val[2] == nb[2]:
                continue
            a, b = val[2], nb[2]                       # декаль b лежит внутри клетки a
            if BIOME_ORDER.index(b) <= BIOME_ORDER.index(a):
                continue                    # красит сосед, не эта клетка
            mx, my = int(val[0] + t * (nb[0] - val[0])), int(val[1] + t * (nb[1] - val[1]))
            patch = img[max(0, my - 4):my + 4, max(0, mx - 4):mx + 4].reshape(-1, 3).mean(0)
            strips.append((de76(tone_lab(tuple(patch)), tone_lab(tuple(means[b]))),
                           de76(tone_lab(tuple(patch)), tone_lab(tuple(means[a]))), a, b))
            g = _profile(img, val, nb, means,
                         de76(tone_lab(tuple(means[a])), tone_lab(tuple(means[b]))))
            if g:
                geom.append(g)
    if not strips:
        print("в кадре нет пар биомов, где декаль вообще рисуется")
        return 0
    worst = max(strips, key=lambda s: s[0])
    med = lambda xs: sorted(xs)[len(xs) // 2]
    print(f"пар перехода: {len(strips)}; медиана ΔE(перо ↔ носимый материал) = "
          f"{med([s[0] for s in strips]):.1f} (мера T-136, чем меньше, тем лучше), "
          f"медиана ΔE(перо ↔ тон своей клетки) = {med([s[1] for s in strips]):.1f} "
          f"(это межбиомный контраст, норма frame/contrast ≥ 12, не дефект)")
    print(f"худший ΔE(перо ↔ носимый материал) = {worst[0]:.1f} ({worst[2]}→{worst[3]}), "
          f"порог {threshold:.1f} → {'FAIL' if worst[0] > threshold else 'PASS'}")
    if geom:
        print(f"профиль поперёк ребра (медиана по {len(geom)} парам): переход на "
              f"t* = {med([g[0] for g in geom]):.2f}, полоса смешения "
              f"{med([g[1] for g in geom]):.2f} клетки, grain пера/базы = "
              f"{med([g[2] for g in geom]):.2f} (1.0 = фактура та же, гладкое перо < 0.7)")
    return 0


if __name__ == "__main__":
    sys.exit(main())

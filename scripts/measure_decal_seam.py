#!/usr/bin/env python3
"""Замер перехода между биомами: кромка, геометрия и фактура (T-136, T-138).

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
import math
import os
import re
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


def _patch(img: np.ndarray, x: int, y: int, r: int = 6) -> np.ndarray:
    return img[max(0, int(y) - r):int(y) + r, max(0, int(x) - r):int(x) + r]


def _at(own: list, nb: list, t: float, off: float = 0.0) -> tuple:
    """Точка на оси «центр своей клетки → центр соседней», боковой сдвиг off — в долях
    межцентрового расстояния. Ось нормирована по паре, поэтому направление гекса
    (у которого сосед по E/W ближе, чем по диагонали) в единицы не лезет."""
    ux, uy = nb[0] - own[0], nb[1] - own[1]
    d = math.hypot(ux, uy)
    ux, uy, ox, oy = ux / d, uy / d, -uy / d, ux / d
    return own[0] + t * ux * d + off * ox * d, own[1] + t * uy * d + off * oy * d


def _tone(img: np.ndarray, own: list, nb: list, means: dict, t: float, off: float = 0.0):
    """(ΔE до тона своей клетки, ΔE до тона соседней) в точке оси."""
    x, y = _at(own, nb, t, off)
    lab = tone_lab(tuple(_patch(img, x, y).reshape(-1, 3).mean(0)))
    return (de76(lab, tone_lab(tuple(means[own[2]]))),
            de76(lab, tone_lab(tuple(means[nb[2]]))))


def _grain(img: np.ndarray, own: list, nb: list, t: float, off: float = 0.0) -> float:
    """Зерно материала в точке оси: медиана ВЧ-дисперсии по трём боковым сдвигам."""
    return float(np.median([_hf(_patch(img, *_at(own, nb, t, o)))
                            for o in (off - 0.15, off, off + 0.15)]))


def _feather() -> float:
    """FEATHER из gen_map_art.py. Читается из исходника, а не импортируется: gen_map_art
    тянет image-clone-раннер, а молча продублировать константу — значит через месяц
    померить не ту глубину пера, что рисует атлас."""
    src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                            "gen_map_art.py"), encoding="utf-8").read()
    return float(re.search(r"^FEATHER = ([\d.]+)", src, re.M).group(1))


def _profile(img: np.ndarray, own: list, nb: list, means: dict, contrast: float):
    """Геометрия перехода поперёк ребра: (t*, ширина полосы, std t* вдоль ребра).

    t* — где тон становится ближе к чужому биому; ширина — полоса между «ещё свой»
    (ΔE до своего ≤ 0.25 межбиомного контраста) и «уже чужой»; std t* по пяти боковым
    сдвигам — насколько граница блуждает: у отпечатка прямоугольной кисти она была бы
    ~0, у материала — дрожит на суб-тайловом масштабе. None, если контраст мелок и
    профиль не читается.
    """
    if contrast < 8.0:
        return None
    ts = [i / 40.0 for i in range(2, 21)]
    da, db = [], []
    for t in ts:
        u, v = _tone(img, own, nb, means, t)
        da.append(u)
        db.append(v)
    cross = next((t for t, u, v in zip(ts, da, db) if v < u), None)
    own_side = [t for t, u in zip(ts, da) if u <= 0.25 * contrast]
    nb_side = [t for t, v in zip(ts, db) if v <= 0.25 * contrast]
    if cross is None or not own_side or not nb_side:
        return None
    spread = []
    for off in (-0.3, -0.15, 0.0, 0.15, 0.3):
        for t in ts:
            u, v = _tone(img, own, nb, means, t, off)
            if v < u:
                spread.append(t)
                break
    std = float(np.std(spread)) if len(spread) >= 3 else 0.0
    return cross, min(nb_side) - max(own_side), std


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
    Фактура — профиль ВЧ-дисперсии по той же оси t: перо (t≈0.45) против **того же
    материала в его собственной клетке** (t≈0.95). Прежнее сравнение пера с базой
    соседнего биома меряло разницу двух материалов, а не сглаживание декалем.

    Единицы печатаются отдельной строкой и все размеры профиля — в долях межцентрового
    расстояния данной пары: у гекса сосед по E/W ближе, чем по диагонали, поэтому
    «тайл» и «клетка» — непереводимые без коэффициента оси, а смешение осей и породило
    исходную ошибку T-138."""
    geo = json.load(open(f"{shot}.cells.json", encoding="utf-8"))
    tile = int(geo["tile"][0])
    cells = geo["cells"]
    img = np.asarray(Image.open(shot).convert("RGB"), dtype=np.float64)
    means, strips, geom, strong, same = {}, [], [], [], []
    dist = []          # межцентровые расстояния по всем рёбрам: у гекса они разные
    for biome in sorted({v[2] for v in cells.values()}):
        px = [img[max(0, v[1] - 12):v[1] + 12, max(0, v[0] - 12):v[0] + 12].reshape(-1, 3)
              for v in cells.values() if v[2] == biome]
        means[biome] = np.concatenate(px).mean(0)
    for key, val in cells.items():
        cx, cy = map(int, key.split(","))
        for d in (NEIGH_ODD if cy % 2 else NEIGH_EVEN):
            nb = cells.get(f"{cx + d[0]},{cy + d[1]}")
            if nb:
                dist.append(math.hypot(nb[0] - val[0], nb[1] - val[1]))
    for key, val in cells.items():
        cx, cy = map(int, key.split(","))
        for d in (NEIGH_ODD if cy % 2 else NEIGH_EVEN):
            nb = cells.get(f"{cx + d[0]},{cy + d[1]}")
            if not nb:
                continue
            if val[2] == nb[2]:
                # Контроль: у одноимённых соседей перехода нет, и профиль зерна по такой
                # оси обязан быть плоским. Без этой точки 0.80× у декаля не с чем
                # сравнить: неясно, где шумовой пол самой меры.
                same.append((val, nb))
                continue
            a, b = val[2], nb[2]                       # декаль b лежит внутри клетки a
            if BIOME_ORDER.index(b) <= BIOME_ORDER.index(a):
                continue                    # красит сосед, не эта клетка
            mx, my = int(val[0] + t * (nb[0] - val[0])), int(val[1] + t * (nb[1] - val[1]))
            patch = img[max(0, my - 4):my + 4, max(0, mx - 4):mx + 4].reshape(-1, 3).mean(0)
            contrast = de76(tone_lab(tuple(means[a])), tone_lab(tuple(means[b])))
            strips.append((de76(tone_lab(tuple(patch)), tone_lab(tuple(means[b]))),
                           de76(tone_lab(tuple(patch)), tone_lab(tuple(means[a]))), a, b))
            g = _profile(img, val, nb, means, contrast)
            if g:
                geom.append(g)
            if contrast >= threshold:
                strong.append((val, nb))
    if not strips:
        print("в кадре нет пар биомов, где декаль вообще рисуется")
        return 0
    worst = max(strips, key=lambda s: s[0])
    med = lambda xs: sorted(xs)[len(xs) // 2]
    feather = _feather()
    f_px = feather * tile
    print(f"единицы: тайл {tile} px; клетка = межцентровое расстояние, у гекса оно "
          f"разное по направлениям ({min(dist):.0f}–{max(dist):.0f} px, 1 тайл = "
          f"{tile / max(dist):.2f}–{tile / min(dist):.2f} клетки); FEATHER {feather:.2f} "
          f"тайла = {f_px:.0f} px = {f_px / max(dist):.2f}–{f_px / min(dist):.2f} клетки. "
          f"Ось t ниже — доля межцентрового расстояния своей пары: 0 центр своей клетки, "
          f"0.5 общее ребро, 1.0 центр соседней.")
    print(f"пар перехода: {len(strips)}; медиана ΔE(перо ↔ носимый материал) = "
          f"{med([s[0] for s in strips]):.1f} (мера T-136, чем меньше, тем лучше), "
          f"медиана ΔE(перо ↔ тон своей клетки) = {med([s[1] for s in strips]):.1f} "
          f"(это межбиомный контраст, норма frame/contrast ≥ 12, не дефект)")
    print(f"худший ΔE(перо ↔ носимый материал) = {worst[0]:.1f} ({worst[2]}→{worst[3]}), "
          f"порог {threshold:.1f} → {'FAIL' if worst[0] > threshold else 'PASS'}")
    if geom:
        print(f"геометрия перехода (медиана по {len(geom)} парам): t* = "
              f"{med([g[0] for g in geom]):.2f}, полоса смешения "
              f"{med([g[1] for g in geom]):.2f} клетки, std(t*) вдоль ребра = "
              f"{med([g[2] for g in geom]):.3f} — насколько граница блуждает; у отпечатка "
              f"прямоугольной кисти была бы ~0")
    if strong:
        grid = [i / 10.0 + 0.05 for i in range(10)]
        rows = {"↔A": [], "↔B": [], "зерно": []}
        for t in grid:
            a, b, g = [], [], []
            for own, nb in strong:
                u, v = _tone(img, own, nb, means, t)
                a.append(u)
                b.append(v)
                g.append(_grain(img, own, nb, t))
            for name, vals in (("↔A", a), ("↔B", b), ("зерно", g)):
                rows[name].append(float(np.median(vals)))
        print(f"профиль поперёк ребра (медиана по {len(strong)} парам с контрастом ≥ "
              f"{threshold:.0f}; A — своя клетка, B — соседняя, чей материал несёт перо):")
        print("  t     " + " ".join(f"{t:5.2f}" for t in grid))
        for name, vals in rows.items():
            print(f"  {name:6}" + " ".join(f"{x:5.1f}" for x in vals))
        if same:
            edge = float(np.median([_grain(img, own, nb, 0.45) for own, nb in same]))
            base = float(np.median([_grain(img, own, nb, 0.95) for own, nb in same]))
            print(f"контроль ({len(same)} пар одноимённых соседей, декаль на этой оси не "
                  f"рисуется нигде): зерно у ребра {edge:.1f} против {base:.1f} в базе → "
                  f"{edge / base:.2f}× = шумовой пол меры; всё, что ниже него, — "
                  f"сглаживание декалем, а не край тайла и не фильтр")
        gf, gb = rows["зерно"][4], rows["зерно"][9]
        print(f"Δgrain пера = {gf:.1f} (t=0.45) против {gb:.1f} у того же материала в его "
              f"собственной клетке (t=0.95) → {gf / gb:.2f}×, Δ = {gf - gb:+.1f}")
        print(f"  в строку взята t=0.45 — последняя точка, чьё окно 12×12 px целиком "
              f"лежит в полосе пера; t=0.55 = {rows['зерно'][5]:.1f} в вывод не входит: "
              f"её центр уже за ребром и окно захватывает хвост blend-полосы со стороны B, "
              f"то есть мерит смесь двух сторон оси, а не перо. Дно ямы — между 0.45 и 0.55.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

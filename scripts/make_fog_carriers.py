#!/usr/bin/env python3
"""Коммит-носитель четырёх кадров 11.3: один рецепт, а не ad-hoc пиксели прошлого круга.

Повод (круг 12). Три из четырёх носителей 11.3 были сделаны в сессии и **не имеют
генератора в репо**: md5 доказывает байты, но не рецепт. Плюс пара `frame-z10-fog.png` /
`frame-z05-fog.png` оказалась **перепутана именами** (проверено рендером с carrier-коммита
`90343162`: `--zoom=1` даёт байты, лежавшие под именем z05, и наоборот). Этот скрипт —
рецепт; имена в нём выводятся из фактического `--zoom`, а не из памяти о том, что рендерилось.

Вход — три кадра `tools/map_shot.gd` (один seed, 1:1, туман вкл/выкл):

    godot --path game -s tools/map_shot.gd -- --seed=4242 --size=40 --zoom=1   --fog=1 --out=/tmp/z1_on.png
    godot --path game -s tools/map_shot.gd -- --seed=4242 --size=40 --zoom=1   --fog=0 --out=/tmp/z1_off.png
    godot --path game -s tools/map_shot.gd -- --seed=4242 --size=40 --zoom=0.5 --fog=1 --out=/tmp/z05_on.png

Выход — в каталог носителей: `frame-z10-fog.png`, `frame-z05-fog.png`,
`fog-footprint-1x.png` (|fog=1 − fog=0|, автоконтраст, 1:1), `crop-transitions-2x.png`
(квадрат 512 вокруг самой длинной границы биомов, 2× NEAREST). Скрипт печатает md5 каждого
и контроль `fog=0` (обязан совпасть с байтовым эталоном T-137 `7b79ca98…`, иначе в разность
попало не только туман). Третий носитель AC 8 — соседний `make_fog_transition_carrier.py`.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageOps

FOG0_REFERENCE = "7b79ca982bea0e2961a604be929a50b4"  # байтовый эталон T-137 (--fog=0)
CROP = 512


def md5(path: Path) -> str:
    return hashlib.md5(path.read_bytes()).hexdigest()


def cells_of(png: Path) -> dict[tuple[int, int], tuple[int, int, str]]:
    with open(png.with_suffix(png.suffix + ".cells.json"), encoding="utf-8") as f:
        raw = json.load(f)["cells"]
    return {
        tuple(int(p) for p in k.split(",")): (int(v[0]), int(v[1]), str(v[2]))
        for k, v in raw.items()
    }


def longest_boundary(geo: dict) -> tuple[int, int]:
    """Центр клетки с наибольшим числом соседей другого биома — куда резать кроп переходов."""
    best, score = (0, 0), -1
    for (cx, cy), (_x, _y, biome) in geo.items():
        n = sum(
            1
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
            if (nb := geo.get((cx + dx, cy + dy))) is not None and nb[2] != biome
        )
        if n > score:
            best, score = (cx, cy), n
    return best


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--z1-on", type=Path, required=True)
    ap.add_argument("--z1-off", type=Path, required=True)
    ap.add_argument("--z05-on", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True, help="каталог носителей")
    a = ap.parse_args()
    out = a.out
    out.mkdir(parents=True, exist_ok=True)

    off_md5 = md5(a.z1_off)
    print(f"контроль fog=0: {off_md5} {'== эталон T-137' if off_md5 == FOG0_REFERENCE else '≠ ЭТАЛОН — разность нечистая'}")

    # Кадры по именам: имя несёт фактический --zoom, а не воспоминание.
    for src, name in ((a.z1_on, "frame-z10-fog.png"), (a.z05_on, "frame-z05-fog.png")):
        (out / name).write_bytes(src.read_bytes())

    on = np.asarray(Image.open(a.z1_on).convert("RGB"), dtype=np.int16)
    off = np.asarray(Image.open(a.z1_off).convert("RGB"), dtype=np.int16)
    diff = np.abs(on - off).mean(axis=2).astype(np.uint8)
    ImageOps.autocontrast(Image.fromarray(diff, mode="L")).save(out / "fog-footprint-1x.png")

    geo = cells_of(a.z1_on)
    cx, cy = longest_boundary(geo)
    px, py, _ = geo[(cx, cy)]
    crop = Image.open(a.z1_on).convert("RGB").crop(
        (max(0, px - CROP // 2), max(0, py - CROP // 2), max(CROP, px + CROP // 2), max(CROP, py + CROP // 2))
    )
    crop.resize((CROP * 2, CROP * 2), Image.NEAREST).save(out / "crop-transitions-2x.png")

    for name in ("frame-z10-fog.png", "frame-z05-fog.png", "fog-footprint-1x.png", "crop-transitions-2x.png"):
        print(f"  {md5(out / name)}  {name}")
    print(f"  кроп переходов: клетка ({cx},{cy}) — максимум соседей другого биома, {CROP}px → 2× NEAREST")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

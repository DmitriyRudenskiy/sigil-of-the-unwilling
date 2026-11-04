#!/usr/bin/env python3
"""Ручная разметка сцен: игровая зона и период решётки глазами (ветвь (а) Q-M136).

Автоматический фитт геометрии на комплекте не сошёлся (`docs/mvp/SCENE-SLICE-MEASURE.md`),
и владелец решил её руками. «Руками» не значит «на глазок в чат»: инструмент даёт кадр
с координатной сеткой, рисует обратно то, что было помечено (чтобы разметку видно было
проверить, а не предполагать), и складывает метку в `manual` запись реестра сцен. Дальше
`measure_scene_lattice.py --manual` фиттит при ограниченном руками — и мерой успеха
служит объяснённая доля нарисованных линий, а не мнение о разметке.

    python3 scripts/annotate_scenes.py --list
    python3 scripts/annotate_scenes.py --sheet --scene=<файл>        # кадр + сетка
    python3 scripts/annotate_scenes.py --mark=x,y,w,h --scene=<файл> # сохранить зону
    python3 scripts/annotate_scenes.py --sheet --scene=<файл> --grid=50   # плотнее
    python3 scripts/annotate_scenes.py --all --sheet                 # листы пачкой

Листы — в `tmp/annotate/` (пиксели в git не идут, D-185); метки — в
`game/data/config/scene_slices.json`, блок `manual` записи сцены.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import cv2
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import measure_scene_lattice as L  # noqa: E402  (тот же комплект, реестр и пороги)

SHEET_DIR = L.ROOT / "tmp/annotate"
FONT = cv2.FONT_HERSHEY_SIMPLEX


def label(img, text, x, y, color=(0, 255, 255), scale=0.4):
    """Подпись с чёрной обводкой — жёлтый по светлой траве без неё нечитаем."""
    cv2.putText(img, text, (x, y), FONT, scale, (0, 0, 0), 3, cv2.LINE_AA)
    cv2.putText(img, text, (x, y), FONT, scale, color, 1, cv2.LINE_AA)


def sheet(img: np.ndarray, grid: int) -> np.ndarray:
    """Кадр с координатной сеткой и подписями осей в нативных пикселях сцены."""
    h, w = img.shape[:2]
    out = img.copy()
    for x in range(0, w, grid):
        cv2.line(out, (x, 0), (x, h), (0, 255, 255), 1)
        label(out, str(x), x + 2, 14 if grid >= 50 else 12)
    for y in range(0, h, grid):
        cv2.line(out, (0, y), (w, y), (0, 255, 255), 1)
        if y:
            label(out, str(y), 2, y + 12)
    label(out, f"{w}x{h} grid {grid}", 6, h - 8, (255, 255, 255), 0.5)
    return out


def draw_roi(img: np.ndarray, roi: list[int], color=(0, 0, 255)):
    x, y, w, h = roi
    cv2.rectangle(img, (x, y), (x + w - 1, y + h - 1), color, 2)
    label(img, f"manual {x},{y},{w},{h}", x + 4, max(18, y - 6), color, 0.5)
    return img


def set_manual(name: str, roi: list[int], width: float | None, orientation: str | None) -> dict:
    """Метка сцены в реестр. Дополняет запись, не трогает замеры (тот же закон, что у
    `update_registry`: последний прогон не имеет права стирать предыдущий)."""
    reg = L.load_registry()
    rec = reg.setdefault("scenes", {}).setdefault(name, {})
    man = rec.setdefault("manual", {})
    man["roi"] = roi
    if width is not None:
        man["W"] = width
    if orientation:
        man["orientation"] = orientation
    L.REGISTRY.write_text(json.dumps(reg, ensure_ascii=False, indent=1) + "\n")
    return man


def self_test() -> int:
    """Сетка и метка не должны съезжать: кадр известного размера, метка известного
    прямоугольника, пиксели угла проверены на месте."""
    img = np.zeros((400, 600, 3), np.uint8)
    got = sheet(img, 100)
    # проверяем на пустых рядах: на строке y=200 лежит ещё и горизонталь, и «пустой»
    # пиксель там найтись не может в принципе
    ok = bool(got[150, 100].max() > 0 and got[150, 102].max() == 0
              and got[200, 150].max() > 0 and got[202, 150].max() == 0)
    print(f"{'ok  ' if ok else 'FAIL'} сетка по 100 px стоит на своих местах")
    marked = draw_roi(got.copy(), [50, 60, 300, 200])
    ok2 = bool(marked[60, 50].max() > 0 and marked[259, 349].max() > 0 and marked[10, 10].max() == 0)
    print(f"{'ok  ' if ok2 else 'FAIL'} метка рисуется по переданным координатам")
    return 0 if ok and ok2 else 1


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--kit", default="")
    ap.add_argument("--scene", default="")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--sheet", action="store_true", help="положить лист в tmp/annotate/")
    ap.add_argument("--mark", default="", help="x,y,w,h — игровая зона сцены в реестр")
    ap.add_argument("--width", type=float, default=None, help="период решётки, если мерил глазами")
    ap.add_argument("--orientation", default="", choices=["", "pointy", "flat"])
    ap.add_argument("--grid", type=int, default=100)
    ap.add_argument("--out", default=str(SHEET_DIR))
    ap.add_argument("--self-test", action="store_true")
    a = ap.parse_args()
    if a.self_test:
        return self_test()

    kit = L.kit_dir(a.kit)
    if a.list:
        for n in L.kit_files(kit):
            print(n)
        return 0
    names = L.kit_files(kit) if a.all else ([a.scene] if a.scene else [])
    if not names:
        sys.exit("--scene=<файл> или --all (см. --list)")

    out_dir = Path(a.out)
    for name in names:
        path = Path(name) if Path(name).is_file() else kit / name
        img = cv2.imread(str(path), cv2.IMREAD_COLOR)
        if img is None:
            sys.exit(f"не читается кадр: {path}")
        stem = Path(name).stem[:24]
        reg = L.load_registry()
        man = reg.get("scenes", {}).get(name, {}).get("manual")
        canvas = img
        if a.sheet:
            canvas = sheet(img, a.grid)
            if man and man.get("roi"):
                draw_roi(canvas, man["roi"])
            out_dir.mkdir(parents=True, exist_ok=True)
            dst = out_dir / f"{stem}.png"
            cv2.imwrite(str(dst), canvas)
            print(f"ЛИСТ: {dst}")
        if a.mark:
            roi = [int(v) for v in a.mark.split(",")]
            assert len(roi) == 4, "формат x,y,w,h"
            saved = set_manual(name, roi, a.width, a.orientation or None)
            check = draw_roi(sheet(img, a.grid).copy(), roi)
            dst = out_dir / f"{stem}.marked.png"
            out_dir.mkdir(parents=True, exist_ok=True)
            cv2.imwrite(str(dst), check)
            print(f"МЕТКА: {json.dumps(saved, ensure_ascii=False)} → переснято: {dst}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

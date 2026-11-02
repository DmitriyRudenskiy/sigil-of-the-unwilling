#!/usr/bin/env python3
"""Аудит комплекта фигур героев: альфа, холст, опорная точка, происхождение.

Зачем. `scripts/check_hero_frames.py` (T-318) держит связку «кадр ↔ манифест
сборки», то есть **идентичность байтов**. Он молчит, если в игру встал кадр
правильного героя, но другой геометрии: без альфы, на чужом холсте, с ногами
выше опорной линии или с хромакеем в углу. Такой кадр игра не отвергает —
он просто хуже выглядит в бою, и замечает это только глаз. Задача 3.6 смены
`alpha-battle-field` требует машины, которая меряет именно эти четыре оси по
тем же кодам, что и аудит демо-комплекта (`battle-demo/tools/audit_sprites.py`),
— отсюда соседний скрипт с тем же словарём нарушений.

Что проверяется по каждому кадру `game/assets/sprites/<hero>/<hero>_<action>_<NN>.png`:

* `нет альфа-канала` — режим PNG без альфы либо альфа нулевая везде;
* `размер` — холст обязан равняться `canvas` из манифеста сборки (дефолт 512);
* `силуэт касается края кадра` — альфа-bounding box задевает рамку;
* `хромакей в углу` — непрозрачный зелёный в одном из четырёх углов;
* `опорная точка` — низ силуэта обязан стоять на `feet_y` (дефолт 448) в допуске
  `ANCHOR_BELOW`/`ANCHOR_ABOVE`;
* `рост силуэта` — высота силуэта в полосе `[0.75 × figure_h, figure_h + FIGURE_TOL]`
  (дефолт 384 → [288, 392]);
* `происхождение` — у каталога героя есть `frames_manifest.json`: без него кадр
  не с чем связать, и его геометрия не проверяема (пишется отдельной строкой).

Допуски взяты из замера живого комплекта (2026-10-30, 5 героев / 300 кадров):
низ силуэта лежит в полосе 438–448 при опоре 448, рост — 330–384. То есть допуск
по опорной точке (12 px выше, 2 px ниже) и нижняя граница роста (0.75 × figure_h)
не подгоняются под живой набор, а покрывают его с запасом; красным станет только
существенный сдвиг.

Идентичность персонажа (оси D-297) здесь не мерится — она остаётся за ux-review
и контактным листом `scripts/hero_identity_audit.py`.

    python3 scripts/audit_hero_frames.py                 # код 0 = комплект чист
    python3 scripts/audit_hero_frames.py --report /tmp/a.json
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parents[1]
SPRITES = REPO / "game/assets/sprites"

FRAME = re.compile(r"^.+_(idle|walk|attack|hit|turn)_\d{2}\.png$")

CANVAS_DEFAULT = 512
FEET_Y_DEFAULT = 448
FIGURE_H_DEFAULT = 384
# Допуски опорной точки: ниже линии ноги не уходят вовсе (силуэт проваливается
# за землю), выше — на величину, замеченную в живом комплекте (10 px) с запасом.
ANCHOR_ABOVE = 12
ANCHOR_BELOW = 2
FIGURE_TOL = 8
FIGURE_MIN_SHARE = 0.75

CHROMA = (0, 255, 0)
CHROMA_TOLERANCE = 40


def check_chroma(image: Image.Image) -> str | None:
    """Непрозрачный пиксель хромакея в одном из четырёх углов кадра.

    Тот же код и тот же допуск, что у аудита демо-комплекта: два аудитора с
    разными порогами хромакея — это два разных ответа на один вопрос.
    """
    width, height = image.size
    for x, y in ((0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)):
        r, g, b, a = image.getpixel((x, y))
        if a > 200 and all(abs(v - c) <= CHROMA_TOLERANCE
                           for v, c in ((r, 0), (g, 255), (b, 0))):
            return f"хромакей в углу ({x}, {y}): {(r, g, b, a)}"
    return None


def geometry(manifest: dict) -> tuple:
    """(canvas, feet_y, figure_h) — из манифеста сборки, иначе дефолты HERO-ANIM.md."""
    return (int(manifest.get("canvas", CANVAS_DEFAULT)),
            int(manifest.get("feet_y", FEET_Y_DEFAULT)),
            int(manifest.get("figure_h", FIGURE_H_DEFAULT)))


def check_frame(path: Path, canvas: int, feet_y: int, figure_h: int) -> list:
    """Список нарушений по одному кадру; пустой список — кадр чист."""
    problems = []
    image = Image.open(path)
    if image.mode != "RGBA":
        return [f"нет альфа-канала: режим {image.mode}"]
    if image.size != (canvas, canvas):
        problems.append(f"размер {image.size[0]}×{image.size[1]}, надо {canvas}×{canvas}")
    box = image.getchannel("A").getbbox()
    if box is None:
        problems.append("пустой кадр: альфа нулевая во всех пикселях")
        return problems
    if box[0] == 0 or box[1] == 0 or box[2] >= image.size[0] or box[3] >= image.size[1]:
        problems.append(f"силуэт касается края кадра: bounding box {list(box)}")
    chroma = check_chroma(image)
    if chroma:
        problems.append(chroma)
    bottom = box[3] - 1
    if bottom > feet_y + ANCHOR_BELOW or bottom < feet_y - ANCHOR_ABOVE:
        problems.append(
            f"опорная точка вне допуска: низ силуэта y={bottom}, опора feet_y={feet_y} "
            f"(допуск −{ANCHOR_ABOVE}…+{ANCHOR_BELOW} px)")
    height = box[3] - box[1]
    lo, hi = round(figure_h * FIGURE_MIN_SHARE), figure_h + FIGURE_TOL
    if not lo <= height <= hi:
        problems.append(
            f"рост силуэта вне допуска: {height} px, ожидается в полосе [{lo}, {hi}]")
    return problems


def audit(sprites: Path = SPRITES) -> dict:
    rows = []
    for hero in sorted(p for p in sprites.iterdir() if p.is_dir()):
        frames = sorted(f for f in hero.glob("*.png")
                        if FRAME.match(f.name) and f.name.startswith(hero.name + "_"))
        if not frames:
            continue
        mp = hero / "frames_manifest.json"
        provenance = mp.exists()
        manifest = json.loads(mp.read_text(encoding="utf-8")) if provenance else {}
        canvas, feet_y, figure_h = geometry(manifest)
        for f in frames:
            problems = check_frame(f, canvas, feet_y, figure_h)
            if not provenance:
                problems.insert(0, "происхождение: нет frames_manifest.json — кадр "
                                  "не связан со сборкой, геометрия не проверяема")
            rows.append({"hero": hero.name, "file": f.name, "ok": not problems,
                         "problems": problems})
    bad = [r for r in rows if not r["ok"]]
    return {"sprites": str(sprites), "checked": len(rows),
            "accepted": len(rows) - len(bad), "rejected": len(bad),
            "files": rows}


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("sprites", nargs="?", default=str(SPRITES))
    ap.add_argument("--report", default=None)
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args(argv)
    res = audit(Path(args.sprites))
    if args.report:
        Path(args.report).write_text(json.dumps(res, ensure_ascii=False, indent=1),
                                     encoding="utf-8")
    if not args.quiet:
        for row in res["files"]:
            if not row["ok"]:
                for p in row["problems"]:
                    print(f"БРАК {row['hero']}/{row['file']}: {p}")
        print(f"КАДРОВ {res['checked']}, принято {res['accepted']}, "
              f"брак {res['rejected']}")
    return 1 if res["rejected"] else 0


if __name__ == "__main__":
    sys.exit(main())

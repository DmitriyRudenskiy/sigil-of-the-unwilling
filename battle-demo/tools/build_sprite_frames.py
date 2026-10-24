#!/usr/bin/env python3
"""Собирает `AnimatedSprite2D`-атлас из принятых клипов (задача 6.15, D10).

На входе — клипы, помеченные в `artifacts/verdicts.json` как годные. Каждый кадр
приводится к каноническому холсту: силуэт масштабируется до высоты 96 px (D1),
ступни ставятся в общую точку отрисовки. После этого pivot у всех кадров одного
юнита общий, и в движке спрайт ставится в точку мира без поправок на кадр.

Холст 128×128, ступни — в (64, 112). Узел в сцене обязан быть с
`centered = false` и `offset = Vector2(-64, -112)`; это один константный параметр,
его пишет сюда, а не в голову читателю.

Текстуры (png) в git не идут (D-185): их пересобирает `gen_clip.py` + этот
инструмент. Сам `.sprite_frames` пишет Godot (`tools/build_sprite_frames.gd`) —
формат ресурса надёжно сериализует только движок, а не наша строка. Расширение —
`.sprite_frames.tres`: голое `.sprite_frames` знает только редактор, а
`ResourceSaver` на нём отвечает «File unrecognized». В git идёт и ресурс, и план
сборки: они и есть контракт имени дорожки (D10) и порядка кадров.

    python3 battle-demo/tools/build_sprite_frames.py --char knight
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
GODOT_ROOT = ROOT.parent / "game"
CLIPS = ROOT / "artifacts/clips"
SPRITES = ROOT / "assets/sprites"
VERDICTS = ROOT / "artifacts/verdicts.json"
CLIP_MANIFEST = ROOT / "artifacts/clip-manifest.json"

CANVAS = 128
# Стопы канона: x — середина холста, y — на 16 px ниже низа силуэта не ставим,
# берем 112, чтобы над головой остался запас в 16 px при силуете в 96 px.
FEET = (64, 112)
UNIT_HEIGHT = 96
# Частота дорожки: 4 кадра клипа на цикл (D9). Удар и получение урона читаются
# быстрее; `turn` — разворот на месте, он тоже короткий.
FPS = {"idle": 4.0, "walk": 4.0, "attack": 8.0, "hit": 8.0, "turn": 8.0}
LOOPING = {"idle", "walk"}


def normalize(source: Path, target: Path) -> None:
    """Один кадр → канонический холст: высота силуэта 96 px, ступни в FEET."""
    image = Image.open(source).convert("RGBA")
    box = image.getchannel("A").getbbox()
    if not box:
        raise SystemExit(f"{source}: пустой кадр, ступни ставить некуда")
    silhouette = image.crop(box)
    scale = UNIT_HEIGHT / (box[3] - box[1])
    size = (max(1, round(silhouette.width * scale)),
            max(1, round(silhouette.height * scale)))
    silhouette = silhouette.resize(size, Image.LANCZOS)
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    canvas.paste(silhouette, (FEET[0] - size[0] // 2, FEET[1] - size[1]), silhouette)
    target.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(target)


def build(char: str) -> dict:
    """Готовит канонические холсты и план сборки; .sprite пишет Godot."""
    verdicts = json.loads(VERDICTS.read_text()) if VERDICTS.exists() else {}
    rows = [row for row in json.loads(CLIP_MANIFEST.read_text()) if row["char"] == char]
    animations = {}
    for row in rows:
        if row["anim"] not in FPS:
            continue
        key = f"battle-demo/artifacts/clips/{char}/{row["anim"]}"
        verdict = verdicts.get(key, "")
        if not verdict.startswith("годен"):
            print(f"  пропуск {row['anim']}: {verdict or 'нет вердикта'}", file=sys.stderr)
            continue
        frames = []
        for index, path in enumerate(row["subsampled"]):
            target = SPRITES / char / row["anim"] / f"{index:02d}.png"
            normalize(ROOT.parent / path, target)
            frames.append(f"res://assets/sprites/{char}/{row['anim']}/{index:02d}.png")
        animations[row["anim"]] = frames

    if not animations:
        raise SystemExit(f"{char}: нет ни одного годного клипа — собирать нечего")
    plan = {
        "char": char,
        "feet_offset": [-FEET[0], -FEET[1]],
        "animations": [
            {"name": name, "loop": name in LOOPING, "fps": FPS[name], "frames": frames}
            for name, frames in sorted(animations.items())
        ],
        "out": f"res://assets/sprites/{char}.sprite_frames.tres",
    }
    plan_path = ROOT / "artifacts/sprite-plan.json"
    plan_path.write_text(json.dumps(plan, ensure_ascii=False, indent=2))
    return {"plan": str(plan_path.relative_to(ROOT.parent)),
            "animations": {row["name"]: len(row["frames"]) for row in plan["animations"]},
            "run": "godot --headless --path battle-demo --script res://tools/build_sprite_frames.gd"}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--char", required=True)
    args = parser.parse_args()
    print(json.dumps(build(args.char), ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

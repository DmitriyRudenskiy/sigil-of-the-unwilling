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
import hashlib
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
# Новый процесс: A-pose → 81 кадр. Дорожки отсюда перекрывают принятый комплект.
APOSE = ROOT / "artifacts/clips-apose"
## У этих A-pose оружия нет вообще (`assets/a_pose_v2` снято до цепочки
## extract+merge из `tools/spec.json` «kit»), а в принятом idle оно есть: меч у
## рыцаря, лук у лучника, топор у варвара, кинжалы у разбойника. Перекрывать
## годный кадр безоружным — значит показать юнита без оружия в покое, поэтому
## idle этих четырёх остаётся принятым. Снимается строка с пересъёмкой
## weapon-merged A-pose (walk от этого пока не спасено — дорожки раньше не было).
APOSE_NO_WEAPON = {"archer", "barbarian", "cutthroat", "knight"}
FRAME_COUNT = 4

CANVAS = 128
# Стопы канона: x — середина холста, y — на 16 px ниже низа силуэта не ставим,
# берем 112, чтобы над головой остался запас в 16 px при силуете в 96 px.
FEET = (64, 112)
UNIT_HEIGHT = 96
# Частота дорожки: 4 кадра клипа на цикл (D9). Удар и получение урона читаются
# быстрее; `turn` — разворот на месте, он тоже короткий.
FPS = {"idle": 4.0, "walk": 4.0, "attack": 8.0, "hit": 8.0, "turn": 8.0}
LOOPING = {"idle", "walk"}


def digest(source: Path) -> str:
    return hashlib.sha256(source.read_bytes()).hexdigest()


def distinct_frames(clip_dir: Path, count: int) -> list[Path]:
    """Кадры дорожки без двух одинаковых картинок подряд (владелец, 2026-10-25).

    Подряд идущие совпадения по хешу выбрасываем, оставшееся прореживаем ровно.
    После нормального прогона повторов нет (замер 2026-10-25: 18 дорожек × 81 кадр —
    81 уникальный хеш), но застывший кадр модели дорожку не портит, а превращает
    её в «два одинаковых кадра подряд» — это и ловит проверка.
    """
    pool, previous = [], None
    for path in sorted(clip_dir.glob("frame_*.png")):
        current = digest(path)
        if current != previous:
            pool.append(path)
        previous = current
    if len(pool) < count:
        raise SystemExit(f"{clip_dir}: кадров уникальных по хешу {len(pool)} < {count}")
    return [pool[round(index * (len(pool) - 1) / (count - 1))] for index in range(count)]


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


def apose_tracks(char: str) -> dict[str, list[str]]:
    """Дорожки нового процесса (A-pose → 81 кадр, `gen_clip_apose.py`).

    Вердикт лежит рядом с клипом в `report.json`; дорожка принятым клипам не
    конкурент, а перекрывает свою (у idle/walk источник теперь A-pose).
    """
    tracks = {}
    if not (APOSE / char).is_dir():
        return tracks
    for report in sorted((APOSE / char).glob("*/report.json")):
        anim = report.parent.name
        data = json.loads(report.read_text())
        if not data["verdict"].startswith("годен"):
            print(f"  пропуск {anim}: {data['verdict']}", file=sys.stderr)
            continue
        if anim == "idle" and char in APOSE_NO_WEAPON:
            print(f"  пропуск {anim}: A-pose без оружия, остаётся принятый кадр",
                  file=sys.stderr)
            continue
        clip_dir = report.parent
        frames = []
        for index, path in enumerate(distinct_frames(clip_dir, FRAME_COUNT)):
            target = SPRITES / char / anim / f"{index:02d}.png"
            normalize(path, target)
            frames.append(f"res://assets/sprites/{char}/{anim}/{index:02d}.png")
        tracks[anim] = frames
    return tracks


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
        path_dir = key
        frames = []
        for index, path in enumerate(distinct_frames(ROOT.parent / path_dir, len(row["subsampled"]))):
            target = SPRITES / char / row["anim"] / f"{index:02d}.png"
            normalize(path, target)
            frames.append(f"res://assets/sprites/{char}/{row['anim']}/{index:02d}.png")
        animations[row["anim"]] = frames

    for name, frames in apose_tracks(char).items():
        animations[name] = frames

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

#!/usr/bin/env python3
"""Собирает `AnimatedSprite2D`-атлас из принятых клипов (задача 6.15, D10).

На входе — клипы, помеченные в `artifacts/verdicts.json` как годные. Каждый кадр
приводится к каноническому холсту: силуэт масштабируется до высоты UNIT_HEIGHT,
ступни ставятся в общую точку отрисовки. После этого pivot у всех кадров одного
юнита общий, и в движке спрайт ставится в точку мира без поправок на кадр.

Холст 512×512, ступни — в (256, 448), высота силуэта 384 px (спека
`battle-demo-sprites`, «Техническая форма кадра»). Узел в сцене обязан быть с
`centered = false`, `offset = Vector2(-256, -448)` и `scale = 0.25`: движок рисует
юнита в тех же 96 px, что и до переезда на 512, — масштаб кадра и масштаб экрана
разведены и встречаются в одной константе `ENGINE_SCALE` в
`scripts/view/battle_unit_view.gd`.

Имя файла кадра — `char_<side>_<name>_<anim>_<NN>.png` (спека «Нейминг файлов»),
`side` — `player` или `enemy`, `NN` — номер кадра с единицы (`01..04`,
`docs/asset-spec.md` «Выходные файлы»); кадры юнита лежат в
`assets/sprites/<id>/` — так же, как их собирает `.sprite_frames`.
Форму, имена и полноту по всем файлам проверяет `tools/audit_sprites.py`.

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

## Форма кадра по спеке: холст 512×512, силуэт 384 px, ступни в (256, 448) —
## те же пропорции, что были у 128-канваса, умноженные на 4. Клип модели и так
## приходит 512×512, так что это не апскейл, а отказ от лишнего даунскейла.
CANVAS = 512
FEET = (256, 448)
UNIT_HEIGHT = 384
## Запас по бокам холста: касание края силуэтом аудит считает браком.
EDGE_MARGIN = 8
## Враг в демо один, и он не из пула (постоянный зверь), поэтому `side` в имени
## файла выводится из id, а не хранится в данных юнита.
ENEMY_IDS = {"wolf"}


def frame_name(char: str, anim: str, index: int) -> str:
    """Имя файла кадра по схеме спеки: `char_<side>_<name>_<anim>_<NN>.png`.

    `index` — номер дорожки с нуля, `NN` — с единицы (`01..04`).
    """
    side = "enemy" if char in ENEMY_IDS else "player"
    return f"char_{side}_{char}_{anim}_{index + 1:02d}.png"


def frame_target(char: str, anim: str, index: int) -> tuple[Path, str]:
    """Куда писать кадр и как на него ссылается план сборки `.sprite_frames`."""
    name = frame_name(char, anim, index)
    return SPRITES / char / name, f"res://assets/sprites/{char}/{name}"
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
    """Один кадр → канонический холст: высота силуэта UNIT_HEIGHT, ступни в FEET.

    Кроме высоты ограничивается и ширина — с запасом `EDGE_MARGIN`: широкий кадр
    (рык волка в `attack` перекрывает холст целиком) иначе обрезается по краю, а
    это брак по спеке («Персонаж обрезан по краю»).
    """
    image = Image.open(source).convert("RGBA")
    box = image.getchannel("A").getbbox()
    if not box:
        raise SystemExit(f"{source}: пустой кадр, ступни ставить некуда")
    silhouette = image.crop(box)
    scale = min(UNIT_HEIGHT / (box[3] - box[1]),
                (CANVAS - 2 * EDGE_MARGIN) / (box[2] - box[0]))
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
            target, res_path = frame_target(char, anim, index)
            normalize(path, target)
            frames.append(res_path)
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
            target, res_path = frame_target(char, row["anim"], index)
            normalize(path, target)
            frames.append(res_path)
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

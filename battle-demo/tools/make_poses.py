#!/usr/bin/env python3
"""Карты поз для прогона (задача 6.5 tasks.md).

Поза — скелет DWPose **этого же персонажа** (D14): исходный скелет берётся из
`assets/poses/_dwpose/<id>.json`, а каждый кадр анимации — ручная правка
ключевых точек (поводки вокруг суставов) с сохранением пропорций персонажа.
Рендер идёт тем же `dwpose.draw_poses`, что и базовая карта, поэтому модель
видит привычный ей OpenPose-стиль.

Запуск: python3 battle-demo/tools/make_poses.py
"""
import hashlib
import json
import math
import sys
from pathlib import Path

import comfy  # только ROOT + load_spec
from dwpose import draw_poses, decode_json_as_poses
from dwpose.util2 import HWC3
from PIL import Image

ROOT = comfy.ROOT
DWPOSE_DIR = "battle-demo/assets/poses/_dwpose"
OUT_DIR = "battle-demo/assets/poses"

# OpenPose COCO-18: 0 nose, 1 neck, 2 RS, 3 RE, 4 RW, 5 LS, 6 LE, 7 LW,
# 8 RH, 9 RK, 10 RA, 11 LH, 12 LK, 13 LA, 14 REye, 15 LEye, 16 REar, 17 LEar
HEAD = [0, 14, 15, 16, 17]
R_ARM = [2, 3, 4]
L_ARM = [5, 6, 7]
R_LEG = [8, 9, 10]
L_LEG = [11, 12, 13]
TORSO = [1, 2, 5, 8, 11]
UPPER = [1, 2, 5, 3, 6, 4, 7] + HEAD


def pts(body: list, indices: list) -> list:
    return [(body[i * 3], body[i * 3 + 1]) for i in indices]


def put(body: list, indices: list, moved: list) -> None:
    for index, (x, y) in zip(indices, moved):
        body[index * 3] = x
        body[index * 3 + 1] = y


def rotate(group: list, pivot: tuple, angle: float) -> list:
    rad = math.radians(angle)
    cos, sin = math.cos(rad), math.sin(rad)
    return [(px + cos * (x - px) - sin * (y - py), py + sin * (x - px) + cos * (y - py))
            for x, y in group for px, py in [pivot]]


def shift(group: list, dx: float, dy: float) -> list:
    return [(x + dx, y + dy) for x, y in group]


def squash(group: list, axis_x: float, factor: float) -> list:
    return [(axis_x + (x - axis_x) * factor, y) for x, y in group]


def apply(body: list, indices: list, transform) -> None:
    put(body, indices, transform(pts(body, indices)))


def similarity(from_pairs: list, to_pairs: list):
    """Похожее преобразование по двум соответствиям (поворот + масштаб + сдвиг)."""
    (ax, ay), (bx, by) = from_pairs
    (cx, cy), (dx, dy) = to_pairs
    vx, vy = bx - ax, by - ay
    wx, wy = dx - cx, dy - cy
    norm = vx * vx + vy * vy or 1.0
    a = (vx * wx + vy * wy) / norm
    b = (vx * wy - vy * wx) / norm
    return lambda x, y: (a * (x - ax) - b * (y - ay) + cx, b * (x - ax) + a * (y - ay) + cy)


def transform_extras(body: list, source: dict, head_from: list, head_to: list,
                     rwrist_from: list, rwrist_to: list, lwrist_from: list, lwrist_to: list) -> None:
    """Лицо и кисти едут за головой и запястьями: то же преобразование, что получил родитель."""
    for key, (from_pairs, to_pairs) in {
        "face_keypoints_2d": (head_from, head_to),
        "hand_right_keypoints_2d": (rwrist_from, rwrist_to),
        "hand_left_keypoints_2d": (lwrist_from, lwrist_to),
    }.items():
        values = source.get(key)
        if not values or None in from_pairs or None in to_pairs:
            continue
        move = similarity(from_pairs, to_pairs)
        for i in range(0, len(values), 3):
            if values[i + 2] < 1.0:
                continue
            values[i], values[i + 1] = move(values[i], values[i + 1])


def joint(body: list, index: int) -> tuple | None:
    return (body[index * 3], body[index * 3 + 1]) if body[index * 3 + 2] >= 1.0 else None


def retarget(sample: dict, target: dict) -> dict:
    """Поза образца походки, перенесённая в масштаб и положение персонажа.

    Соответствие — бёдро→шея образца на бёдро→шею персонажа (поворот + масштаб +
    сдвиг), ему же подвергаются лицо и кисти. Скелет персонажа при этом остаётся
    своим (D14): образец даёт движение, а не пропорции.
    """
    def hip_neck(keypoints: list) -> tuple:
        return ((keypoints[8 * 3], keypoints[8 * 3 + 1]),
                (keypoints[1 * 3], keypoints[1 * 3 + 1]))

    move = similarity(hip_neck(sample["pose_keypoints_2d"]), hip_neck(target["pose_keypoints_2d"]))
    pose = json.loads(json.dumps(sample))
    for key in ("pose_keypoints_2d", "face_keypoints_2d",
                "hand_left_keypoints_2d", "hand_right_keypoints_2d"):
        values = pose.get(key)
        if not values:
            continue
        for i in range(0, len(values), 3):
            if values[i + 2] < 1.0:
                continue
            values[i], values[i + 1] = move(values[i], values[i + 1])
    return pose


def frame_pose(body: list, animation: str, frame: int) -> None:
    """Ручная правка ключевых точек одного кадра. Углы — в градусах, «минус» — вперёд."""
    neck = joint(body, 1)
    if animation == "idle":
        # Дыхание: корпус поднимается и опускается, руки идут в противофазе.
        # Мелкий сдвиг (±5 px) модель не читает вовсе — кадр совпадает с кадром
        # (проверено 2026-10-24: idle_01 и idle_02 вышли одинаковыми).
        # Дыхание с переносом веса: таз уезжает в сторону, корпус наклоняется,
        # колени сгибаются. Сдвиг корпуса без переноса веса модель «выпрямляет»
        # в свою каноническую стойку — кадры совпадают (проверено 2026-10-24,
        # idle_03/idle_04 при ±26 px по вертикали).
        hip, lean, knee = [(0, 0, 0), (34, -9, 12), (14, -3, 5), (-30, 8, -10)][frame - 1]
        apply(body, UPPER + TORSO + HEAD, lambda g: rotate(g, joint(body, 8), lean))
        apply(body, TORSO + HEAD + UPPER + R_LEG + L_LEG, lambda g: shift(g, hip * 0.4, 0))
        apply(body, R_LEG, lambda g: rotate(g, joint(body, 8), knee))
        apply(body, L_LEG, lambda g: rotate(g, joint(body, 11), -knee * 0.6))
        apply(body, R_ARM, lambda g: rotate(g, joint(body, 2), -lean * 1.5))
        apply(body, L_ARM, lambda g: rotate(g, joint(body, 5), lean * 1.2))
    elif animation == "walk":
        legs = [(26, -18), (0, 0), (-26, 18), (-8, 8)][frame - 1]
        apply(body, R_LEG, lambda g: rotate(g, joint(body, 8), legs[0]))
        apply(body, L_LEG, lambda g: rotate(g, joint(body, 11), legs[1]))
        apply(body, R_ARM, lambda g: rotate(g, joint(body, 2), -legs[0] * 0.8))
        apply(body, L_ARM, lambda g: rotate(g, joint(body, 5), -legs[1] * 0.8))
        apply(body, UPPER + TORSO, lambda g: shift(g, 0, [0, -8, 0, -4][frame - 1]))
    elif animation == "attack":
        arm, lean = [(-70, 4), (-20, -6), (95, -22), (40, -8)][frame - 1]
        apply(body, R_ARM, lambda g: rotate(g, joint(body, 2), arm))
        apply(body, L_ARM, lambda g: rotate(g, joint(body, 5), -arm * 0.35))
        apply(body, UPPER + TORSO, lambda g: rotate(g, neck, lean))
        apply(body, HEAD, lambda g: rotate(g, neck, -lean * 0.6))
        apply(body, R_LEG, lambda g: rotate(g, joint(body, 8), [6, 0, -14, -6][frame - 1]))
    elif animation == "hit":
        lean = [22, 10, -14, 0][frame - 1]
        apply(body, UPPER + TORSO, lambda g: rotate(g, neck, lean))
        apply(body, HEAD, lambda g: rotate(g, neck, lean * 0.6))
        apply(body, R_ARM, lambda g: rotate(g, joint(body, 2), lean * 1.4))
        apply(body, L_ARM, lambda g: rotate(g, joint(body, 5), lean * 1.1))
    elif animation == "turn":
        # Поворот корпуса: плечи и бёдро сжимаются по горизонтали вокруг центра,
        # дальняя рука уходит за спину (ближняя — наоборот).
        # Поворот корпуса вокруг вертикальной оси: сжимается весь силуэт,
        # руки уходят в сторону поворота. Без сжатия ног кадр почти не меняется
        # (проверено на первом варианте: turn_01…04 совпадали).
        factor, twist = [(0.8, 18), (0.5, 34), (0.68, -22), (1.0, 0)][frame - 1]
        center = (joint(body, 8)[0] + joint(body, 11)[0]) / 2
        apply(body, TORSO + R_ARM + L_ARM + HEAD + R_LEG + L_LEG, lambda g: squash(g, center, factor))
        apply(body, R_ARM, lambda g: shift(g, twist, 0))
        apply(body, L_ARM, lambda g: shift(g, -twist, 0))
    else:
        raise ValueError(f"неизвестная анимация {animation}")


def render(person: dict, canvas: int) -> Image.Image:
    poses, height, width = decode_json_as_poses(json.dumps({
        "people": [person], "canvas_height": canvas, "canvas_width": canvas}))
    return Image.fromarray(HWC3(draw_poses(poses, height, width)))


def build_character(character: dict, animations: list, frames: int,
                    motion: dict) -> list:
    source = json.loads((ROOT / DWPOSE_DIR / f"{character['id']}.json").read_text())
    rows = []
    for animation in animations:
        for frame in range(1, frames + 1):
            own = json.loads(json.dumps(source["people"][0]))
            reference = motion.get(animation)
            if reference:
                sample = json.loads((ROOT / reference["dir"] /
                                     f"{reference['cells'][frame - 1]:02d}.json").read_text())
                person = retarget(sample["people"][0], own)
            else:
                person = own
            body = person["pose_keypoints_2d"]
            before = {
                "head": [joint(body, 1), joint(body, 0)],
                "rhand": [joint(body, 1), joint(body, 4)],
                "lhand": [joint(body, 1), joint(body, 7)],
            }
            if not reference:
                frame_pose(body, animation, frame)
            after = {
                "head": [joint(body, 1), joint(body, 0)],
                "rhand": [joint(body, 1), joint(body, 4)],
                "lhand": [joint(body, 1), joint(body, 7)],
            }
            transform_extras(body, person, before["head"], after["head"],
                             before["rhand"], after["rhand"], before["lhand"], after["lhand"])
            out = ROOT / OUT_DIR / character["id"] / f"{animation}_{frame:02d}.png"
            out.parent.mkdir(parents=True, exist_ok=True)
            render(person, source["canvas_height"]).save(out)
            rows.append((character["id"], animation, frame,
                         hashlib.md5(out.read_bytes()).hexdigest()))
    return rows


def main() -> int:
    spec = comfy.load_spec()
    rows = []
    for character in spec["characters"]:
        rows += build_character(character, spec["animations"], spec["frames"],
                                spec.get("motion_reference", {}))
    manifest = ROOT / OUT_DIR / "MANIFEST.md"
    manifest.write_text(
        "# Манифест карт поз (задача 6.5)\n\n"
        "Скелет — DWPose кадра-источника этого персонажа (`_dwpose/<id>.json`), кадр — "
        "ручная правка ключевых точек (`tools/make_poses.py: frame_pose`), рендер — "
        "`dwpose.draw_poses`. Файл: `<персонаж>/<анимация>_<кадр>.png`.\n\n"
        "Один файл = одна поза одного кадра: лист 2×2 (D5) модель читает как одну позу — "
        "кадры анимации получаются одинаковыми (проверено 2026-10-24, лист idle_grid).\n\n"
        "| персонаж | анимация | кадр | md5 |\n| --- | --- | --- | --- |\n"
        + "".join(f"| {r[0]} | {r[1]} | {r[2]} | {r[3]} |\n" for r in rows),
        encoding="utf-8")
    print(f"карт поз: {len(rows)} → {manifest.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

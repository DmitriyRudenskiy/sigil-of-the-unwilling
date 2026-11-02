#!/usr/bin/env python3
"""Собранные ролики героев → дорожки SpriteFrames в игре.

Роль: принятые варианты клипов (81 кадр, фон — сплошной хромакей) превращаются в
комплект того же формата, что несёт `battle-demo`: холст 512×512, ступни в
(256, 448), дорожки `idle/walk/attack/hit/turn`. `CharacterFrames` от этого не
переписывается — только получает строки таблицы, потому что геометрия опоры та же.

Кадры прореживаются (по умолчанию 12 на дорожку): 81 кадр на дорожку — это 20 МБ
прозрачных PNG на юнита, а на глаз в бою при 96 px разницы нет. Сырьё остаётся
в `scripts/hero_anim/out/` (gitignored).

    python3 scripts/hero_anim/integrate.py swordsmen archers
"""
import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, str(Path(__file__).resolve().parent))
from hero_anim import HEROES, bg_colour, download, hero_dir  # noqa: E402

GAME = Path(__file__).resolve().parents[2] / "game"
ACTIONS = ["idle", "walk", "attack", "hit", "turn"]
LOOP = {"idle": 1, "walk": 1, "attack": 0, "hit": 0, "turn": 0}
SPEED = {"idle": 6.0, "walk": 8.0, "attack": 12.0, "hit": 12.0, "turn": 8.0}
CANVAS = 512
FEET_Y = 448
FRAME = re.compile(r"^(?P<hero>.+)_(?P<action>idle|walk|attack|hit|turn)_\d{2}\.png$")
SKIP_START = 24  # Wan стартует из покоя: у цикла первые ~0.8 с — «ещё стоит»
LOOP_WINDOW = 40  # и к концу 81 кадра начинает разворачивать героя к камере
FIGURE_H = 384  # при SCALE 0.25 даёт 96 px силуэта на поле — мера комплекта
HALO = {"paladin"}  # Wan дорисовала паладину зелёное свечение: оно не фон и не герой
SPECK = 200  # замкнутый остров меньше — мусор ключа/нимба, а не часть тела (макс. настоящий 156)


def frames_of(hero: str, action: str) -> tuple:
    """Каталог полного ролика принятого варианта и номер варианта.

    Вариант возвращается наружу: он попадает в манифест сборки, потому что
    вердикт зрения («эти кадры — тот же персонаж») выносится конкретному
    варианту клипа, а не каталогу героя (T-318).
    """
    action_dir = hero_dir(hero, action)
    picked = action_dir / "picked.json"
    if not picked.exists():
        raise SystemExit(f"{hero}/{action}: нет picked.json — сначала collect --pick N")
    variant = json.loads(picked.read_text())["variant"]
    manifest = json.loads((action_dir / f"v{variant:02d}.json").read_text())
    dest = action_dir / "full" / f"v{variant:02d}"
    dest.mkdir(parents=True, exist_ok=True)
    for i, ref in enumerate(manifest):
        path = dest / f"{i:03d}.png"
        if not path.exists():
            download(ref, path)
    return dest, variant


def load_frames(d: Path, hero: str) -> list:
    """Кадры варианта → RGBA с ключом фона.

    Ключ векторизован и считается уже на уменьшенном кадре: итоговый холст — 512,
    а покадровый питон-цикл на 1024² съел бы вечер на одном герое.
    """
    out = []
    for f in sorted(d.glob("*.png")):
        if f.name in {"look.png", "sheet.png"}:
            continue
        im = Image.open(f).convert("RGB").resize((CANVAS, CANVAS), Image.LANCZOS)
        rgb = np.asarray(im).astype(np.int16)
        br, bg, bb = bg_colour(im)
        d_ = np.max(np.abs(rgb - np.array([br, bg, bb], dtype=np.int16)), axis=2)
        alpha = np.where(d_ < 60, 0, 255).astype(np.uint8)
        if hero in HALO:
            # Свечение — жёлто-зелёное, ярче тела; золотая отделка под ним R>G, сталь R≈G≈B.
            glow = ((rgb[..., 1] > rgb[..., 0] + 15) & (rgb[..., 1] > rgb[..., 2] + 40)
                    & (rgb[..., 1] > 110))
            alpha[glow] = 0
        frame = Image.fromarray(np.dstack([rgb.astype(np.uint8), alpha]), "RGBA")
        out.append(drop_specks(frame))
    return out


def drop_specks(frame: Image.Image) -> Image.Image:
    """Удалить замкнутые острова мелкой мусора, оставленные ключом и нимбом."""
    a = np.asarray(frame).copy()
    body = a[..., 3] > 0
    if not body.any():
        return frame
    labels, _ = ndimage.label(body)
    keep = np.bincount(labels.ravel()) >= SPECK
    keep[0] = False  # 0 — фон, он и так прозрачный
    a[..., 3] = np.where(keep[labels], a[..., 3], 0)
    return Image.fromarray(a, "RGBA")


def union_bbox(frames: list) -> tuple:
    """Общая рамка всех кадров дорожки — иначе дорожки гуляют друг относительно друга."""
    ys, xs = [], []
    for f in frames:
        m = np.asarray(f)[:, :, 3] > 16
        if m.any():
            ys.append(m.any(axis=1).nonzero()[0][[0, -1]])
            xs.append(m.any(axis=0).nonzero()[0][[0, -1]])
    y0 = int(min(v[0] for v in ys))
    y1 = int(max(v[1] for v in ys))
    x0 = int(min(v[0] for v in xs))
    x1 = int(max(v[1] for v in xs))
    return x0, y0, x1, y1


def compose(frames: list, bbox: tuple) -> list:
    """Кадры на общий холст комплекта: ступни в 448, фигура в 384 px, центр по x."""
    x0, y0, x1, y1 = bbox
    scale = FIGURE_H / float(y1 - y0 + 1)
    out = []
    for f in frames:
        cut = f.crop((x0, y0, x1 + 1, y1 + 1))
        w = max(1, int(round(cut.width * scale)))
        h = max(1, int(round(cut.height * scale)))
        cut = cut.resize((w, h), Image.LANCZOS)
        canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
        canvas.alpha_composite(cut, (int((CANVAS - w) / 2), FEET_Y - h))
        out.append(canvas)
    return out


def subsample(frames: list, n: int, skip: int = 0, window: int = 0) -> list:
    """Равномерная выборка `n` кадров; `skip` — отброшенное начало, `window` — потолок.

    Wan начинает ролик из позы покоя, а к концу разворачивает героя к камере, поэтому
    у зацикленных дорожек берётся середина: без отсечки цикл даёт запинку на витке и
    поворот в три четверти там, где вид должен оставаться боковым.
    """
    frames = frames[skip:] if skip < len(frames) else frames
    if window:
        frames = frames[:window]
    if len(frames) <= n:
        return frames
    idx = [round(i * (len(frames) - 1) / (n - 1)) for i in range(n)]
    return [frames[i] for i in idx]


def write_tres(hero: str, pngs: dict) -> Path:
    """Файл `.tres` в формате комплекта: ext_resource на каждый кадр + блок дорожки."""
    ids, ext = {}, []
    n = 0
    for action in ACTIONS:
        for name in pngs[action]:
            n += 1
            ident = f"{n}_h{n:04d}"
            ids[name] = ident
            ext.append(f'[ext_resource type="Texture2D" '
                       f'path="res://assets/sprites/{hero}/{name}" id="{ident}"]')
    blocks = []
    for action in ACTIONS:
        frames = ", ".join('{\n"duration": 1.0,\n"texture": ExtResource("%s")\n}'
                           % ids[name] for name in pngs[action])
        blocks.append('{\n"frames": [%s],\n"loop": %d,\n"name": &"%s",\n"speed": %s\n}' % (
            frames, LOOP[action], action, SPEED[action]))
    body = "[" + ", ".join(blocks) + "]"
    dest = GAME / "assets/sprites" / f"{hero}.sprite_frames.tres"
    dest.write_text("\n".join(
        ['[gd_resource type="SpriteFrames" format=3]', ""] + ext +
        ["", "[resource]", "animations = " + body, "", "]", ""]))
    return dest


def integrate(hero: str, frames_per_track: int) -> None:
    clips = {action: frames_of(hero, action) for action in ACTIONS}
    per_action = {action: load_frames(clips[action][0], hero) for action in ACTIONS}
    # Общая рамка считается по всем дорожкам сразу: у героя один холст, иначе
    # дорожки разъезжаются при смене анимации.
    all_frames = [f for action in ACTIONS for f in per_action[action]]
    bbox = union_bbox(all_frames)
    out_dir = GAME / "assets/sprites" / hero
    out_dir.mkdir(parents=True, exist_ok=True)
    for old in out_dir.glob(f"{hero}_*.png"):
        old.unlink()
    pngs = {}
    for action in ACTIONS:
        composed = compose(per_action[action], bbox)
        chosen = subsample(composed, frames_per_track,
                           skip=SKIP_START if LOOP[action] else 0,
                           window=LOOP_WINDOW if LOOP[action] else 0)
        pngs[action] = []
        for i, img in enumerate(chosen, start=1):
            name = f"{hero}_{action}_{i:02d}.png"
            img.save(out_dir / name)
            pngs[action].append(name)
    path = write_tres(hero, pngs)
    total = sum(len(v) for v in pngs.values())
    write_manifest(hero, frames_per_track, clips, pngs)
    print(f"{hero}: {total} кадр(ов) → {path.relative_to(GAME.parent)}")


def write_manifest(hero: str, frames_per_track: int, clips: dict, pngs: dict) -> Path:
    """Манифест сборки: какие варианты клипов легли в какие файлы игры.

    Кадры в `game/assets/sprites/` — бинарник, и до этого манифеста в репозитории
    не было ничего, что связывало бы их с вердиктом зрения: пересъёмка (или
    молчаливая перезапись старым промптом) не краснела нигде. Манифест даёт
    машинную проверку `scripts/check_hero_frames.py`: файл в игре либо совпадает
    с собранным комплектом, либо уровень краснеет.
    """
    frames = {}
    for action in ACTIONS:
        for name in pngs[action]:
            blob = (GAME / "assets/sprites" / hero / name).read_bytes()
            frames[name] = {"track": action, "sha256": hashlib.sha256(blob).hexdigest()}
    body = {
        "hero": hero,
        "canvas": CANVAS,
        "feet_y": FEET_Y,
        "figure_h": FIGURE_H,
        "frames_per_track": frames_per_track,
        "skip_start": {a: (SKIP_START if LOOP[a] else 0) for a in ACTIONS},
        "loop_window": {a: (LOOP_WINDOW if LOOP[a] else 0) for a in ACTIONS},
        "clips": {a: {"variant": clips[a][1],
                      "picked": f"scripts/hero_anim/out/{hero}/{a}/picked.json"}
                  for a in ACTIONS},
        "frames": frames,
    }
    dest = GAME / "assets/sprites" / hero / "frames_manifest.json"
    dest.write_text(json.dumps(body, ensure_ascii=False, indent=1,
                               sort_keys=True) + "\n", encoding="utf-8")
    return dest


def snapshot(hero: str, frames_per_track: int) -> Path:
    """Манифест по тому, что уже лежит в игре, без пересборки кадров.

    Нужен героям, снятым до манифеста: их сырые клипы локально не сохранились,
    пересобирать их — значит молча переписать сто двадцать верных png. Манифест-
    снимок помечен `backfilled` и защищает от последующего расхождения, но не
    утверждает, что вариант дорожки пересмотрен.
    """
    out_dir = GAME / "assets/sprites" / hero
    frames = {}
    for f in sorted(out_dir.glob(f"{hero}_*.png")):
        m = re.match(FRAME, f.name)
        if not m:
            continue
        frames[f.name] = {"track": m.group("action"),
                          "sha256": hashlib.sha256(f.read_bytes()).hexdigest()}
    clips = {}
    for action in ACTIONS:
        picked = hero_dir(hero, action) / "picked.json"
        clips[action] = {"variant": json.loads(picked.read_text())["variant"]
                         if picked.exists() else None,
                         "picked": f"scripts/hero_anim/out/{hero}/{action}/picked.json"}
    body = {"hero": hero, "canvas": CANVAS, "feet_y": FEET_Y, "figure_h": FIGURE_H,
            "frames_per_track": frames_per_track, "backfilled": True,
            "skip_start": {a: (SKIP_START if LOOP[a] else 0) for a in ACTIONS},
            "loop_window": {a: (LOOP_WINDOW if LOOP[a] else 0) for a in ACTIONS},
            "clips": clips, "frames": frames}
    dest = out_dir / "frames_manifest.json"
    dest.write_text(json.dumps(body, ensure_ascii=False, indent=1, sort_keys=True) + "\n",
                    encoding="utf-8")
    return dest


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("hero", nargs="*", default=HEROES)
    ap.add_argument("--frames", type=int, default=12)
    ap.add_argument("--backfill", action="store_true",
                    help="только манифест по кадрам в игре, без пересборки (T-318)")
    args = ap.parse_args()
    for hero in args.hero or HEROES:
        if args.backfill:
            path = snapshot(hero, args.frames)
            print(f"{hero}: манифест-снимок → {path.relative_to(GAME.parent)}")
        else:
            integrate(hero, args.frames)


if __name__ == "__main__":
    main()

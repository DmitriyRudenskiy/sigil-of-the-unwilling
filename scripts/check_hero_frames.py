#!/usr/bin/env python3
"""Кадры героев в игре обязаны совпадать с манифестом сборки (T-318).

Зачем. Кадры `game/assets/sprites/<hero>/` — бинарники, и до этого проверщика в
репозитории не было ни одной машины, которая замечала бы подмену: шесть десятков
кадров `knights` и `battle_dwarf` несли персонажа с другой картинки (не тот доспех,
не то оружие) ровно потому, что вердикт зрения никем не был привязан к файлам.
Манифест пишет `scripts/hero_anim/integrate.py`, здесь — сверка.

Что проверяется (и что НЕ проверяется):
  * у каталога героя есть `frames_manifest.json`;
  * набор png на диске равен набору в манифесте — ни лишних, ни забытых кадров;
  * хэш каждого файла совпадает с собранным комплектом.
Идентичность персонажа (четыре оси D-297) машиной не мерится: она остаётся за
ux-review и контактным листом `scripts/hero_identity_audit.py`. Проверщик
отвечает только за то, чтобы в игре лежали ровно те кадры, на которые вердикт
был вынесен.

    python3 scripts/check_hero_frames.py [путь до game/assets/sprites]
"""
import hashlib
import json
import re
import sys
from pathlib import Path

FRAME = re.compile(r"^(?P<hero>.+)_(?P<action>idle|walk|attack|hit|turn)_\d{2}\.png$")


def hero_dirs(sprites: Path) -> list:
    """Каталоги героев: те, в которых есть кадр дорожки или манифест сборки.

    Манифест без кадров — тоже герой: иначе полный набор png, удалённый руками,
    перестает быть предметом проверки ровно в тот момент, когда проверка нужнее
    всего (T-318).
    """
    out = []
    for d in sorted(p for p in sprites.iterdir() if p.is_dir()):
        has_frame = any(FRAME.match(f.name) and f.name.startswith(d.name + "_")
                        for f in d.glob("*.png"))
        if has_frame or (d / "frames_manifest.json").exists():
            out.append(d)
    return out


def check(sprites: Path) -> list:
    """Список расхождений; пустой список — кадры совпадают с манифестом."""
    problems = []
    for d in hero_dirs(sprites):
        man = d / "frames_manifest.json"
        if not man.exists():
            problems.append(
                f"{d.name}: нет frames_manifest.json — собрать заново: "
                f"python3 scripts/hero_anim/integrate.py {d.name}")
            continue
        try:
            body = json.loads(man.read_text(encoding="utf-8"))
        except json.JSONDecodeError as e:
            problems.append(f"{d.name}: манифест не читается ({e})")
            continue
        frames = body.get("frames", {})
        on_disk = {f.name for f in d.glob("*.png") if FRAME.match(f.name)}
        for name in sorted(set(frames) - on_disk):
            problems.append(f"{d.name}: {name} есть в манифесте, но не на диске")
        for name in sorted(on_disk - set(frames)):
            problems.append(f"{d.name}: {name} лежит в игре, но его нет в манифесте "
                            f"(кадр собран без вердикта?)")
        for name in sorted(set(frames) & on_disk):
            want = frames[name].get("sha256")
            got = hashlib.sha256((d / name).read_bytes()).hexdigest()
            if want != got:
                problems.append(
                    f"{d.name}: {name} не совпадает с манифестом "
                    f"(собрали другие кадры или перезаписали руками)")
    return problems


def main() -> int:
    sprites = Path(sys.argv[1]) if len(sys.argv) > 1 else (
        Path(__file__).resolve().parents[1] / "game" / "assets" / "sprites")
    if not sprites.is_dir():
        print(f"HERO FRAMES: RED — нет каталога {sprites}")
        return 1
    problems = check(sprites)
    dirs = hero_dirs(sprites)
    n = sum(len(json.loads((d / "frames_manifest.json").read_text(encoding="utf-8"))["frames"])
            for d in dirs if (d / "frames_manifest.json").exists())
    for p in problems:
        print(f"  {p}")
    if problems:
        print(f"HERO FRAMES: RED ({len(problems)} расхождений) — пересобрать: "
              f"python3 scripts/hero_anim/integrate.py <герой>")
        return 1
    print(f"HERO FRAMES: OK ({len(dirs)} герой(ов), {n} кадров сверены с манифестом)")
    return 0


if __name__ == "__main__":
    sys.exit(main())

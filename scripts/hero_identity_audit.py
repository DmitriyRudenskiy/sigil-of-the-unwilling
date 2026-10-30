#!/usr/bin/env python3
"""Контактный лист «вырез владельца → принятый профиль → кадр в игре».

Идентичность героя решается этим листом, а не текстом промпта (D-297): четыре оси —
стиль, лицо, палитра, оружие; расхождение по любой = вариант не принят. Лист
пересобирается перед каждой приёмкой профиля/дорожки (T-318 — пересъёмка троих).

    python3 scripts/hero_identity_audit.py [--out tmp/hero-identity-audit.png]

Пиксели в git не идут (D-185); артефактом смены считается этот скрипт и вердикт в
docs/mvp/matrix/<дата>/.
"""
from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw

HEROES = ["swordsmen", "archers", "knights", "paladin", "battle_dwarf"]
FIGURE = "game/assets/units/figures"
PROFILE = "scripts/hero_anim/out/{hero}/profile/adopted.png"
FRAME = "game/assets/sprites/{hero}/{hero}_idle_01.png"
BG = (40, 40, 48, 255)


def cell(root: Path, rel: str, h: int) -> Image.Image | None:
    path = root / rel
    if not path.exists():
        return None
    im = Image.open(path).convert("RGBA")
    bg = Image.new("RGBA", im.size, BG)
    bg.alpha_composite(im)
    bg.thumbnail((h, h), Image.LANCZOS)
    return bg.convert("RGB")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="tmp/hero-identity-audit.png")
    ap.add_argument("--h", type=int, default=420)
    args = ap.parse_args()
    root = Path(__file__).resolve().parent.parent
    cols = [("{hero}: вырез", f"{FIGURE}/{{hero}}.png"),
            ("профиль", PROFILE.format(hero="{hero}")),
            ("кадр в игре", FRAME.format(hero="{hero}"))]
    pad = 8
    sheet = Image.new("RGB", (3 * (args.h + pad) + pad,
                              len(HEROES) * (args.h + pad) + pad), (20, 20, 24))
    d = ImageDraw.Draw(sheet)
    missing: list[str] = []
    for r, hero in enumerate(HEROES):
        for c, (label, rel) in enumerate(cols):
            rel = rel.format(hero=hero)
            im = cell(root, rel, args.h)
            if im is None:
                missing.append(rel)
                continue
            sheet.paste(im, (pad + c * (args.h + pad), pad + r * (args.h + pad)))
        d.text((pad + 2, pad + r * (args.h + pad) + 2), f"{hero}: {', '.join(l for l, _ in cols)}",
               fill=(255, 255, 0))
    dest = Path(args.out)
    dest.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(dest)
    print(dest, sheet.size)
    if missing:
        print("нет файлов (кадр ещё не собран?):", *missing, sep="\n  ")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

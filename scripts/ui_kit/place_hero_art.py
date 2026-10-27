#!/usr/bin/env python3
"""Укладка кадров ComfyUI на носители экрана «Герой» (T-249, T-251).

Кадры рисует контур `scripts/concept_art/generate.py` по спеке
`hero_screen_spec.json`; сюда они приходят белым фоном (проверка-изолятор
генератора требует почти-белой рамки). Здесь фон срезается, кадр обрезается по
контенту и вписывается в размер носителя.

Белый фон убирается по связным областям почти-белого: прозрачной делается та
белая область, что держится за край кадра, и та, что велика (дырка в кольце,
окно в решётке щита — это фон, запертый контуром предмета). Мелкое белое
остаётся: блик на клинке и вспышка на звезде — рисунок, а не фон.

Запуск: python3 scripts/ui_kit/place_hero_art.py [--only id1,id2] [--dry]
"""
from __future__ import annotations

import argparse
import json
from collections import deque
from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "concept_art/krea2/h1_painted"
OUT = ROOT / "game/assets"
NEAR_WHITE = 232          # порог «белый» фона (кадр сжимается WEBP, 255 не держится)
KEY_SCAN = 256            # сторона, на которой ищется связность фона
ALPHA_FEATHER = 1.0       # мягкая кромка носителя, px
BG_AREA = 0.015           # белая область крупнее доли кадра — фон, а не блик

# id кадра → (носитель, бокс w×h, режим, ключить ли фон). Бокс = пропорция
# прямоугольника из hero_layout.gd: TextureRect растягивает носитель под
# фактический размер, чужая пропорция = искажённый рисунок.
TARGETS: dict[str, tuple[str, tuple[int, int], str, bool]] = {
    "hero_portrait": ("ui/hero/portrait.png", (512, 368), "cover", False),
    "hero_figure": ("ui/hero/figure.png", (428, 478), "height", True),
    "stat_attack": ("ui/icons/hero/stat_attack.png", (128, 128), "contain", True),
    "stat_defense": ("ui/icons/hero/stat_defense.png", (128, 128), "contain", True),
    "stat_magic": ("ui/icons/hero/stat_magic.png", (128, 128), "contain", True),
    "stat_knowledge": ("ui/icons/hero/stat_knowledge.png", (128, 128), "contain", True),
}

# Иконки навыков экрана «Герой»: носители те же, что были (assets/ui/icons/),
# меняются только пиксели — 40×40 плоские заглушки → 128×128 с альфой.
for _skill in ("nature_sense", "keen_eye", "navigation", "geology", "alchemy"):
    TARGETS["skill_" + _skill] = (f"ui/icons/{_skill}.png", (128, 128), "contain", True)
# иконки предметов лежат одной папкой и одним размером — список id берём из спеки
ITEMS_DEST = "artifacts/{id}.png"
ITEMS_BOX = (128, 128)


def sources() -> dict[str, Path]:
    """id → путь кадра. Каталог обхода тот, что пишет генератор."""
    out: dict[str, Path] = {}
    for p in SRC.rglob("*.webp"):
        out[p.stem] = p
    return out


def background_mask(rgb: Image.Image) -> Image.Image:
    """Альфа 0 там, где фон: почти-белое, связанное с краем кадра или крупное."""
    small = rgb.copy()
    small.thumbnail((KEY_SCAN, KEY_SCAN))
    w, h = small.size
    px = small.load()
    white = [[min(px[x, y][:3]) >= NEAR_WHITE for x in range(w)] for y in range(h)]
    bg = [[False] * w for _ in range(h)]
    seen = [[False] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            if not white[y][x] or seen[y][x]:
                continue
            comp, edge, q = [], False, deque([(x, y)])
            seen[y][x] = True
            while q:
                cx, cy = q.popleft()
                comp.append((cx, cy))
                if cx in (0, w - 1) or cy in (0, h - 1):
                    edge = True
                for nx, ny in ((cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)):
                    if 0 <= nx < w and 0 <= ny < h and white[ny][nx] and not seen[ny][nx]:
                        seen[ny][nx] = True
                        q.append((nx, ny))
            # фон = держится за край или велика; мелкое белое — блик, остаётся
            is_bg = edge or len(comp) >= BG_AREA * w * h
            for cx, cy in comp:
                bg[cy][cx] = is_bg
    mask = Image.new("L", (w, h), 255)
    mask.putdata([0 if bg[y][x] else 255 for y in range(h) for x in range(w)])
    mask = mask.resize(rgb.size, Image.BILINEAR)
    return mask.filter(ImageFilter.GaussianBlur(ALPHA_FEATHER))


def keyed(rgb: Image.Image) -> Image.Image:
    rgba = rgb.convert("RGBA")
    rgba.putalpha(background_mask(rgb))
    return rgba


def fit(im: Image.Image, box: tuple[int, int], mode: str) -> Image.Image:
    """cover — заполнить бокс, обрезав лишнее; contain — вписать с полями;
    height — по высоте, по центру по ширине (кукла держит высоту поля)."""
    bw, bh = box
    if mode == "cover":
        s = max(bw / im.width, bh / im.height)
        r = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
        x, y = (r.width - bw) // 2, (r.height - bh) // 2
        return r.crop((x, y, x + bw, y + bh))
    if mode == "height":
        s = bh / im.height
        r = im.resize((max(1, round(im.width * s)), bh), Image.LANCZOS)
        if r.width > bw:                       # шире поля — не обрезаем, а сжимаем дальше
            s = bw / r.width
            r = r.resize((bw, max(1, round(r.height * s))), Image.LANCZOS)
        out = Image.new("RGBA", box, (0, 0, 0, 0))
        out.paste(r, ((bw - r.width) // 2, (bh - r.height) // 2), r)
        return out
    s = min(bw / im.width, bh / im.height)
    r = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)
    out = Image.new("RGBA", box, (0, 0, 0, 0))
    out.paste(r, ((bw - r.width) // 2, (bh - r.height) // 2), r)
    return out


def trim(im: Image.Image) -> Image.Image:
    box = im.getbbox() if im.mode == "RGB" else im.split()[-1].getbbox()
    return im.crop(box) if box else im


def place(cid: str, src: Path, dest: Path, box, mode: str, key: bool, dry: bool) -> str:
    if not src.is_file():
        return f"{cid}: КАДРА НЕТ ({src})"
    im = Image.open(src)
    im.load()
    im = keyed(im) if key else im.convert("RGB")
    im = trim(im)
    out = fit(im, box, mode)
    if dry:
        return f"{cid}: {im.size} → {box} (dry)"
    dest.parent.mkdir(parents=True, exist_ok=True)
    out.save(dest)
    return f"{cid}: {dest.relative_to(ROOT)} {out.size} {dest.stat().st_size // 1024} КБ"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", help="список id через запятую")
    ap.add_argument("--dry", action="store_true")
    a = ap.parse_args()
    only = set(a.only.split(",")) if a.only else None
    srcs = sources()
    todo: list[tuple[str, str, tuple[int, int], str, bool]] = [
        (cid, dest, box, mode, key) for cid, (dest, box, mode, key) in TARGETS.items()]
    spec = json.loads((ROOT / "scripts/concept_art/hero_screen_spec.json").read_text())
    for item in spec["categories"]["resources"]["items"]:
        todo.append((item["id"], ITEMS_DEST.format(id=item["id"]), ITEMS_BOX, "contain", True))
    n = 0
    for cid, dest, box, mode, key in todo:
        if only and cid not in only:
            continue
        print(place(cid, srcs.get(cid, Path(".")), OUT / dest, box, mode, key, a.dry))
        n += 1
    print(f"итого: {n}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

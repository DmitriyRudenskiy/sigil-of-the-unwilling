#!/usr/bin/env python3
"""Кадр-источник каждого персонажа (задача 6.4 tasks.md).

Портрет = сам кадр-источник, обрезанный по содержимому (фон — почти белый) и
приведённый к квадрату 1024². Никакого рисования с нуля: идентичность и стиль
приходят из пикселей (D13). Файл грузится на сервер и становится первым входом
графа; имя на сервере — `sotu-<id>.png`.

Запуск: python3 battle-demo/tools/make_portraits.py [--no-upload]
"""
import argparse
import hashlib
import sys
from pathlib import Path

from PIL import Image, ImageChops

import comfy

SIDE = 1024
BG_TOLERANCE = 12
PADDING = 0.04


def crop_to_content(source: Path, out: Path) -> tuple[int, int]:
    image = Image.open(source).convert("RGB")
    background = Image.new("RGB", image.size, (255, 255, 255))
    mask = ImageChops.difference(image, background).convert("L").point(
        lambda value: 255 if value > BG_TOLERANCE else 0)
    box = mask.getbbox()
    if box is None:
        raise ValueError(f"{source}: кадр белый, содержимого нет")
    width, height = box[2] - box[0], box[3] - box[1]
    side = int(max(width, height) * (1 + PADDING * 2))
    canvas = Image.new("RGB", (side, side), (255, 255, 255))
    canvas.paste(image.crop(box), ((side - width) // 2, (side - height) // 2))
    canvas = canvas.resize((SIDE, SIDE), Image.LANCZOS)
    out.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out)
    return box[2] - box[0], box[3] - box[1]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--no-upload", action="store_true")
    parser.add_argument("--spec", default=None)
    args = parser.parse_args()

    spec = comfy.load_spec(args.spec)
    portraits = comfy.ROOT / spec["portraits_dir"]
    for character in spec["characters"]:
        source = Path(spec["sources_dir"]) / character["source"]
        out = portraits / f"{character['id']}.png"
        width, height = crop_to_content(source, out)
        digest = hashlib.md5(out.read_bytes()).hexdigest()
        server = ""
        if not args.no_upload:
            server = comfy.upload(spec["comfy"], out, f"sotu-{character['id']}.png")
        print(f"{character['id']}\t{width}x{height}\t{digest}\t{out.relative_to(comfy.ROOT)}\t{server}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

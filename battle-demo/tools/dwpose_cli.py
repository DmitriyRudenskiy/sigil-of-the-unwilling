#!/usr/bin/env python3
"""Скелет DWPose по картинке → openpose json (задача 6.5).

`python3 battle-demo/tools/dwpose_cli.py <png> --out <json|каталог> [--size 1024] [--cells N]`

`--cells N` — изображение нарезается N×N и скелет считается для каждой ячейки
(образец походки — лист 5×5, по человеку на ячейку), json-ы складываются в
`<out>/NN.json` по порядку ячеек. Без `--cells` — один человек на изображении.
"""
import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from dwpose import DwposeDetector


def detect(detector, image: Image.Image, size: int) -> dict:
    """Один проход DWPose по квадратному кадру `size`×`size` (как в 6.5).

    Квадрат нужен, чтобы координаты скелета совпали с холстом `draw_poses`
    (детектор паддит изображение до квадрата, а json описывает именно его).
    """
    source = image.convert("RGB").resize((size, size))
    _, data, _ = detector(np.array(source), image_and_json=True,
                          include_body=True, include_hand=True, include_face=True,
                          detect_resolution=size)
    return data


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("image")
    parser.add_argument("--out", required=True)
    parser.add_argument("--size", type=int, default=1024)
    parser.add_argument("--cells", type=int, help="лист N×N: скелет на каждую ячейку")
    args = parser.parse_args()

    image = Image.open(args.image)
    detector = DwposeDetector.from_pretrained("yzd-v/DWPose")
    if args.cells:
        out = Path(args.out)
        out.mkdir(parents=True, exist_ok=True)
        side_x, side_y = image.width // args.cells, image.height // args.cells
        count = 0
        for row in range(args.cells):
            for column in range(args.cells):
                cell = image.crop((column * side_x, row * side_y,
                                   (column + 1) * side_x, (row + 1) * side_y))
                people = detect(detector, cell, args.size)["people"]
                if not people:
                    print(f"ячейка {row}{column}: людей нет", file=sys.stderr)
                    continue
                (out / f"{count:02d}.json").write_text(json.dumps(
                    {"people": people[:1], "canvas_height": args.size, "canvas_width": args.size}))
                count += 1
        print(f"скелетов: {count} → {out}")
        return 0

    data = detect(detector, image, args.size)
    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    Path(args.out).write_text(json.dumps(data))
    print(f"скелетов: {len(data['people'])} → {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

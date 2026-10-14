#!/usr/bin/env python3
"""Матрица попарных dHash по набору иконок ASSET-1.

Мерка повторяет tests/unit/assets/test_resource_icons_asset1.gd (_dhash_field):
кроп поля содержимого, свёртка 9×8 билинейным ресайзом по RGBA, яркость со смешиванием альфы с носителем
(#281c0f), сравнение соседних пикселей по горизонтали. Нужна для итераций по
формам: гонять ради этого Godot долго.
"""
import glob
import itertools
import os
import sys

from PIL import Image

DIR = sys.argv[1] if len(sys.argv) > 1 else "game/assets/ui/icons/resources"
CARRIER = (0x28 / 255, 0x1C / 255, 0x0F / 255)
THRESHOLD = int(sys.argv[2]) if len(sys.argv) > 2 else 12


def lum(px):
    a = px[3] / 255.0
    r = px[0] / 255.0 * a + CARRIER[0] * (1 - a)
    g = px[1] / 255.0 * a + CARRIER[1] * (1 - a)
    b = px[2] / 255.0 * a + CARRIER[2] * (1 - a)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


FIELD = 8


def dhash(img):
    """Хэш поля содержимого (канвас − 8 px): на всём канвасе мера вырождена."""
    im = img.convert("RGBA").crop((FIELD, FIELD, 32 - FIELD, 32 - FIELD))
    small = im.resize((9, 8), Image.BILINEAR)
    h = 0
    for y in range(8):
        for x in range(8):
            if lum(small.getpixel((x, y))) > lum(small.getpixel((x + 1, y))):
                h |= 1 << (y * 8 + x)
    return h


def hamming(a, b):
    return bin(a ^ b).count("1")


paths = sorted(glob.glob(os.path.join(DIR, "icon_resource_*.png")))
ids = [os.path.basename(p)[len("icon_resource_"):-4] for p in paths]
h = {i: dhash(Image.open(p)) for i, p in zip(ids, paths)}
pairs = sorted((hamming(h[a], h[b]), a, b) for a, b in itertools.combinations(ids, 2))
worst = [p for p in pairs if p[0] < THRESHOLD]
print(f"иконок {len(ids)}, пар {len(pairs)}, порог {THRESHOLD}")
print("худшие 12:", [(d, a, b) for d, a, b in pairs[:12]])
print(f"красных пар: {len(worst)}")
for d, a, b in worst:
    print(f"  {d:2d}  {a} ↔ {b}")
sys.exit(1 if worst else 0)

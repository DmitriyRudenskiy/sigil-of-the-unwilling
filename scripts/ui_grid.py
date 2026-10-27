#!/usr/bin/env python3
"""Разметка кадра адресной сеткой (A1..J10) и вырезание ячейки.

Зачем: ux-review обязан разбирать кадр поэлементно (AGENTS.md «UX-review машинным
зрением»), а расхождение надо чем-то зафиксировать. Сетка даёт словарь: «кнопка в
D5» и в кадре, и в макете — про одни и те же координаты, если размечать ОБОИМ
одинаковым --cols/--rows.

Инструмент размечает и кроит, он ничего не решает. Пиксельная мера вердиктом не
является (D-228: пустой серый кадр против раскрашенного макета даёт «80%»), вердикт
— разбор кадра глазом, а адрес ячейки только делает его проверяемым.

  python3 scripts/ui_grid.py reference/12_inventory_parchment_sheet.jpeg \
      --out /tmp/ref.grid.png
  python3 scripts/ui_grid.py frame.png --cell D4 --zoom 3 --out /tmp/cell.D4.png

Кадр для разметки берётся чистым (без сетки); в git пиксели не кладутся (D-185).
"""
from __future__ import annotations

import argparse
import os
import string
import sys

from PIL import Image, ImageDraw, ImageFont

FONT_CANDIDATES = [
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf",
    "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    "C:/Windows/Fonts/arialbd.ttf",
]


def cell_name(col: int, row: int) -> str:
    """(0,0) -> A1; за 26 колонок — числа, сетка крупнее 26×N нам не нужна."""
    return f"{string.ascii_uppercase[col] if col < 26 else col + 1}{row + 1}"


def parse_cell(text: str) -> tuple[int, int]:
    body = text.strip().upper()
    i = 0
    while i < len(body) and body[i].isalpha():
        i += 1
    if not i or i == len(body):
        raise argparse.ArgumentTypeError(f"ячейка выглядит как A1/D10/J3, получено: {text}")
    col = sum((ord(ch) - 64) * 26 ** k for k, ch in enumerate(reversed(body[:i]))) - 1
    return col, int(body[i:]) - 1


def load_font(px: int):
    for path in FONT_CANDIDATES:
        try:
            return ImageFont.truetype(path, px)
        except OSError:
            continue
    try:
        return ImageFont.load_default(size=px)
    except TypeError:  # Pillow < 10.1
        return ImageFont.load_default()


def cell_bbox(size: tuple[int, int], cols: int, rows: int, col: int, row: int):
    w, h = size
    cw, ch = w / cols, h / rows
    x0, y0 = round(col * cw), round(row * ch)
    x1, y1 = round((col + 1) * cw), round((row + 1) * ch)
    return x0, y0, x1 - x0, y1 - y0


def self_check() -> int:
    """Минимальная проверка сетки и меры: `python3 scripts/ui_grid.py --self-check`."""
    assert cell_name(0, 0) == "A1" and cell_name(9, 9) == "J10" and cell_name(26, 0) == "271"
    assert parse_cell("A1") == (0, 0) and parse_cell("d10") == (3, 9) and parse_cell("J3") == (9, 2)
    size = (1920, 1080)
    for cols, rows in [(10, 10), (7, 3), (1, 1)]:
        covered = 0
        for j in range(rows):
            for i in range(cols):
                x, y, w, h = cell_bbox(size, cols, rows, i, j)
                assert 0 <= x and x + w <= size[0] and 0 <= y and y + h <= size[1], (i, j)
                covered += w * h
        # Сумма площадей обязана давать кадр с точностью до округления границ ячеек.
        assert abs(covered - size[0] * size[1]) <= 2 * (size[0] + size[1]), (cols, rows, covered)
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import numpy as np
    import ui_diff
    flat = np.full((64, 64), 77.0, dtype=np.float32)
    assert np.allclose(ui_diff._box_blur(flat, 7), 77.0, atol=1e-3), "_box_blur на константе"
    assert abs(ui_diff.fallback_ssim(flat, flat) - 1.0) < 1e-6, "SSIM identical"
    other = (np.random.default_rng(7).random((64, 64)) * 255).astype(np.float32)
    assert ui_diff.fallback_ssim(flat, other) < 0.05, "SSIM шума и константы обязан быть низким"
    print("[ui_grid] self-check: OK (сетка, адреса ячеек, box blur, SSIM-фолбэк)")
    return 0


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Адресная сетка / кроп ячейки для ux-review.")
    p.add_argument("image", help="чистый кадр или макет")
    p.add_argument("--out", required=True, help="куда писать")
    p.add_argument("--cols", type=int, default=10)
    p.add_argument("--rows", type=int, default=10)
    p.add_argument("--alpha", type=float, default=0.5, help="непрозрачность линий 0..1")
    p.add_argument("--line-width", type=int, default=0, help="толщина линии, 0 = авто")
    p.add_argument("--cell", type=parse_cell, default=None, metavar="A1",
                   help="не размечать, а вырезать эту ячейку")
    p.add_argument("--zoom", type=int, default=1, help="увеличить кроп (nearest), 1 = без изменения")
    p.add_argument("--pad", type=int, default=0, help="расширить кроп на N px в каждую сторону")
    a = p.parse_args()
    if a.cols < 1 or a.rows < 1:
        p.error("--cols/--rows обязаны быть >= 1")
    return a


def crop_cell(img: Image.Image, a: argparse.Namespace) -> Image.Image:
    col, row = a.cell
    if not (0 <= col < a.cols and 0 <= row < a.rows):
        raise SystemExit(f"ячейка вне сетки {a.cols}×{a.rows}: col={col + 1} row={row + 1}")
    x, y, w, h = cell_bbox(img.size, a.cols, a.rows, col, row)
    x0, y0 = max(0, x - a.pad), max(0, y - a.pad)
    x1, y1 = min(img.width, x + w + a.pad), min(img.height, y + h + a.pad)
    out = img.crop((x0, y0, x1, y1))
    if a.zoom > 1:
        out = out.resize((out.width * a.zoom, out.height * a.zoom), Image.NEAREST)
    return out


def draw_grid(img: Image.Image, a: argparse.Namespace) -> Image.Image:
    w, h = img.size
    lw = a.line_width or max(1, round(min(w, h) / 700))
    font = load_font(max(11, round(h / a.rows * 0.22)))
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    line = (255, 60, 60, int(255 * a.alpha))
    for i in range(1, a.cols):
        x = round(i * w / a.cols)
        d.line([(x, 0), (x, h)], fill=line, width=lw)
    for j in range(1, a.rows):
        y = round(j * h / a.rows)
        d.line([(0, y), (w, y)], fill=line, width=lw)
    for j in range(a.rows):
        for i in range(a.cols):
            name = cell_name(i, j)
            x, y, cw, ch = cell_bbox(img.size, a.cols, a.rows, i, j)
            tx, ty = x + 2 * lw + 2, y + 2 * lw + 1
            tw = d.textlength(name, font=font)
            th = font.size if hasattr(font, "size") else 12
            d.rectangle([tx - 1, ty - 1, tx + tw + 3, ty + th + 2], fill=(20, 0, 0, 190))
            d.text((tx + 1, ty), name, font=font, fill=(255, 240, 120, 255))
    out = img.convert("RGBA")
    out.alpha_composite(overlay)
    return out.convert("RGB")


def main() -> int:
    if "--self-check" in sys.argv:
        return self_check()
    a = parse_args()
    img = Image.open(a.image).convert("RGB")
    out = crop_cell(img, a) if a.cell else draw_grid(img, a)
    out.save(a.out)
    if a.cell:
        name = cell_name(a.cell[0], a.cell[1])
        print(f"[ui_grid] ячейка {name} ({a.cols}×{a.rows}) из {img.size[0]}×{img.size[1]}"
              f" → {out.size[0]}×{out.size[1]}{f' ×{a.zoom}' if a.zoom > 1 else ''} -> {a.out}")
    else:
        print(f"[ui_grid] сетка {a.cols}×{a.rows} на {img.size[0]}×{img.size[1]} -> {a.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

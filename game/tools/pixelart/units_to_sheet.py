#!/usr/bin/env python3
"""Сборка кадров-юнитов обратно в листы по 12 (3 ряда × 4 колонки).

Обратная сторона `sheet_to_units.py`: кадры берутся рекурсивно, по одному
масштабу на лист, белый фон, общая базовая линия. По умолчанию лист повторяет
геометрию исходного корпуса (`set-*.png` — ячейка 332×587, юнит 75% ячейки),
в натуральную величину. Лист, собранный здесь, разрежется обратно:
`sheet_to_units.py --dry-run` на нём даёт те же 12 принятых ячеек.

Кадры группируются по подкаталогу (тегу стиля) — один лист = один стиль;
`--mixed` собирает общую кучу. Неполный последний лист досказывается белыми
ячейками: резак отбрасывает пустые сам.

Использование:
    units_to_sheet.py --in ~/Downloads/_make_for_lora/units_tight
    units_to_sheet.py --in <папка> --out <папка> --per 12 --mixed --cell 664x1174
"""
from __future__ import annotations

import argparse
from collections import defaultdict
from pathlib import Path

from PIL import Image

from sheet_to_units import sheet_files

ROWS, COLS = 3, 4
FRAC = 0.95             # юнит во долю ячейки: поле нужно, но `ink` резака
#                         # = тёмные пиксели / ПЛОЩАДЬ ЛИСТА, поэтому широкое
#                         # поле роняет светлые кадры под порог 0.02


def group_by_tag(paths: list[Path], root: Path, mixed: bool) -> dict[str, list[Path]]:
    """Кадры по группам: тег = имя подкаталога, либо одна общая куча."""
    groups: dict[str, list[Path]] = defaultdict(list)
    for p in paths:
        tag = 'all' if mixed else (p.parent.name if p.parent != root else 'all')
        groups[tag].append(p)
    return {k: sorted(v) for k, v in sorted(groups.items())}


def sizes(paths: list[Path]) -> list[tuple[int, int]]:
    out = []
    for p in paths:
        with Image.open(p) as im:
            out.append(im.size)
    return out


def make_sheet(paths: list[Path], dims: list[tuple[int, int]], frac: float) -> Image.Image:
    """Кадры ставятся пиксель в пиксель (без ресайза): резак морфологически
    закрывает силуэт ядром в 5 px и меряет севено долей от площади листа —
    на увеличенном листе те же пиксели рвутся на лоскуты и ячейки отбрасываются.
    Размер ячейки поэтому берётся из самого крупного кадра, а не наоборот."""
    cw = round(max(w for w, _ in dims) / frac)
    ch = round(max(h for _, h in dims) / frac)
    baseline = round((ch + max(h for _, h in dims)) / 2)   # общая базовая линия
    sheet = Image.new('RGB', (COLS * cw, ROWS * ch), 'white')
    for i, (p, (w, h)) in enumerate(zip(paths, dims)):
        with Image.open(p) as im:
            r = im.convert('RGB')
        x, y = (i % COLS) * cw, (i // COLS) * ch
        sheet.paste(r, (x + round((cw - w) / 2), y + baseline - h))
    return sheet


def main(argv=None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--in', dest='src', type=Path, required=True)
    ap.add_argument('--out', type=Path, default=None)
    ap.add_argument('--per', type=int, default=ROWS * COLS)
    ap.add_argument('--frac', type=float, default=FRAC)
    ap.add_argument('--mixed', action='store_true', help='не резать листы по тегам')
    a = ap.parse_args(argv)
    assert a.per <= ROWS * COLS, f'лист вмещает {ROWS * COLS} кадров'

    out = a.out or a.src.parent / 'sheets12'
    out.mkdir(parents=True, exist_ok=True)
    files = sheet_files(a.src)
    made = total = 0
    for tag, paths in group_by_tag(files, Path(a.src), a.mixed).items():
        for n, start in enumerate(range(0, len(paths), a.per), 1):
            chunk = paths[start:start + a.per]
            name = f'sheet_{tag}_{n:02d}.png'
            make_sheet(chunk, sizes(chunk), a.frac).save(out / name)
            made += 1
            total += len(chunk)
            print(f'{name}: {len(chunk)}/{a.per} кадров')
    print(f'ИТОГО {made} листов, {total} кадров из {len(files)} → {out}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

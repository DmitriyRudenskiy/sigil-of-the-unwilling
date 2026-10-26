#!/usr/bin/env python3
"""Сборка кадров-юнитов обратно в листы по 12 (3 ряда × 4 колонки).

Обратная сторона `sheet_to_units.py`: кадры берутся рекурсивно, ставятся
пиксель в пиксель (без ресайза) на белый фон, в ряду — на общую базовую линию.

Состав листа — по умолчанию **смешанный и пропорциональный**: подкаталог =
тег стиля, и в каждый лист берётся 12 кадров в долях остатка корпуса (при
корпусе 304/232/138/59 это 5+4+2+1). Внутри листа кадры одного стиля не
стоят вплотную по горизонтали и вертикали — раскладкой заведует `arrange()`,
сетка 3×4 с соседями «вкрест» это выдерживает при доле стиля ≤ 6 из 12.
`--by-tag` возвращает прежний режим: один лист = один стиль.

Неполный последний лист досказывается белыми ячейками: резак отбрасывает
пустые сам.

Использование:
    units_to_sheet.py --in ~/Downloads/_make_for_lora/units_tight
    units_to_sheet.py --in <папка> --out <папка> --by-tag --per 12
"""
from __future__ import annotations

import argparse
import itertools
from collections import defaultdict
from pathlib import Path

import numpy as np
from PIL import Image

from sheet_to_units import screen_cell, sheet_files

ROWS, COLS = 3, 4
FRAC = 0.95             # кадр во долю ячейки: это запас на склейку — слипшиеся
#                         # кадры резак считает одной ячейкой и теряет оба


def by_tag(paths: list[Path], root: Path) -> dict[str, list[Path]]:
    """Кадры по тегам: тег = имя подкаталога (стили лежат в подпапках)."""
    groups: dict[str, list[Path]] = defaultdict(list)
    for p in paths:
        groups[p.parent.name if p.parent != root else 'all'].append(p)
    return {k: sorted(v) for k, v in sorted(groups.items())}


def quota(remaining: dict[str, int], total: int) -> dict[str, int]:
    """Сколько какого тега положить в следующий лист: доли остатка корпуса,
    округление по методу наибольшего остатка (сумма ровно `total`)."""
    pool = sum(remaining.values())
    if pool <= total:
        return dict(remaining)
    share = {t: total * n / pool for t, n in remaining.items()}
    out = {t: int(v) for t, v in share.items()}
    left = total - sum(out.values())
    for t, _ in sorted(share.items(), key=lambda kv: (-(kv[1] - out[kv[0]]), kv[0])):
        if left <= 0:
            break
        out[t] += 1
        left -= 1
    return {t: n for t, n in out.items() if n}


def neighbours(i: int) -> list[int]:
    r, c = divmod(i, COLS)
    return [j for j in ((i - COLS if r else -1), (i + COLS if r < ROWS - 1 else -1),
                        (i - 1 if c else -1), (i + 1 if c < COLS - 1 else -1)) if j >= 0]


def arrange(counts: dict[str, int]) -> list[str | None]:
    """Порядок тегов в 12 ячейках: соседям по горизонтали/вертикали — разные
    теги. Перебор с возвратом: 12 ячеек и 4 тега, ветвление гасится правилом
    «тега нет у соседа» и порядком «сначала самый многочисленный»."""
    cells: list[str | None] = [None] * (ROWS * COLS)

    def bt(left: dict[str, int]) -> bool:
        if not any(left.values()):
            return True
        i = cells.index(None)
        busy = {cells[j] for j in neighbours(i) if cells[j]}
        for t in sorted(left, key=lambda t: (-left[t], t)):
            if left[t] and t not in busy:
                cells[i] = t
                left[t] -= 1
                if bt(left):
                    return True
                left[t] += 1
                cells[i] = None
        return False

    return cells if bt(dict(counts)) else []


def split_evenly(counts: dict[str, int], k: int) -> list[dict[str, int]]:
    """Раздать кадры по k листам поровну, каждый тег — своим остатком."""
    out = [dict() for _ in range(k)]
    for t, n in sorted(counts.items()):
        base, rem = divmod(n, k)
        for i in range(k):
            out[i][t] = base + (1 if i < rem else 0)
    return [{t: n for t, n in d.items() if n} for d in out]


def plan(left: dict[str, int], per: int) -> list[dict[str, int]]:
    """Состав каждого листа: доли остатка корпуса, хвост не бросает огрызок."""
    qs: list[dict[str, int]] = []
    while sum(left.values()):
        q = quota(left, per)
        for t, n in q.items():
            left[t] -= n
        qs.append(q)
    if len(qs) > 1 and sum(qs[-1].values()) < per // 3:
        tail = defaultdict(int)
        for q in qs[-2:]:
            for t, n in q.items():
                tail[t] += n
        qs = qs[:-2] + split_evenly(tail, 2)
    return qs


def layout(tags: dict[str, list[Path]], per: int) -> list[list[Path]]:
    """Очередь кадров по тегам → листы. Состав листа считает plan(),
    позиции — arrange()."""
    queues = {t: list(v) for t, v in tags.items()}
    return [[queues[t].pop(0) for t in arrange(q) or [t for t, n in sorted(q.items()) for _ in range(n)] if t]
            for q in plan({t: len(v) for t, v in queues.items()}, per)]


def make_sheet(paths: list[Path], dims: list[tuple[int, int]], frac: float) -> Image.Image:
    """Кадры ставятся пиксель в пиксель (без ресайза): резак закрывает силуэт
    ядром в 5 px, на раздутом кадре он рвётся на лоскуты и ячейка падает по
    числу связных частей. Колонки и ряды равны самому крупному кадру в них,
    а не самому крупному в листе: лишнее поле только скрашивает лист."""
    colw = [round(max((w for i, (w, _) in enumerate(dims) if i % COLS == c), default=0) / frac)
            for c in range(COLS)][:1 + max(i % COLS for i in range(len(dims)))]
    rowh = [round(max((h for i, (_, h) in enumerate(dims) if i // COLS == r), default=0) / frac)
            for r in range(ROWS)][:1 + max(i // COLS for i in range(len(dims)))]
    xs = [0] + list(itertools.accumulate(colw))
    ys = [0] + list(itertools.accumulate(rowh))
    sheet = Image.new('RGB', (xs[-1], ys[-1]), 'white')
    for i, (p, (w, h)) in enumerate(zip(paths, dims)):
        r, c = divmod(i, COLS)
        with Image.open(p) as im:
            sheet.paste(im.convert('RGB'),
                        (xs[c] + (colw[c] - w) // 2, ys[r] + (rowh[r] + h) // 2 - h))
    return sheet


def sizes(paths: list[Path]) -> list[tuple[int, int]]:
    out = []
    for p in paths:
        with Image.open(p) as im:
            out.append(im.size)
    return out


def _selftest() -> int:
    """Минимальная проверка арифметики состава и раскладки (без картинок)."""
    counts = {'1_cartoon': 304, '2_comic_fx': 232, '3_warm_pastel': 138, '4_anime_chibi': 59}
    q = quota(counts, 12)
    assert sum(q.values()) == 12 and q == {'1_cartoon': 5, '2_comic_fx': 4,
                                           '3_warm_pastel': 2, '4_anime_chibi': 1}, q
    for _ in range(50):                       # доли меняются по мере выдачи пула
        left = dict(counts)
        while sum(left.values()):
            take = quota(left, 12)
            cells = arrange(take)
            assert cells, take                # раскладка без соседних одинаковых
            for i, c in enumerate(cells):
                if not c:
                    continue
                assert all(cells[j] != c for j in neighbours(i)), (cells, i)
            for t, n in take.items():
                left[t] = max(0, left[t] - n)
    assert quota({'a': 3, 'b': 1}, 12) == {'a': 3, 'b': 1}
    assert arrange({'a': 7, 'b': 5}) == []    # 7 из 12 впритык не развести
    # отбор не зависит от того, насколько лист больше кадра (иначе собранный
    # лист на 20% шире ронял светлые костюмы по ink, не изменившись)
    sprite = np.zeros((120, 90), bool)
    sprite[10:110, 15:75] = True
    sprite[40:70, 30:60] = False
    for pad in (0, 400, 900):
        canvas = np.zeros((120 + 2 * pad, 90 + 2 * pad), bool)
        canvas[pad:pad + 120, pad:pad + 90] = sprite
        ok, reasons = screen_cell(canvas)
        assert ok, (pad, reasons)
    print('selftest OK')
    return 0


def main(argv=None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--in', dest='src', type=Path)
    ap.add_argument('--selftest', action='store_true')
    ap.add_argument('--out', type=Path, default=None)
    ap.add_argument('--per', type=int, default=ROWS * COLS)
    ap.add_argument('--by-tag', action='store_true', help='один лист = один стиль')
    ap.add_argument('--frac', type=float, default=FRAC)
    a = ap.parse_args(argv)
    if a.selftest:
        return _selftest()
    assert a.src, 'нужен --in'
    assert a.per <= ROWS * COLS, f'лист вмещает {ROWS * COLS} кадров'

    files = sheet_files(a.src)
    groups = by_tag(files, Path(a.src))
    if a.by_tag:
        sheets, names = [], []
        for t, paths in groups.items():
            for n, i in enumerate(range(0, len(paths), a.per), 1):
                sheets.append(paths[i:i + a.per])
                names.append(f'sheet_{t}_{n:02d}')
    else:
        sheets = layout(groups, a.per)
        names = [f'sheet_mix_{n:02d}' for n in range(1, len(sheets) + 1)]

    out = a.out or a.src.parent / 'sheets12'
    out.mkdir(parents=True, exist_ok=True)
    for name, chunk in zip(names, sheets):
        make_sheet(chunk, sizes(chunk), a.frac).save(out / f'{name}.png')
    made = sum(len(s) for s in sheets)
    print(f'{len(sheets)} листов, {made} кадров из {len(files)} → {out}')
    for name, chunk in list(zip(names, sheets))[:3]:
        mix = defaultdict(int)
        for p in chunk:
            mix[p.parent.name] += 1
        print(f'  {name}: ' + ' '.join(f'{t}={n}' for t, n in sorted(mix.items())))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

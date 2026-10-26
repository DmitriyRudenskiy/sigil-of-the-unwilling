#!/usr/bin/env python3
"""Разбор листа юнитов (4×3 персонажа на белом фоне) на отдельные спрайты.

Канвас ячейки = 1024×1024, юнит вписан в 768 (75% холста), остальное — поле.
Порядок: бинаризация по яркости → сёмена (крупные связные компоненты) →
сетка по кластерам центроидов → числовой отбор ячейки → кэш → кроп.

Отобранные кадры складываются в кэш (по умолчанию `_unit_cache/` рядом с
листом) под именем `<sheet>_<row><col>_<md5[:8]>.png`: имя производно от
содержимого, поэтому один и тот же юнит, попавший в два листа, кладётся один
раз. Соседний `.json` хранит хэш листа, md5 кадра, md5 всего юнита (кадр +
поле) и координаты в листе.

Использование:
    sheet_to_units.py --dry-run лист.png          # вердикт по ячейкам
    sheet_to_units.py --crop лист.png --out dir/  # вырезать отобранное
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import math
import sys
import time
from pathlib import Path

import numpy as np
import cv2
from PIL import Image

CANVAS = 1024
UNIT_FRACTION = 0.75
UNIT_SIDE = int(CANVAS * UNIT_FRACTION)  # 768

# Пороги числового отбора. Всё, что вне диапазона, — кандидаты в мусор или в
# склейку двух юнитов; ни то ни другое в датасет не идёт.
MIN_INK = 0.02          # доля тёмных пикселей в ячейке
MIN_FILL = 0.16         # заполнение минимального прямоугольника
MIN_ASPECT = 0.35       # шир./выс. стоящего персонажа
MAX_ASPECT = 2.6
MIN_SOLIDITY = 0.30     # площадь / площадь выпуклой оболочки
MIN_COMPONENTS = 1
MAX_COMPONENTS = 6
MIN_COMPONENT_SHARE = 0.05  # компонент меньше — деталь, а не отдельный юнит

MIN_SEED_AREA = 0.012   # севено меньше 1.2% кадра листа — не персонаж
DARK_THRESHOLD = 80     # 255 − min(RGB) выше порога → пиксель принадлежит юниту


# ------------------------------------------------------------------ загрузка

def load_rgb(path: str | Path):
    """Читает PNG как RGB float32 0..255. Возвращает (rgb, path)."""
    path = Path(path)
    return np.asarray(Image.open(path).convert('RGB'), dtype=np.float32), path


def sheet_files(source) -> list[Path]:
    """Список листов из каталога (рекурсивно), служебные — исключены."""
    root = Path(source) if not isinstance(source, dict) else Path(source['root'])
    skip = set(source.get('skip', ())) if isinstance(source, dict) else set()
    out = []
    for path in sorted(root.rglob('*.png')):
        if path.parent == root and path.stem in skip:
            continue
        out.append(path)
    return out


def md5_file(path: str | Path) -> str:
    digest = hashlib.md5()
    with open(path, 'rb') as handle:
        for block in iter(lambda: handle.read(1 << 20), b''):
            digest.update(block)
    return digest.hexdigest()


# ------------------------------------------------------- сёмена и сетка ячеек

def alpha_of(rgb) -> np.ndarray:
    """Непрозрачность юнита по яркости: фон светлый, персонаж тёмный."""
    return (255.0 - rgb.min(axis=2)) > DARK_THRESHOLD


def seeds_of(alpha: np.ndarray) -> list[np.ndarray]:
    """Крупные связные компоненты листа — по одному на персонажа (обычно)."""
    mask = cv2.morphologyEx(
        alpha.astype(np.uint8), cv2.MORPH_CLOSE,
        cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5)))
    count, labels = cv2.connectedComponents(mask, 8)[:2]
    floor = MIN_SEED_AREA * alpha.size
    seeds = []
    for i in range(1, count):
        if (labels == i).sum() > floor:
            seeds.extend(split_wide(labels == i))
    return seeds


def split_wide(mask: np.ndarray, max_aspect: float = 1.15) -> list[np.ndarray]:
    """Разрезать севено, у которого силуэт шире, чем персонаж: по узкому месту.

    Персонажи выше, чем широки, поэтому компонент с w/h > max_aspect — это
    соприкоснувшиеся соседи. Режем по колонке с минимальным числом пикселей.
    """
    ys, xs = np.nonzero(mask)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    h, w = y1 - y0, x1 - x0
    if w <= max_aspect * h:
        return [mask]
    column = mask[y0:y1, x0:x1].sum(axis=0)
    inner = column[1:-1]
    if not inner.any():
        return [mask]
    cut = x0 + 1 + int(inner.argmin())
    left, right = mask.copy(), mask.copy()
    left[:, cut:] = False
    right[:, :cut] = False
    return [part for half in (left, right) for part in split_wide(half, max_aspect)
            if half.sum() > MIN_SEED_AREA * mask.size / 4]


def _cluster(values, threshold):
    """Одномерная группировка отсортированных значений по зазору."""
    values = sorted(values)
    groups, current = [], [values[0]]
    for value in values[1:]:
        if value - current[-1] <= threshold:
            current.append(value)
        else:
            groups.append(current)
            current = [value]
    groups.append(current)
    return [float(np.mean(g)) for g in groups]


def grid_cells(seed_masks):
    """Разложить сёмена по ячейкам сетки: кластеризация центроидов по X/Y.

    Возвращает {(row, col): mask}, (rows, cols). Пустой ячейки в словаре нет.
    """
    if not seed_masks:
        return {}, 0, 0
    h, w = seed_masks[0].shape
    ys = [np.nonzero(m)[0] for m in seed_masks]
    xs = [np.nonzero(m)[1] for m in seed_masks]
    cy = [float(y.mean()) for y in ys]
    cx = [float(x.mean()) for x in xs]
    row_c = _cluster(cy, 0.4 * max(1, int(np.median([np.ptp(y) for y in ys]))))
    col_c = _cluster(cx, 0.6 * max(1, int(np.median([np.ptp(x) for x in xs]))))
    cells = {}
    for m, y, x in zip(seed_masks, cy, cx):
        key = (int(np.argmin(np.abs(np.array(row_c) - y))),
               int(np.argmin(np.abs(np.array(col_c) - x))))
        cells[key] = m if key not in cells else cells[key] | m
    return cells, len(row_c), len(col_c)


def cell_bbox(mask: np.ndarray, pad: int = 8):
    """Минимальный прямоугольник ячейки с полями (в координатах листа)."""
    ys, xs = np.nonzero(mask)
    if not len(ys):
        return None
    h, w = mask.shape
    return (max(0, int(ys.min()) - pad), min(h, int(ys.max()) + 1 + pad),
            max(0, int(xs.min()) - pad), min(w, int(xs.max()) + 1 + pad))


# ----------------------------------------------------------- метрики и отбор

def components_of(mask: np.ndarray) -> list[tuple[int, tuple]]:
    """Связные компоненты кадра: (площадь, (y0, x0, y1, x1)), крупные первыми."""
    count, labels = cv2.connectedComponents(mask.astype(np.uint8), 8)[:2]
    out = []
    for i in range(1, count):
        comp = labels == i
        area = int(comp.sum())
        if not area:
            continue
        ys, xs = np.nonzero(comp)
        out.append((area, (int(ys.min()), int(xs.min()),
                           int(ys.max()) + 1, int(xs.max()) + 1)))
    return sorted(out, reverse=True)


def cell_metrics(mask: np.ndarray) -> dict:
    """Числовой портрет ячейки: всё, по чему она проходит или не проходит отбор."""
    ys, xs = np.nonzero(mask)
    if not len(ys):
        return {'ink': 0.0, 'empty': True}
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    crop = mask[y0:y1, x0:x1]
    h, w = crop.shape
    area = int(crop.sum())
    contours, _ = cv2.findContours(crop.astype(np.uint8), cv2.RETR_EXTERNAL,
                                   cv2.CHAIN_APPROX_SIMPLE)
    hull = cv2.contourArea(cv2.convexHull(np.vstack(contours))) if contours else 0.0
    comps = components_of(crop)
    big = [a for a, _ in comps if a >= MIN_COMPONENT_SHARE * area]
    return {
        'empty': False,
        'bbox': [int(y0), int(y1), int(x0), int(x1)],
        'ink': area / mask.size,
        'fill': area / (h * w),
        'aspect': w / h,
        'solidity': area / hull if hull else 0.0,
        'components': len(big),
        'parts': len(comps),
        'largest_share': comps[0][0] / area if comps else 0.0,
        'second_share': comps[1][0] / area if len(comps) > 1 else 0.0,
    }


def screen_cell(mask: np.ndarray) -> tuple[bool, list[str]]:
    """Отобрать ячейку по числам. Возвращает (принять, причины отказа)."""
    m = cell_metrics(mask)
    if m.get('empty'):
        return False, ['empty']
    reasons = []
    if m['ink'] < MIN_INK:
        reasons.append(f"ink={m['ink']:.4f}<{MIN_INK}")
    if m['fill'] < MIN_FILL:
        reasons.append(f"fill={m['fill']:.3f}<{MIN_FILL}")
    if not MIN_ASPECT <= m['aspect'] <= MAX_ASPECT:
        reasons.append(f"aspect={m['aspect']:.2f} вне [{MIN_ASPECT}, {MAX_ASPECT}]")
    if m['solidity'] < MIN_SOLIDITY:
        reasons.append(f"solidity={m['solidity']:.2f}<{MIN_SOLIDITY}")
    if not MIN_COMPONENTS <= m['components'] <= MAX_COMPONENTS:
        reasons.append(f"components={m['components']} вне "
                       f"[{MIN_COMPONENTS}, {MAX_COMPONENTS}]")
    if m['largest_share'] < 1 - MIN_COMPONENT_SHARE:
        reasons.append(f"largest={m['largest_share']:.2f} — кадр не один юнит")
    return not reasons, reasons


# ------------------------------------------------------------------ кэш кадров

def frame_of(mask: np.ndarray, rgb: np.ndarray, bbox) -> np.ndarray:
    """Канвас 1024×1024 RGBA: юнит из bbox вписан в 768, вокруг — поле."""
    y0, y1, x0, x1 = bbox
    scale = UNIT_SIDE / max(y1 - y0, x1 - x0)
    unit = np.dstack([rgb[y0:y1, x0:x1], mask[y0:y1, x0:x1] * 255.0])
    resized = cv2.resize(unit.astype(np.uint8),
                         (max(1, round((x1 - x0) * scale)),
                          max(1, round((y1 - y0) * scale))),
                         interpolation=cv2.INTER_AREA)
    canvas = np.zeros((CANVAS, CANVAS, 4), np.uint8)  # поле прозрачное RGBA(0,0,0,0)
    oy = (CANVAS - resized.shape[0]) // 2
    ox = (CANVAS - resized.shape[1]) // 2
    canvas[oy:oy + resized.shape[0], ox:ox + resized.shape[1]] = resized
    return canvas


def cache_index(cache_dir: Path) -> dict[str, list[Path]]:
    """md5 кадра → файлы кэша (по содержимому, не по имени)."""
    index: dict[str, list[Path]] = {}
    if cache_dir.is_dir():
        for path in cache_dir.glob('*.png'):
            index.setdefault(md5_file(path), []).append(path)
    return index


def cache_put(cache_dir: Path, frame: np.ndarray, *, sheet: str, cell,
              md5_frame: str, md5_unit: str, source_bbox) -> tuple[Path, bool]:
    """Положить кадр в кэш. Возвращает (путь, newly_written)."""
    cache_dir.mkdir(parents=True, exist_ok=True)
    name = f'{Path(sheet).stem}_{cell[0]}{cell[1]}_{md5_frame[:8]}'
    png = cache_dir / f'{name}.png'
    newly = not png.exists()
    if newly:
        Image.fromarray(frame, 'RGBA').save(png)
        (cache_dir / f'{name}.json').write_text(json.dumps({
            'sheet': str(sheet), 'cell': list(cell), 'md5_frame': md5_frame,
            'md5_unit': md5_unit, 'source_bbox': list(source_bbox),
            'canvas': [CANVAS, CANVAS], 'unit_side': UNIT_SIDE,
        }, ensure_ascii=False, indent=1) + '\n', encoding='utf-8')
    return png, newly


# ------------------------------------------------------------------ верхний уровень

def analyse_sheet(path: str | Path) -> dict:
    """Лист → сетка ячеек + числовой отбор каждой. Ничего не пишет."""
    started = time.perf_counter()
    rgb, path = load_rgb(path)
    alpha = alpha_of(rgb)
    cells, rows, cols = grid_cells(seeds_of(alpha))
    out = {}
    for key, mask in sorted(cells.items()):
        bbox = cell_bbox(mask)
        metrics = cell_metrics(mask[bbox[0]:bbox[1], bbox[2]:bbox[3]]) \
            if bbox else {'empty': True}
        accepted, reasons = screen_cell(mask)
        out[key] = {'bbox': bbox, 'metrics': metrics,
                    'accepted': accepted, 'reasons': reasons}
    return {'path': str(path), 'md5': md5_file(path), 'grid': (rows, cols),
            'cells': out, 'seconds': time.perf_counter() - started}


def crop_sheet(path: str | Path, out_dir: str | Path,
               cache_dir: str | Path | None = None) -> dict:
    """Вырезать принятые отбором ячейки в out_dir/<лист>/; оригиналы не трогаются."""
    started = time.perf_counter()
    rgb, path = load_rgb(path)
    alpha = alpha_of(rgb)
    cells, rows, cols = grid_cells(seeds_of(alpha))
    out_dir = Path(out_dir) / path.stem
    out_dir.mkdir(parents=True, exist_ok=True)
    cache_dir = Path(cache_dir) if cache_dir else path.parent / '_unit_cache'
    written, skipped, duplicate = [], [], 0
    for key, mask in sorted(cells.items()):
        accepted, reasons = screen_cell(mask)
        bbox = cell_bbox(mask)
        if not accepted or bbox is None:
            skipped.append({'cell': key, 'reasons': reasons})
            continue
        frame = frame_of(mask, rgb, bbox)
        unit_md5 = hashlib.md5(frame.tobytes()).hexdigest()
        png, newly = cache_put(cache_dir, frame, sheet=path.name, cell=key,
                               md5_frame=unit_md5, md5_unit=unit_md5,
                               source_bbox=bbox)
        if not (out_dir / png.name).exists():
            shutil.copyfile(png, out_dir / png.name)
        if newly:
            written.append(png.name)
        else:
            duplicate += 1
    return {'path': str(path), 'grid': (rows, cols), 'written': written,
            'duplicate': duplicate, 'skipped': skipped,
            'seconds': time.perf_counter() - started}


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('sheets', nargs='+', type=Path)
    ap.add_argument('--dry-run', action='store_true', help='только вердикт по ячейкам')
    ap.add_argument('--crop', action='store_true', help='вырезать отобранное')
    ap.add_argument('--out', type=Path, default=None)
    ap.add_argument('--cache', type=Path, default=None)
    args = ap.parse_args(argv)
    if not (args.dry_run or args.crop):
        ap.error('нужен --dry-run и/или --crop')
    for sheet in args.sheets:
        report = analyse_sheet(sheet)
        rows, cols = report['grid']
        taken = sum(1 for c in report['cells'].values() if c['accepted'])
        print(f"{report['path']}: сетка {rows}×{cols}, принято {taken}/"
              f"{len(report['cells'])} за {report['seconds']:.1f} c")
        for key, cell in report['cells'].items():
            flag = 'accept' if cell['accepted'] else 'reject'
            print(f"  ({key[0]},{key[1]}) {flag} {'; '.join(cell['reasons'])}")
        if args.crop:
            result = crop_sheet(sheet, args.out or sheet.parent / 'units',
                                cache_dir=args.cache)
            print(f"  вырезано {len(result['written'])}, "
                  f"дубликатов {result['duplicate']}")
    return 0


if __name__ == '__main__':
    sys.exit(main())

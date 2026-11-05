#!/usr/bin/env python3
"""Лист тайлов земли из кадра AI-комплекта: нарезка по решётке реестра.

Донор — кадр из `game/data/config/scene_slices.json` с принятой геометрией сот
(`cell_fit.accepted`: T-339). Каждая клетка решётки внутри игровой области
становится тайлом `tile × tile`, классифицируется по тону и складывается в
**раскладку существующего атласа** (`--layout=…world_map_atlas.json`): сетку, id и
роли клеток диктует манифест атласа, из кадра приходит только поверхность. Рантайм
при этом не меняется ни на строку: тот же `TileAtlas`, а лист поднимает
`MAP_KIT=1` (`TileAtlas.sheet_path()`, T-341); без `--layout` получается
собственная упаковка кадра — только для глазного вердикта, в игру она не идёт.

Координаты решётки берутся из **реестра**, а не пересчитываются здесь: один
источник геометрии с приёмкой T-339, иначе лист разъедется с числом, по которому
кадр был принят. Ориентацию (сдвиг ≤ 3°) резка игнорирует — для вырезов шага
решётки это доли пикселя на границе тайла.

Вырез — квадрат стороной по **большему** шагу решётки: aspect кадра
сохраняется (тайл не тянется), а соседние тайлы перекрываются по вертикали там,
где шаг меньше (щелей не бывает, перекрывание — плата за прямоугольный тайл).

Запуск:
  python3 scripts/slice_kit_atlas.py --self-test
  python3 scripts/slice_kit_atlas.py --sha <префикс sha256 донора> \\
      [--kit /Users/user/Downloads/battlefield] \\
      [--out-prefix game/assets/tiles/world_map_kit] [--tile 82] [--max-tiles 256]
"""

from __future__ import annotations

import argparse
import hashlib
import json
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image

VERSION = 1
QUALITY = 80
REGISTRY = Path("game/data/config/scene_slices.json")
KIT_DEFAULT = Path.home() / "Downloads/battlefield"
## Тон тайла — имена биомов атласа (`TileAtlas.BIOME_NAMES`), иначе рантайм
## будет искать «green» там, где рендер знает «grass».
TONES = ("snow", "water", "sand", "rock", "swamp", "mud", "grass")

## Биомы раскладки, у которых в кадре-доноре нет своего тона, но есть близкий.
## «Дорога» атласа — утоптанное полотно (её же рисует декаль покрытия в
## `MapRenderer.paint_roads`), а глинистая тропа в доноре есть; без подмены
## дорожные клетки и декаль легли бы травой. Песок подменить нечем — он остаётся
## травой и ездит в отчёте как пробел (T-341).
SUBSTITUTE = {"road": "mud"}


def lab(a: np.ndarray) -> np.ndarray:
    """sRGB → CIE Lab (те же константы, что у приёмки кадров)."""
    c = np.clip(a.astype(np.float64) / 255.0, 0.0, 1.0)
    m = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]])
    xyz = c @ m.T
    xyz /= np.array([0.95047, 1.0, 1.08883])
    f = np.where(
        xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16.0 / 116.0
    )
    return np.stack(
        [116.0 * f[..., 1] - 16.0, 500.0 * (f[..., 0] - f[..., 1]), 200.0 * (f[..., 1] - f[..., 2])],
        axis=-1,
    )


def tone_of(rgb: np.ndarray) -> str:
    """Тон клетки по среднему Lab. Порядок проверок и есть правило.

    Пороги сняты по осям самих тонов (замер опорных цветов, Lab):
    вода `b ≈ −26…−30`; зелень `a ≈ −13…−15` (болото — та же зелень, но `b ≈ 2`
    против `b ≈ 20` у травы); песок `L > 78` при `b > 15`; серый — хроматика
    `|a|, |b| < 8` при любой яркости; остальное глина/трава. Всё неопределимое
    остаётся травой — тот же дефолт, что у самого частого биома.
    """
    L, a, b = (float(v) for v in lab(np.asarray(rgb, dtype=float)).reshape(-1, 3).mean(axis=0))
    if L > 92 and abs(a) < 6 and b > -8:
        return "snow"
    if b < -8:
        return "water"
    if a < -8:
        return "grass" if b > 10 else "swamp"
    if b > 15 and L > 78:
        return "sand"
    if abs(a) < 5 and abs(b) < 8:
        return "rock"
    if b > 8:
        return "mud"
    return "grass"


def strip_lines(rgb: np.ndarray, radius: int = 4, threshold: float = 18.0) -> np.ndarray:
    """Снять тёмную сетку, нарисованную поверх кадра.

    Кадры комплекта содержат контуры сот (вердикт D-310: линии долой — иначе в
    игре получается двойная сетка, идущая не по клеткам тайлмапа). Чернила
    темнее ткани вокруг, поэтому «пиксель заметно темнее локальной медианы» —
    это линия, а медиана — её заполнение.
    """
    from scipy.ndimage import median_filter

    # По осям картинки, но НЕ по каналам: общий фильтр на три оси смешивает RGB
    # и обесцвечивает заполнение.
    med = median_filter(rgb, size=(2 * radius + 1, 2 * radius + 1, 1), mode="reflect")
    ink = rgb.astype(np.int16).mean(axis=2) < med.astype(np.int16).mean(axis=2) - threshold
    return np.where(ink[..., None], med, rgb).astype(np.uint8)


def cells_of(fit: dict) -> list[dict]:
    """Клетки решётки реестра внутри области замера (`roi`), центр — не у кромки.

    Область — прямоугольник замера, а не многоугольник кадра: резать за ней
    нечего, а приёмка решётки считалась ровно на ней.
    """
    ox, oy = (float(v) for v in fit["origin"])
    cs, rs = float(fit["col_step_px"]), float(fit["row_step_px"])
    side = max(cs, rs)
    x0, y0, x1, y1 = (float(v) for v in fit["roi"])
    out: list[dict] = []
    r = 0
    while oy + r * rs + rs / 2.0 <= y1:
        q = 0
        while ox + q * cs + cs / 2.0 <= x1:
            cx, cy = ox + q * cs + cs / 2.0, oy + r * rs + rs / 2.0
            if x0 <= cx <= x1 and y0 <= cy <= y1:
                out.append({"q": q, "r": r, "center": [round(cx, 1), round(cy, 1)]})
            q += 1
        r += 1
    return out


def slice_donor(
    frame: Path, fit: dict, tile: int, max_tiles: int, digest: str, rgb: np.ndarray | None = None
) -> tuple[dict, np.ndarray]:
    if rgb is None:
        rgb = np.asarray(Image.open(frame).convert("RGB"), dtype=np.uint8)
    rgb = strip_lines(rgb)
    side = max(float(fit["col_step_px"]), float(fit["row_step_px"]))
    cells = cells_of(fit)
    if not cells:
        raise SystemExit("в игровой области нет целых клеток решётки — резать нечего")
    if max_tiles and len(cells) > max_tiles:
        stride = int(np.ceil(len(cells) / max_tiles))
        cells = cells[::stride]
    h, w = rgb.shape[:2]
    tiles, out = [], []
    for c in cells:
        cx, cy = c["center"]
        x0 = int(cx - side / 2.0)
        y0 = int(cy - side / 2.0)
        crop = rgb[y0 : min(h, y0 + int(side)), x0 : min(w, x0 + int(side))]
        if min(crop.shape[:2]) < int(side) * 0.9:
            continue
        tiles.append(
            np.asarray(
                Image.fromarray(crop).resize((tile, tile), Image.LANCZOS), dtype=np.uint8
            )
        )
        out.append(
            {
                "atlas": [len(tiles) - 1, 0],
                "tone": tone_of(crop),
                "src_cell": [int(c["q"]), int(c["r"])],
                "src_center": c["center"],
            }
        )
    cols = int(np.ceil(np.sqrt(len(tiles))))
    for i, cell in enumerate(out):
        cell["atlas"] = [i % cols, i // cols]
    manifest = {
        "version": VERSION,
        "tile": tile,
        "grid": [cols, int(np.ceil(len(tiles) / cols))],
        "source": {"path": str(frame), "sha256": digest, "size": list(fit["size"])},
        "fit": {
            k: fit.get(k)
            for k in (
                "origin",
                "col_step_px",
                "row_step_px",
                "radius_px",
                "stretch",
                "coverage",
                "residual_px",
                "inliers",
            )
        },
        # Линии кадра сняты при резке: без этого тайл приносит в игру контур
        # чужой решётки (параметры — аргументы strip_lines).
        "lines_removed": {"radius_px": 4, "threshold": 18},
        "cells": out,
    }
    return manifest, np.stack(tiles)


def _save(sheet: np.ndarray, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(sheet).save(path, "WEBP", quality=QUALITY, method=6)


def write_sheet(tiles: np.ndarray, cols: int, tile: int, path: Path) -> None:
    rows = int(np.ceil(len(tiles) / cols)) if len(tiles) else 1
    sheet = np.zeros((max(1, rows) * tile, cols * tile, 3), dtype=np.uint8)
    for i, t in enumerate(tiles):
        r, c = divmod(i, cols)
        sheet[r * tile : (r + 1) * tile, c * tile : (c + 1) * tile] = t
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(sheet).save(path, "WEBP", quality=QUALITY, method=6)


def layout_sheet(
    layout: Path, tiles: list[np.ndarray], tones: list[str], tile: int, path: Path
) -> tuple[list[dict], dict]:
    """Собрать лист в раскладке существующего атласа.

    Декалям перехода свой тайл не даётся — в кадре перехода нет, и честное
    «перехода нет» лучше мнимого. Биому, для которой в кадре нет ни тона, ни
    подмены, клетка берётся **из поверхности того же носителя** (`<layout>.webp`,
    то есть из текущего атласа): песчаное кольцо города — песочной текстуры, а не
    зелёной подделки. Если листа-носителя рядом нет, клетка становится травой и
    уезжает в `biomes_without_tone`. Рантайм не меняется ни на строку:
    `tools/map_shot.gd --atlas=` подменяет пиксели тем же тайлсетом, а в игре лист
    поднимает `TileAtlas.sheet_path()`.
    """
    spec = json.loads(layout.read_text())
    cols, rows = (int(v) for v in spec["grid"])
    if int(spec["tile"]) != tile:
        raise SystemExit(f"лист {layout}: тайл {spec['tile']} != {tile}")
    carrier = layout.with_suffix(".webp")
    base = (
        np.asarray(Image.open(carrier).convert("RGB"), dtype=np.uint8)
        if carrier.exists()
        else None
    )
    by_tone: dict[str, list[int]] = {}
    for i, tone in enumerate(tones):
        by_tone.setdefault(tone, []).append(i)
    if not by_tone.get("grass"):
        raise SystemExit("в доноре нет ни одной клетки тона grass — лист нечем наполнять")
    taken: dict[str, int] = {}
    sheet = np.zeros((rows * tile, cols * tile, 3), dtype=np.uint8)
    placed: list[dict] = []
    missing: list[str] = []
    substituted: dict[str, str] = {}
    from_layout: list[str] = []
    for cell in spec["cells"]:
        biome = str(cell["biome"])
        pool = by_tone.get(biome)
        if not pool and SUBSTITUTE.get(biome) in by_tone:
            sub = SUBSTITUTE[biome]
            substituted[biome] = sub
            pool = by_tone[sub]
        x, y = (int(v) for v in cell["atlas"])
        if not pool and base is not None:
            # Клетка достаётся носителю: своя текстура лучше чужой подделки.
            if biome not in from_layout:
                from_layout.append(biome)
            sheet[y * tile : (y + 1) * tile, x * tile : (x + 1) * tile] = base[
                y * tile : (y + 1) * tile, x * tile : (x + 1) * tile
            ]
            placed.append({"id": cell["id"], "tone": "carrier"})
            continue
        if not pool:
            if biome not in missing:
                missing.append(biome)
            pool = by_tone["grass"]
        n = taken.get(biome, 0)
        taken[biome] = n + 1
        src = pool[n % len(pool)]
        sheet[y * tile : (y + 1) * tile, x * tile : (x + 1) * tile] = tiles[src]
        placed.append({"id": cell["id"], "tone": tones[src]})
    _save(sheet, path)
    return placed, {
        "biomes_without_tone": missing,
        "biomes_substituted": substituted,
        "biomes_from_carrier": from_layout,
    }


def self_test() -> int:
    """Кадр 3×3 клетки с заведомыми тонами + тон по Lab."""
    pitch, tile = 40, 24
    colors = {
        "grass": (90, 110, 60),
        "water": (30, 60, 110),
        "sand": (200, 175, 110),
        "snow": (240, 245, 248),
        "rock": (105, 105, 105),
    }
    fit = {
        "origin": [0.0, 0.0],
        "col_step_px": float(pitch),
        "row_step_px": float(pitch),
        "radius_px": pitch / 2.0,
        "size": [pitch * 3 + 1, pitch * 3 + 1],
    }
    img = Image.new("RGB", tuple(fit["size"]), colors["grass"])
    px = img.load()
    rows = [
        ("grass", "water", "sand"),
        ("snow", "grass", "rock"),
        ("grass", "grass", "grass"),
    ]
    for r, row in enumerate(rows):
        for c, name in enumerate(row):
            for y in range(r * pitch, (r + 1) * pitch):
                for x in range(c * pitch, (c + 1) * pitch):
                    px[x, y] = colors[name]
    fit["roi"] = [0, 0, fit["size"][0] - 1, fit["size"][1] - 1]
    manifest, tiles = slice_donor(
        Path("synthetic"), fit, tile, 0, digest="0" * 64, rgb=np.asarray(img, dtype=np.uint8)
    )
    got = [c["tone"] for c in manifest["cells"]]
    want = [n for row in rows for n in row]
    base = np.full((24, 40, 3), colors["grass"], dtype=np.uint8)
    plate = base.copy()
    plate[11:13, :] = 25  # нарисованный контур клетки
    dev = int(np.abs(strip_lines(plate).astype(np.int16) - base.astype(np.int16)).max())
    # Подмена тона в раскладке: у дороги своего тона в наборе нет, и она обязана
    # взять глину, а не траву (иначе дорожное полотно в игре невидимо). Песок
    # подменить нечем: без листа-носителя он травa и уезжает в пробел, а с листом
    # носителя (`<layout>.webp`) клетка достаётся носителю, а не подделке.
    with tempfile.TemporaryDirectory() as tmp:
        t = Path(tmp)
        (t / "layout.json").write_text(json.dumps({
            "tile": 24, "grid": [2, 1],
            "cells": [
                {"id": "base_road_0", "kind": "base", "biome": "road", "atlas": [0, 0]},
                {"id": "base_sand_0", "kind": "base", "biome": "sand", "atlas": [1, 0]},
            ],
        }))
        probe_tiles = [
            np.full((24, 24, 3), (120, 90, 60), np.uint8),  # глина
            np.full((24, 24, 3), colors["grass"], np.uint8),
        ]
        probe, gaps = layout_sheet(
            t / "layout.json", probe_tiles, ["mud", "grass"], 24, t / "sheet.webp"
        )
        px = np.array([200, 10, 10], np.uint8)
        carrier_sheet = np.zeros((24, 48, 3), np.uint8)
        carrier_sheet[:, 24:] = px
        Image.fromarray(carrier_sheet).save(t / "layout.webp")
        probe_c, gaps_c = layout_sheet(
            t / "layout.json", probe_tiles, ["mud", "grass"], 24, t / "sheet2.webp"
        )
        carrier_px = np.asarray(Image.open(t / "sheet2.webp").convert("RGB"), np.uint8)[0, 30]
    checks = [
        ("тон воды", tone_of(np.array(colors["water"], np.uint8).reshape(1, 1, 3)), "water"),
        ("тон песка", tone_of(np.array(colors["sand"], np.uint8).reshape(1, 1, 3)), "sand"),
        ("тон снега", tone_of(np.array(colors["snow"], np.uint8).reshape(1, 1, 3)), "snow"),
        ("тон камня", tone_of(np.array(colors["rock"], np.uint8).reshape(1, 1, 3)), "rock"),
        ("тон травы", tone_of(np.array(colors["grass"], np.uint8).reshape(1, 1, 3)), "grass"),
        ("число тайлов", len(tiles), 9),
        ("сетка листа", manifest["grid"], [3, 3]),
        ("адрес row-major", manifest["cells"][4]["atlas"], [1, 1]),
        ("тайл квадратный", tuple(tiles[0].shape), (tile, tile, 3)),
        ("следов от линии (>12)", int(dev > 12), 0),
        ("дорога берёт глину", probe[0]["tone"], "mud"),
        ("подмена в отчёте", gaps["biomes_substituted"], {"road": "mud"}),
        ("песок без тона — трава", probe[1]["tone"], "grass"),
        ("пробел в отчёте", gaps["biomes_without_tone"], ["sand"]),
        ("песок у носителя", probe_c[1]["tone"], "carrier"),
        # webp — с потерями, поэтому пиксель сверяется допуском, а не равенством.
        ("пиксель носителя", int(np.abs(carrier_px.astype(int) - px).max()) <= 8, True),
        ("носитель в отчёте", gaps_c["biomes_from_carrier"], ["sand"]),
        ("пробел пуст у носителя", gaps_c["biomes_without_tone"], []),
    ]
    bad = 0
    for name, got_v, want_v in checks:
        ok = got_v == want_v
        bad += 0 if ok else 1
        print(f"SELF-TEST {'ok' if ok else 'FAIL'}: {name}: {got_v!r} (ожидалось {want_v!r})")
    tone_ok = [g for g, w in zip(got, want) if g == w]
    print(
        f"SELF-TEST {'ok' if len(tone_ok) >= 6 else 'FAIL'}: тона клеток: "
        f"{len(tone_ok)}/{len(want)} совпало ({got})"
    )
    if len(tone_ok) < 6:
        bad += 1
    return 1 if bad else 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--sha", help="префикс sha256 донора из реестра")
    ap.add_argument("--kit", type=Path, default=KIT_DEFAULT)
    ap.add_argument("--registry", type=Path, default=REGISTRY)
    ap.add_argument("--out-prefix", type=Path, default=Path("game/assets/tiles/world_map_kit"))
    ap.add_argument("--tile", type=int, default=82, help="сторона тайла = TileSet.tile_size")
    ap.add_argument("--max-tiles", type=int, default=256)
    ap.add_argument(
        "--layout",
        type=Path,
        help="манифест атласа, в чью раскладку собрать лист (world_map_atlas.json)",
    )
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    if args.self_test:
        return self_test()
    if not args.sha:
        ap.error("--sha обязателен (или --self-test)")
    reg = json.loads(args.registry.read_text())
    hits = [
        e
        for e in reg["scenes"].values()
        if str(e.get("sha256", "")).startswith(args.sha) and e.get("cell_fit", {}).get("accepted")
    ]
    if len(hits) != 1:
        raise SystemExit(f"донор {args.sha}: принято записей {len(hits)}, нужно ровно 1")
    entry = hits[0]
    digest = str(entry["sha256"])
    frame = next(
        (
            p
            for p in sorted(args.kit.glob("*.png"))
            if hashlib.sha256(p.read_bytes()).hexdigest() == digest
        ),
        None,
    )
    if frame is None:
        raise SystemExit(
            f"кадр с sha {digest[:12]} не найден в {args.kit}: передай --kit <каталог>"
        )
    manifest, tiles = slice_donor(frame, entry["cell_fit"], args.tile, args.max_tiles, digest)
    sheet = args.out_prefix.with_suffix(".webp")
    meta = args.out_prefix.with_suffix(".json")
    if args.layout:
        placed, gaps = layout_sheet(
            args.layout,
            tiles,
            [c["tone"] for c in manifest["cells"]],
            args.tile,
            sheet,
        )
        manifest["layout"] = str(args.layout)
        manifest["placed"] = placed
        manifest["gaps"] = gaps
    else:
        write_sheet(tiles, manifest["grid"][0], manifest["tile"], sheet)
    meta.write_text(json.dumps(manifest, ensure_ascii=False, indent=1) + "\n")
    tones: dict[str, int] = {}
    for cell in manifest["cells"]:
        tones[cell["tone"]] = tones.get(cell["tone"], 0) + 1
    print(
        f"LIST {sheet}: {len(tiles)} тайлов {args.tile}×{args.tile}, лист "
        f"{manifest['grid']}, тоны {json.dumps(tones, ensure_ascii=False)}"
    )
    if args.layout:
        print(
            "РАСКЛАДКА "
            f"{args.layout}: размещено {len(placed)} клеток, подменено "
            f"{json.dumps(gaps['biomes_substituted'], ensure_ascii=False)}, взято из "
            f"носителя {json.dumps(gaps['biomes_from_carrier'], ensure_ascii=False)}, "
            f"без покрытия: {json.dumps(gaps['biomes_without_tone'], ensure_ascii=False)}"
        )
    print(f"MANIFEST {meta}: донор {digest[:12]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

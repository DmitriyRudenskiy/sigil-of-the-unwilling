#!/usr/bin/env python3
"""Конвейер графики карты (openspec: world-map-art-variety, группы 3 и 4).

Шаги идемпотентны:

    python3 scripts/gen_map_art.py                      # генерация недостающих ролей (GPU)
    python3 scripts/gen_map_art.py --only mat_rock_0     # одна роль
    python3 scripts/gen_map_art.py --assemble            # роли → атлас тайлов + лист объектов
    python3 scripts/gen_map_art.py --contact-sheet       # лист приёмки (вердикт — за владельцем)
    python3 scripts/gen_map_art.py --repro mat_rock_0    # тот же (P,R) → тот же кадр

Сырьё 1024² (gitignored) — image-clone/map/raw/, носитель — game/assets/tiles/ и
game/assets/objects/. Промпты и сюжеты — scripts/concept_art/map_spec.json, в коде их нет.
"""
from __future__ import annotations

import argparse
import json
import math
import sys
import zlib
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts" / "concept_art"))
sys.path.insert(0, str(ROOT / "scripts"))
import generate as G                                    # noqa: E402  общий механизм прогона
import measure_palette_band as PB                       # noqa: E402  Lab/ΔE того же замера

SPEC = json.loads((ROOT / "scripts" / "concept_art" / "map_spec.json").read_text())
GATES = json.loads((ROOT / "game" / "data" / "config" / "map_art_gates.json").read_text())
TILE = int(SPEC["tile"])
RAW = ROOT / SPEC["out_dir"] / "raw"
MANIFEST = ROOT / SPEC["out_dir"] / "MANIFEST.json"
ATLAS_IMG = ROOT / "game/assets/tiles/world_map_atlas.webp"
ATLAS_JSON = ROOT / "game/assets/tiles/world_map_atlas.json"
OBJ_IMG = ROOT / "game/assets/objects/world_map_objects.webp"
OBJ_JSON = ROOT / "game/assets/objects/world_map_objects.json"
BAND = np.array([PB.parse_hex(h) for h in GATES["palette"]["band_m"]], dtype=np.float32)
BAND_LAB = PB.rgb_to_lab(BAND / 255.0)
QUALITY = int(SPEC["export"]["quality"])
VARIANT = SPEC["variants"][0]
UNSCHARP = ImageFilter.UnsharpMask(radius=1.2, percent=120, threshold=2)
WRAP_BAND = 128        # ширина зашивки шва на исходнике 1024 (на 82 px — ~10 px)
FEATHER = 0.22         # доля тайла, на которой утоняется декаль границы
SIDES = ("E", "NE", "NW", "W", "SW", "SE")


# ------------------------------------------------------------------ роли


def roles() -> list[dict]:
    """Плоский список ролей: material — кадр на вариант биома, object — изолированный спрайт."""
    out = []
    for cname, cat in SPEC["categories"].items():
        for item in cat["items"]:
            takes = item.get("takes") or [item["subject"]]
            for n, take in enumerate(takes):
                rid = f"{item['id']}_{n}" if len(takes) > 1 else item["id"]
                out.append({
                    "variant": VARIANT["id"], "category": cname, "id": rid, "subject": take,
                    "model_key": cat["model"], "size": tuple(cat["size"]),
                    "biome": item.get("biome") or item.get("group", ""),
                    "target": item.get("target"), "take": n, "path": RAW / f"{rid}.webp",
                })
    return out


def seed_for(art: dict, bump: int = 0) -> int:
    """Затравка выводима из (версия промпта, роль, попытка) — перевыпуск правкой слов
    меняет и seed, иначе кадр не отличить от прежнего."""
    key = f"{SPEC['prompt_version']}/{art['category']}/{art['id']}"
    return zlib.crc32(key.encode()) % (2**31) + bump


def render_raw(art: dict, dst: Path, attempt: int) -> dict:
    """Один прогон роли в dst. Механизм (граф, запуск, выгрузка, webp) — общий с концептом."""
    cat = SPEC["categories"][art["category"]]
    model = SPEC["models"][art["model_key"]]
    seed = seed_for(art, attempt - 1)
    prompt, neg = G.build_prompt(VARIANT, cat, art, model.get("negative") == "param")
    name = f"map_{art['id']}_a{attempt}"
    img = G.run_job(SPEC["comfy"],
                    G.workflow(art["model_key"], model, art, prompt, neg, seed, name,
                               SPEC.get("render", {})),
                    timeout=1800)
    tmp = dst.with_suffix(".part.png")
    dst.parent.mkdir(parents=True, exist_ok=True)
    G.download(SPEC["comfy"], img, tmp)
    G.to_webp(tmp, dst, QUALITY)
    tmp.unlink(missing_ok=True)
    ok, why = G.check_image(dst, art["size"], art["category"] == "objects")
    return {"id": art["id"], "ok": ok, "why": why, "seed": seed, "attempt": attempt,
            "prompt_version": SPEC["prompt_version"], "prompt": prompt, "negative": neg,
            "model": art["model_key"], "checkpoint": model["unet"],
            "server_file": f"{img.get('subfolder', '')}/{img['filename']}".strip("/"),
            "file": str(dst.relative_to(ROOT))}


def render(only: list[str], force: bool, attempts: int) -> int:
    man = json.loads(MANIFEST.read_text()) if MANIFEST.exists() else {}
    for art in roles():
        if only and art["id"] not in only:
            continue
        if art["path"].exists() and not force:
            continue
        rec = {"id": art["id"], "ok": False, "why": "не запускалась"}
        for attempt in range(1, attempts + 1):
            try:
                rec = render_raw(art, art["path"], attempt)
            except Exception as exc:                       # noqa: BLE001
                rec = {"id": art["id"], "ok": False, "why": str(exc)[:200], "attempt": attempt}
            if rec["ok"]:
                break
            print(f"  ✗ {art['id']} попытка {attempt}: {rec['why']}", flush=True)
        man[art["id"]] = rec
        print(f"{'✓' if rec['ok'] else '✗'} {art['id']}", flush=True)
        MANIFEST.parent.mkdir(parents=True, exist_ok=True)
        MANIFEST.write_text(json.dumps(man, ensure_ascii=False, indent=1))
    return 0 if all(v.get("ok") for v in man.values()) else 1


# ------------------------------------------------------------- постобработка


def make_wrap(a: np.ndarray, band: int = WRAP_BAND) -> np.ndarray:
    """Зашивка шва: левый край cross-fade с правым (верх с низом), зеркально.

    После этого col0 == col(-1) ровно, т. е. кадр — один период текстуры. Окно меньше
    периода шва не даёт, поэтому вариант = целый кадр, а не выкроенное окно (§3.2,
    уклонение: четыре варианта — четыре прогона одного биома, не четыре окна холста)."""
    h, w = a.shape[:2]
    b = min(band, w // 2)
    out = a.astype(np.float32)
    t = np.linspace(0.0, 1.0, b)
    ramp = (t * t * (3 - 2 * t))[None, :, None]            # smoothstep 0→1 по x
    left, right = out[:, :b].copy(), out[:, -b:].copy()[:, ::-1]
    band_x = left * (1 - ramp) + right * ramp
    out[:, :b] = band_x
    out[:, -b:] = band_x[:, ::-1]
    t = np.linspace(0.0, 1.0, b)
    ramp = (t * t * (3 - 2 * t))[:, None, None]
    top, bottom = out[:b].copy(), out[-b:].copy()[::-1]
    band_y = top * (1 - ramp) + bottom * ramp
    out[:b] = band_y
    out[-b:] = band_y[::-1]
    return np.clip(out, 0, 255).astype(np.uint8)


def pull_to_band(a: np.ndarray, target: str | None, to_band: float, to_target: float) -> np.ndarray:
    """Каждый пиксель тянется к ближайшему тону полосы M (кадр собирается внутри полосы,
    а не приводится к ней после) и к тону цели биома — он держит ΔE между биомами."""
    lab = PB.rgb_to_lab(a.astype(np.float32) / 255.0)
    near = np.take(BAND, ((lab[:, :, None, :] - BAND_LAB[None, None]) ** 2).sum(-1).argmin(-1), axis=0)
    out = a.astype(np.float32) * (1 - to_band) + near * to_band
    if target:
        out = out * (1 - to_target) + np.array(PB.parse_hex(target), dtype=np.float32) * to_target
    return np.clip(out, 0, 255).astype(np.uint8)


def tile_from(frame: Path, target: str | None) -> Image.Image:
    """Кадр роли → тайл 82 px: зашивка шва на исходнике, затем полоса M, unsharp, LANCZOS."""
    a = make_wrap(np.asarray(Image.open(frame).convert("RGB")))
    im = Image.fromarray(a).resize((TILE, TILE), Image.LANCZOS)
    im = Image.fromarray(pull_to_band(np.asarray(im), target, 0.4, 0.22))
    return im.filter(UNSCHARP)


def side_profile(size: int, side: str) -> np.ndarray:
    """Поле «до этой стороны шестиугольника»: 0 на стороне, 1 глубже порога пера.

    Клип клетки делает Godot, поэтому декаль обязан жить ровно внутри той же стороны:
    профиль считается по рёбрам вписанного шестиугольника, а не по прямоугольнику."""
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    cx, cy = size / 2.0, size / 2.0
    q = size / 4.0
    corners = {"E": ((size, q), (size, 3 * q)), "NE": ((cx, 0), (size, q)),
               "NW": ((0, q), (cx, 0)), "W": ((0, 3 * q), (0, q)),
               "SW": ((0, 3 * q), (cx, size)), "SE": ((cx, size), (size, 3 * q))}
    (x0, y0), (x1, y1) = corners[side]
    ex, ey = x1 - x0, y1 - y0
    nx, ny = ey / math.hypot(ex, ey), -ex / math.hypot(ex, ey)
    if nx * (cx - x0) + ny * (cy - y0) < 0:                # нормаль должна смотреть внутрь
        nx, ny = -nx, -ny
    d = (x - x0) * nx + (y - y0) * ny
    a = np.clip(d / (FEATHER * size), 0.0, 1.0)
    return np.clip(1.0 - a, 0.0, 1.0) ** 1.6               # 1 на стороне, 0 в глубине


def edge_decal(base: Image.Image, side: str) -> Image.Image:
    """Декаль границы — тот же материал биома, что и база, с альфа-профилем стороны."""
    a = np.asarray(base.convert("RGB")).astype(np.float32)
    alpha = side_profile(TILE, side) * 255.0
    return Image.fromarray(np.dstack([a, alpha]).astype(np.uint8), "RGBA")


def cut_object(frame: Path) -> Image.Image:
    """Белый фон → прозрачность порогом по яркости. Flood fill не нужен: фон у кадров
    однозначный, а дырка в светлой хвое дороже кривизны края силуэта."""
    a = np.asarray(Image.open(frame).convert("RGB")).astype(np.float32)
    alpha = np.clip((246.0 - a.min(2)) / 46.0, 0.0, 1.0)
    im = Image.fromarray(np.dstack([a, alpha * 255.0]).astype(np.uint8), "RGBA")
    return im.resize((TILE, TILE), Image.LANCZOS).filter(UNSCHARP)


# ------------------------------------------------------------------- сборка


def assemble() -> int:
    mats = [r for r in roles() if r["category"] == "materials" and r["path"].exists()]
    objs = [r for r in roles() if r["category"] == "objects" and r["path"].exists()]
    if not mats:
        raise SystemExit("нет ни одной сгенерированной роли — сначала генерация")
    tiles: list[Image.Image] = []
    cells: list[dict] = []

    def add(img: Image.Image, cell: dict) -> None:
        cell["atlas"] = [(len(tiles) % 8) * TILE, (len(tiles) // 8) * TILE]
        cell["src_box"] = [0, 0, TILE, TILE]
        tiles.append(img)
        cells.append(cell)

    for r in mats:
        base = tile_from(r["path"], r["target"])
        add(base, {"id": f"base_{r['biome']}_{r['take']}", "kind": "base", "biome": r["biome"],
                   "variant": r["take"], "source": str(r["path"].relative_to(ROOT))})
        if r["take"] == 0:                 # декаль границы один на биом: он про форму края,
            for side in SIDES:             # а не про вариативность заполнения
                add(edge_decal(base, side),
                    {"id": f"edge_{r['biome']}_{side}", "kind": "edge", "biome": r["biome"],
                     "side": side, "source": str(r["path"].relative_to(ROOT))})

    sheet = Image.new("RGBA", (8 * TILE, math.ceil(len(tiles) / 8) * TILE), (0, 0, 0, 0))
    for i, t in enumerate(tiles):
        sheet.paste(t.convert("RGBA"), ((i % 8) * TILE, (i // 8) * TILE), t)
    ATLAS_IMG.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(ATLAS_IMG, "WEBP", quality=QUALITY)
    ATLAS_JSON.write_text(json.dumps({
        "tile": TILE, "format": "webp", "quality": QUALITY, "sheet": [sheet.width, sheet.height],
        "prompt_version": SPEC["prompt_version"], "model": SPEC["models"], "cells": cells,
    }, ensure_ascii=False, indent=1))

    ocells = []
    osheet = Image.new("RGBA", (8 * TILE, math.ceil(len(objs) / 8) * TILE), (0, 0, 0, 0))
    for i, r in enumerate(objs):
        im = cut_object(r["path"])
        osheet.paste(im, ((i % 8) * TILE, (i // 8) * TILE), im)
        ocells.append({"id": r["id"], "group": r["biome"], "anchor": [TILE // 2, TILE - 2],
                       "atlas": [(i % 8) * TILE, (i // 8) * TILE],
                       "source": str(r["path"].relative_to(ROOT))})
    OBJ_IMG.parent.mkdir(parents=True, exist_ok=True)
    osheet.save(OBJ_IMG, "WEBP", quality=QUALITY)
    OBJ_JSON.write_text(json.dumps({
        "tile": TILE, "format": "webp", "quality": QUALITY, "sheet": [osheet.width, osheet.height],
        "prompt_version": SPEC["prompt_version"], "cells": ocells,
    }, ensure_ascii=False, indent=1))
    print(f"{ATLAS_IMG.relative_to(ROOT)}: {len(cells)} ячеек {sheet.size}, "
          f"{ATLAS_IMG.stat().st_size // 1024} KiB · {OBJ_IMG.relative_to(ROOT)}: "
          f"{len(ocells)} объектов, {OBJ_IMG.stat().st_size // 1024} KiB")
    return 0


def contact_sheet(out: Path) -> int:
    """Лист приёмки: тайлы и объекты на фоне карты, масштаб ×2 (вердикт — за владельцем)."""
    atlas = Image.open(ATLAS_IMG).convert("RGBA")
    objs = Image.open(OBJ_IMG).convert("RGBA")
    bg = Image.new("RGBA", (max(atlas.width, objs.width), atlas.height + objs.height + TILE * 2),
                   (*PB.parse_hex("#1d2829"), 255))
    bg.paste(atlas, (0, 0), atlas)
    bg.paste(objs, (0, atlas.height + TILE), objs)
    bg = bg.convert("RGB").resize((bg.width * 2, bg.height * 2), Image.NEAREST)
    out.parent.mkdir(parents=True, exist_ok=True)
    bg.save(out, "WEBP", quality=90)
    print(f"{out.relative_to(ROOT)} ({out.stat().st_size // 1024} KiB)")
    return 0


def repro(rid: str) -> int:
    """Тот же (P, R) → побайтово тот же кадр; другая затравка → другой кадр."""
    art = next((r for r in roles() if r["id"] == rid), None)
    if not art:
        raise SystemExit(f"нет роли {rid}")
    files = [RAW / f"{rid}_repro_{n}.webp" for n in "abc"]
    for dst, bump in zip(files, (0, 0, 7777)):
        render_raw(art, dst, 1 + bump)
    ha, hb, hc = (zlib.crc32(p.read_bytes()) for p in files)
    for p in files:
        p.unlink(missing_ok=True)
    print(f"{rid}: повтор identical={ha == hb} · другая затравка differs={ha != hc}")
    return 0 if (ha == hb and ha != hc) else 1


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--attempts", type=int, default=3)
    ap.add_argument("--assemble", action="store_true")
    ap.add_argument("--contact-sheet", action="store_true")
    ap.add_argument("--repro", default="")
    a = ap.parse_args()
    if a.assemble:
        return assemble()
    if a.contact_sheet:
        return contact_sheet(ROOT / SPEC["out_dir"] / "sheet_map_art.webp")
    if a.repro:
        return repro(a.repro)
    return render([s for s in a.only.split(",") if s], a.force, a.attempts)


if __name__ == "__main__":
    sys.exit(main())

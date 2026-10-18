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
import os
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
BAND_HEX = [h.lower() for h in GATES["palette"]["band_m"]]
BAND = np.array([PB.parse_hex(h) for h in BAND_HEX], dtype=np.float32)
BAND_LAB = PB.rgb_to_lab(BAND / 255.0)
RAMP_W = {int(k): np.array(v, dtype=np.float32) for k, v in SPEC["ramp_weights"].items()}
QUALITY = int(SPEC["export"]["quality"])
LOSSLESS = bool(SPEC["export"].get("lossless", False))
VARIANT = SPEC["variants"][0]
UNSCHARP = ImageFilter.UnsharpMask(radius=1.2, percent=120, threshold=2)
# Эксперимент T-138 (глазной A/B по глубине ямы зерна); 0 — атлас побайтово прежний.
GRAIN_INJECT = float(os.environ.get("GRAIN_INJECT", "0"))
WRAP_BAND = 128        # ширина зашивки шва на исходнике 1024 (на 82 px — ~10 px)
FEATHER = 0.22         # доля тайла, на которой утоняется декаль границы
SIDES = ("e", "ne", "nw", "w", "sw", "se")   # стороны остроконечного шестиугольника


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
                    "ramp": item.get("ramp"),
                    "shift": SPEC["variant_shift"][n % len(SPEC["variant_shift"])],
                    "take": n, "path": RAW / f"{rid}.webp",
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
        if only and not any(o in art["id"] for o in only):
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


def lab_to_rgb(lab: np.ndarray) -> np.ndarray:
    """Обрат к measure_palette_band.rgb_to_lab (D65, sRGB). В общий модуль замера его не
    несём: гейт обязан оставаться независимым от того, чем красят."""
    l, a, b = lab[..., 0], lab[..., 1], lab[..., 2]
    fy = (l + 16) / 116
    fx, fz = fy + a / 500, fy - b / 200
    f = np.stack([fx, fy, fz], axis=-1)
    xyz = np.where(f ** 3 > 0.008856, f ** 3, (f - 16 / 116) / 7.787)
    xyz = xyz * np.array([0.95047, 1.0, 1.08883])
    m = np.array([[3.2404542, -1.5371385, -0.4985314],
                  [-0.9692660, 1.8760108, 0.0415560],
                  [0.0556434, -0.2040259, 1.0572252]])
    lin = np.clip(xyz @ m.T, 0, 1)
    return np.clip(1.055 * lin ** (1 / 2.4) - 0.055, 0, 1)


def mottle(rid: str, size: int, amp: float, cells: int = 5) -> np.ndarray:
    """Низкочастотное пятно яркости — проталины, куртины, дюны. Частота нарочно низкая
    (5×5 на тайл): только так различает варианты подпись `atlas/distinct`, сжимающая
    клетку до 8×8, и только так пятно читается глазом на 82 px. Затравка — id роли."""
    rng = np.random.default_rng(zlib.crc32(rid.encode()))
    f = np.tile(rng.normal(size=(cells, cells)), (2, 2))
    o = int(rng.integers(cells))
    f = f[o:o + cells, o:o + cells]                     # сдвиг окна = период поля, шов целой
    small = Image.fromarray(((f + 2) * 63).clip(0, 255).astype(np.uint8), "L")
    return (np.asarray(small.resize((size, size), Image.BICUBIC), dtype=np.float32) / 127.5 - 1) * amp


def ramp_tile(a: np.ndarray, ramp: list[str], shift: float = 0.0,
              l_bias: np.ndarray | None = None, grain: float = 7.0,
              dither: float = 2.5, seed: str = "") -> np.ndarray:
    """Фактура остаётся структурой, цвет биома задаёт рампа тонов полосы.

    Сырьё модели — коричневая фактура у ВСЕХ биомов (снег и вода тоже: средний кадр
    #8a6944), поэтому «подмешать целевой тон и снапить к ближайшему» не работало:
    ближайший тон считался по хроматике, тёплые пиксели уезжали в светлый #cdbe9b, и
    восемь биомов сходились в один бежевый (кадр/contrast 3.9 при пороге 12). Здесь
    тон пикселя выбирается по его РАНГУ яркости, a/b берутся у тона полосы целиком.

    Ранг, а не min-max: у живой фактуры яркость скошена, и на min-max восемьдесят
    процентов пикселей уезжали в самый светлый тон рампы — атлас выходил кремовым в
    крапинку на всех восьми биомах. Квантиль даёт доли тонов ровно `ramp_weights` на
    любой фактуре, то есть средний цвет биома = среднее его рампы, и контраст между
    биомами перестаёт зависеть от того, что именно нарисовала модель.

    Вариант биома сдвигает пороги (`variant_shift`), то есть меняет доли тонов: `atlas/
    distinct` меряет клетку 8×8 как средний цвет, и именно средний цвет он видит
    разным. Центр тяжести каждого тона водим по L тона — кластер kmeans (`atlas/
    palette`) остаётся тоном полосы, разброс внутри кластера (фактура) живёт."""
    lab = PB.rgb_to_lab(np.clip(a, 0, 255) / 255.0)
    tone = np.array([BAND_LAB[BAND_HEX.index(h)] for h in ramp], dtype=np.float32)
    l = lab[..., 0] + (0.0 if l_bias is None else l_bias)
    cuts = np.clip(np.cumsum(RAMP_W[len(ramp)])[:-1] + shift, 0.02, 0.98)
    # Порог тонится шумом: без него граница двух тонов — гладкая линия, и тайл выглядит
    # как камуфляж из двух красок. Тот же приём держат ограниченные палитры ручной
    # работы: переход разбивается в точку. Каждый пиксель при этом остаётся ровно на
    # тоне полосы (`atlas/palette` меряет доминирующие тона — они не двигаются).
    rng = np.random.default_rng(zlib.crc32(("dither" + seed).encode()))
    k = np.searchsorted(np.quantile(l, cuts), l + rng.normal(0.0, dither, l.shape))
    off = np.clip(l - np.take(tone[:, 0], k), -grain, grain)
    for i in range(len(ramp)):        # срезка ±grain уводит среднее кластера — возвращаем
        m = k == i
        if m.any():
            off[m] -= off[m].mean()
    out = np.stack([np.take(tone[:, 0], k) + off,
                    np.take(tone[:, 1], k), np.take(tone[:, 2], k)], -1)
    return (lab_to_rgb(out) * 255.0).round().clip(0, 255).astype(np.uint8)


def tile_from(frame: Path, ramp: list[str], shift: float = 0.0,
              rid: str = "") -> Image.Image:
    """Кадр роли → тайл 82 px: зашивка шва, рампа биома, снова зашивка, unsharp."""
    a = make_wrap(np.asarray(Image.open(frame).convert("RGB")))
    # unsharp ДО перекраски: он зточит фактуру, из которой берётся ранг яркости, а не
    # края уже готовых тонов. После квантиля тот же фильтр рисует ореолы между двумя
    # тонами полосы, и их набирается достаточно, чтобы стать доминирующим кластером
    # (`atlas/palette` ловил #2e3122 при ΔE 12.2 именно так).
    im = Image.fromarray(a).resize((TILE, TILE), Image.LANCZOS).filter(UNSCHARP)
    t = ramp_tile(np.asarray(im), ramp, shift, mottle(rid or frame.stem, TILE, 7.0),
                  seed=rid or frame.stem)
    # Второй проход зашивки — уже по цвету. LANCZOS на даунскейле не знает про период
    # (у края он берёт пиксели за кадром), поэтому col0 и col(-1) различаются на доли
    # единицы L. Пока яркость была живописной, это никого не волновало; квантиль рампы
    # ставит порог в середину гистограммы, и те же доли единицы переворачивают тон на
    # всей кромке — 18 швов из 32 при пороге 24 MAD.
    im = Image.fromarray(make_wrap(t, band=10))
    return im.convert("RGBA")   # маска paste() обязана иметь альфу


def side_profile(size: int, side: str) -> np.ndarray:
    """Поле «до этой стороны шестиугольника»: 0 на стороне, 1 глубже порога пера.

    Клип клетки делает Godot, поэтому декаль обязан жить ровно внутри той же стороны:
    профиль считается по рёбрам вписанного шестиугольника, а не по прямоугольнику."""
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    cx, cy = size / 2.0, size / 2.0
    q = size / 4.0
    corners = {"e": ((size, q), (size, 3 * q)), "ne": ((cx, 0), (size, q)),
               "nw": ((0, q), (cx, 0)), "w": ((0, 3 * q), (0, q)),
               "sw": ((0, 3 * q), (cx, size)), "se": ((cx, size), (size, 3 * q))}
    (x0, y0), (x1, y1) = corners[side]
    ex, ey = x1 - x0, y1 - y0
    nx, ny = ey / math.hypot(ex, ey), -ex / math.hypot(ex, ey)
    if nx * (cx - x0) + ny * (cy - y0) < 0:                # нормаль должна смотреть внутрь
        nx, ny = -nx, -ny
    d = (x - x0) * nx + (y - y0) * ny
    a = np.clip(d / (FEATHER * size), 0.0, 1.0)
    return np.clip(1.0 - a, 0.0, 1.0) ** 1.6               # 1 на стороне, 0 в глубине


def edge_decal(base: Image.Image, side: str) -> Image.Image:
    """Декаль границы — тот же материал биома, что и база, с альфа-профилем стороны.

    `base` — среднее по вариантам биома, а не вариант 0 (вердикт В1 → (1), D-205):
    соседняя клетка стоит любым из четырёх, и декаль по одному из них вносит в стык
    половину рампы вариантов. Среднее делит худший шаг пополам и не растит атлас.

    GRAIN_INJECT (0 = по умолчанию, атлас побайтово прежний) — эксперимент T-138: вернуть
    декалю высокочастотную составляющую, съеденную усреднением четырёх вариантов.
    Среднее делит дисперсию зерна ~вдвое, отсюда яма Δgrain 0.80× в полосе пера; инжект
    поднимает дно ямы, не трогая её ширину (ширину задаёт FEATHER). Нужен ровно для того,
    чтобы глазной A/B решал вопрос глубины, а не ширины."""
    a = np.asarray(base.convert("RGB")).astype(np.float32)
    if GRAIN_INJECT:
        soft = np.asarray(Image.fromarray(a.astype(np.uint8)).filter(
            ImageFilter.GaussianBlur(1.0)), dtype=np.float32)
        a = np.clip(a + GRAIN_INJECT * (a - soft), 0.0, 255.0)
    alpha = side_profile(TILE, side) * 255.0
    return Image.fromarray(np.dstack([a, alpha]).astype(np.uint8), "RGBA")


def cut_object(frame: Path, fit: float = 0.86, bottom: int = 6) -> Image.Image:
    """Белый фон → прозрачность порогом по яркости, затем силуэт вписан в тайл.

    Порог, а не flood fill: фон у кадров однозначный, а дырка в светлой хвое дороже
    кривизны края силуэта. Вписывание с нижней кромкой нужно гейтам листа: силуэт не
    должен занимать больше 0.6 клетки и обязан оставлять прозрачную нижнюю полосу
    (на неё опирается якорь объекта на клетке)."""
    a = np.asarray(Image.open(frame).convert("RGB")).astype(np.float32)
    alpha = np.clip((250.0 - a.min(2)) / 30.0, 0.0, 1.0)
    im = Image.fromarray(np.dstack([a, alpha * 255.0]).astype(np.uint8), "RGBA")
    im = im.crop(im.split()[3].getbbox())
    s = min(fit * TILE / im.width, (fit * TILE - bottom) / im.height)
    im = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)
    out = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    # Без маски: paste(src, pos, src) смешивает с прозрачным чёрным фоном и по альфе,
    # то есть превращает RGB в предумноженный (RGB×α) — полупрозрачный край силуэта
    # становится тёмной каймой. Копирование без маски сохраняет straight alpha.
    out.paste(im, ((TILE - im.width) // 2, TILE - bottom - im.height))
    return out.filter(UNSCHARP)


# ------------------------------------------------------------------- сборка


def assemble() -> int:
    mats = [r for r in roles() if r["category"] == "materials" and r["path"].exists()]
    objs = [r for r in roles() if r["category"] == "objects" and r["path"].exists()]
    if not mats:
        raise SystemExit("нет ни одной сгенерированной роли — сначала генерация")
    tiles: list[Image.Image] = []
    cells: list[dict] = []
    bases: dict[str, list[Image.Image]] = {}
    first_path: dict[str, Path] = {}

    def add(img: Image.Image, cell: dict, src: Path) -> None:
        cell["atlas"] = [len(tiles) % 8, len(tiles) // 8]   # в ячейках сетки, не в px
        # окно материала в исходном кадре роли: тайл 82 px обязан быть выкроен из ≥4×,
        # иначе это даунскейл мыла, а не материала
        w, h = Image.open(src).size
        cell["src_box"] = [0, 0, w, h]
        tiles.append(img)
        cells.append(cell)

    for r in mats:
        base = tile_from(r["path"], r["ramp"], r["shift"], r["id"])
        add(base, {"id": f"base_{r['biome']}_{r['take']}", "kind": "base", "biome": r["biome"],
                   "variant": r["take"], "source": str(r["path"].relative_to(ROOT))}, r["path"])
        bases.setdefault(r["biome"], []).append(base)
        first_path.setdefault(r["biome"], r["path"])

    # Средний тон вариантов одного биома выравнивается к общему (T-143, глазной вердикт
    # 11.3 «налепанные заплаты»): `variant_shift` сдвигает пороги рампы, отчего среднее
    # L* уезжает на 3…13 ΔE, и карта собирается из тоновых заплат с прямым швом по
    # ребру клетки. Выравнивается именно среднее: низкочастотное пятно (`mottle`) и
    # зерно — то, чем варианты различаются по-настоящему, — остаются нетронутыми, и
    # подписи гейтов продолжают их видеть (замер по текущему атласу: после
    # выравнивания `atlas/distinct` 8×8 и подпись `frame/variety` 4×4 — 1.00,
    # попиксельный ΔE между вариантами 8…28).
    for biome, vs in bases.items():
        labs = [PB.rgb_to_lab(np.asarray(v.convert("RGB"), dtype=np.float64) / 255.0)
                for v in vs]
        target = np.mean([l.reshape(-1, 3).mean(0) for l in labs], axis=0)
        for v, l in zip(vs, labs):
            rgb = lab_to_rgb(l - (l.reshape(-1, 3).mean(0) - target)) * 255.0
            fixed = Image.fromarray(rgb.round().astype(np.uint8), "RGB").convert("RGBA")
            fixed.putalpha(v.split()[3])
            v.paste(fixed, (0, 0))

    # Декаль границы один на биом: он про форму края, а не про вариативность заполнения.
    for biome, variants in bases.items():
        mean = Image.fromarray(
            np.mean([np.asarray(v.convert("RGB"), dtype=np.float32) for v in variants],
                    axis=0).astype(np.uint8), "RGB")
        for side in SIDES:
            add(edge_decal(mean, side),
                {"id": f"edge_{biome}_{side}", "kind": "edge", "biome": biome,
                 "side": side, "source": str(first_path[biome].relative_to(ROOT))},
                first_path[biome])

    sheet = Image.new("RGBA", (8 * TILE, math.ceil(len(tiles) / 8) * TILE), (0, 0, 0, 0))
    for i, t in enumerate(tiles):
        # Без маски (см. cut_object): paste(src, pos, src) предумножил бы RGB на альфу.
        sheet.paste(t.convert("RGBA"), ((i % 8) * TILE, (i // 8) * TILE))
    ATLAS_IMG.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(ATLAS_IMG, "WEBP", quality=QUALITY, lossless=LOSSLESS)
    ATLAS_JSON.write_text(json.dumps({
        "tile": TILE, "image": ATLAS_IMG.name, "grid": [8, math.ceil(len(tiles) / 8)],
        "format": "webp", "quality": QUALITY,
        "prompt_version": SPEC["prompt_version"], "model": SPEC["models"], "cells": cells,
    }, ensure_ascii=False, indent=1))

    ocells = []
    osheet = Image.new("RGBA", (8 * TILE, math.ceil(len(objs) / 8) * TILE), (0, 0, 0, 0))
    for i, r in enumerate(objs):
        im = cut_object(r["path"])
        osheet.paste(im, ((i % 8) * TILE, (i // 8) * TILE))
        ocells.append({"id": r["id"], "group": r["biome"], "anchor": [TILE // 2, TILE - 2],
                       "atlas": [i % 8, i // 8],
                       "source": str(r["path"].relative_to(ROOT))})
    OBJ_IMG.parent.mkdir(parents=True, exist_ok=True)
    osheet.save(OBJ_IMG, "WEBP", quality=QUALITY, lossless=LOSSLESS)
    OBJ_JSON.write_text(json.dumps({
        "tile": TILE, "image": OBJ_IMG.name, "grid": [8, math.ceil(len(objs) / 8)],
        "format": "webp", "quality": QUALITY,
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

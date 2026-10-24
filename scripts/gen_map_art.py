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
from PIL import Image, ImageDraw, ImageFilter
from scipy.ndimage import label as label_components

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
OBJ_FOG_IMG = ROOT / "game/assets/objects/world_map_objects_fog.webp"
ROAD_IMG = ROOT / "game/assets/objects/world_map_roads.webp"
ROAD_FOG_IMG = ROOT / "game/assets/objects/world_map_roads_fog.webp"
ROAD_JSON = ROOT / "game/assets/objects/world_map_roads.json"
THREAT_IMG = ROOT / "game/assets/objects/world_map_threat.webp"
THREAT_JSON = ROOT / "game/assets/objects/world_map_threat.json"
# Зеркало `GameNumbersMap.MAP_FOG_DIM`: затемнённый побратим листа печатается здесь.
MAP_FOG_DIM = 0.45
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
WRAP_BAND = 32         # ширина зашивки шва на исходнике 1024 (на 82 px — ~2.5 px)
WRAP_TILE_BAND = 3     # то же на тайле 82 px после квантования


def hex_mask(size: int = TILE) -> Image.Image:
    """Альфа клетки атласа (базы и декаля границы): гекс с остриём сверху в коробке size×size.

    Движок кладёт тайлы как `TILE_SHAPE_HEXAGON` (tile_atlas.gd:build_hex), но рисует
    каждый тайл квадратным квадом: ряды идут с шагом 3/4 высоты, поэтому квады
    соседних рядов наезжают друг на друга на 1/4. Непрозрачная квадратная база
    в таких условиях рисует поверх соседей прямые углы — на карте это сетка
    прямоугольников поверх гексов (глазной вердикт 11.3 «налепанные заплаты»,
    T-143). Угловые треугольники обязаны быть прозрачными.
    """
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).polygon([
        (size / 2, 0), (size, size / 4), (size, size * 3 / 4),
        (size / 2, size), (0, size * 3 / 4), (0, size / 4)], fill=255)
    return m

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
                    # масштаб силуэта в тайле: по умолчанию 0.86, ниже — для напольных
                    # объектов (подлесок на 0.86 читается деревом, а не подлеском)
                    "fit": float(item.get("fit", 0.86)),
                    # дороги (6.1): тип декали — strip (полоса на всю ширину) или
                    # intersection (звезда на 3+ ветки); поворот полосы — в коде
                    "kind": item.get("kind", ""),
                    # isolated — свойство категории, а не имени: приёмка кадра
                    # («объект в поле белого, а не бесшовная ткань») обязана идти из
                    # map_spec.json, иначе новая изолированная категория (носители
                    # тиров, 8.1) молча проверялась бы как ткань
                    "isolated": bool(cat.get("isolated", False)),
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
    ok, why = G.check_image(dst, art["size"], art["isolated"])
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
    im = Image.fromarray(make_wrap(t, band=WRAP_TILE_BAND))
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

    Порог плюс связность с краем кадра: фон у кадров светлый, но не всегда чистый
    (серая виньетка), а дырка в светлой хвое дороже кривизны края силуэта, поэтому
    фоном считается только светлое, доходящее до рамки. Вписывание с нижней кромкой
    нужно гейтам листа: силуэт не должен занимать больше 0.6 клетки и обязан оставлять
    прозрачную нижнюю полосу (на неё опирается якорь объекта на клетке)."""
    a = np.asarray(Image.open(frame).convert("RGB")).astype(np.float32)
    alpha = np.clip((250.0 - a.min(2)) / 30.0, 0.0, 1.0)
    # «Плёнка»: модель кладёт вокруг сюжета серую виньетку, и порог выше делает из неё
    # полупрозрачное поле (на карте — светлый квадрат вокруг объекта). Вычитается только
    # то, что тянется от края кадра: светлые пиксели внутри сюжета (хвоя, снег, белизна
    # берёсты) до края не доходят и остаются на месте — за это порог вместо flood fill
    # и держали, связность возвращает ровно то, что он резал по цвету.
    near = a.min(2) >= 200.0
    components, _ = label_components(near)
    touching = (set(components[0, :]) | set(components[-1, :])
                | set(components[:, 0]) | set(components[:, -1]))
    touching.discard(0)
    if touching:
        alpha[np.isin(components, list(touching))] = 0.0
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


def cut_road(frame: Path, kind: str = "strip") -> Image.Image:
    """Дорожная декаль: белый фон → прозрачность (порог + связность с краем),
    затем декаль вписана в тайл по центру (не по нижнему краю, как объекты).

    strip — полоса дороги на всю ширину тайла (горизонтально, поворот по
    направлениям гекса — в коде); intersection — звезда на 3+ ветки, вписана
    в тайл целиком. Прозрачный фон: база биома видна по сторонам от дороги.
    """
    a = np.asarray(Image.open(frame).convert("RGB")).astype(np.float32)
    alpha = np.clip((250.0 - a.min(2)) / 30.0, 0.0, 1.0)
    near = a.min(2) >= 200.0
    components, _ = label_components(near)
    touching = (set(components[0, :]) | set(components[-1, :])
                | set(components[:, 0]) | set(components[:, -1]))
    touching.discard(0)
    if touching:
        alpha[np.isin(components, list(touching))] = 0.0
    im = Image.fromarray(np.dstack([a, alpha * 255.0]).astype(np.uint8), "RGBA")
    im = im.crop(im.split()[3].getbbox())
    if kind == "strip":
        # Полоса на всю ширину тайла: ширина = TILE, высота пропорциональна.
        s = TILE / im.width
        im = im.resize((TILE, max(1, round(im.height * s))), Image.LANCZOS)
        out = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
        out.paste(im, (0, (TILE - im.height) // 2))
    else:
        # Перекрёсток: вписать в тайл целиком (fit 0.95), по центру.
        s = min(0.95 * TILE / im.width, 0.95 * TILE / im.height)
        im = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)
        out = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
        out.paste(im, ((TILE - im.width) // 2, (TILE - im.height) // 2))
    return out.filter(UNSCHARP)


# --------------------------------------------------------------- дороги (6.1)

# Три оси гекса в экранных координатах (y вниз): поворот горизонтальной полосы
# на 0°/±60° даёт оси e–w, ne–sw, nw–se — тот же набор осей, что направления
# SIDES и таблицы соседей T_*_RIGHT в движке (проверено по главному направлению
# материала каждого тайла: −0.4°, −60.2°, +59.5°).
ROAD_AXES = (("ew", 0.0), ("nesw", 60.0), ("nwse", -60.0))


def rotate_road(im: Image.Image, angle: float) -> Image.Image:
    """Поворот декали вокруг центра тайла. expand=False: канвас 82×82 не растёт,
    прозрачные углы остаются прозрачными — декаль, а не квадрат."""
    if angle == 0.0:
        return im
    return im.rotate(angle, resample=Image.BICUBIC, expand=False,
                     center=(TILE / 2, TILE / 2))


def road_edge_decal(strip: Image.Image, side: str) -> Image.Image:
    """Кромка дороги на стороне `side`: материал полосы с альфа-профилем стороны
    гекса — та же механика, что у границ биомов (`edge_decal`/`side_profile`).
    Дорожный материал — ядро полосы (строки с плотной альфой), разложенное по
    профилю: кромка читается как та же дорога, что и полоса, только по краю."""
    a = np.asarray(strip.convert("RGB")).astype(np.float32)
    alpha = np.asarray(strip.split()[3]).astype(np.float32)
    rows = alpha.mean(axis=1)
    ys = np.where(rows > rows.max() * 0.5)[0]
    mat = a[int(ys.min()):int(ys.max()) + 1].mean(axis=0)   # материал по длине дороги
    prof = side_profile(TILE, side) * 255.0
    out = np.tile(mat[None, :, :], (TILE, 1, 1)).astype(np.float32)
    return Image.fromarray(np.dstack([out, prof]).astype(np.uint8), "RGBA")


def build_road_sheet(roads: list[dict]) -> list[dict]:
    """Лист дорог (6.1): декали на прозрачном фоне, по центру тайла. Отдельный
    лист — не объекты (те якорятся вниз) и не атлас (то бесшовная база).

    Сгенерированные роли (полоса/перекрёсток/мост × основная/второстепенная)
    детерминированно достраиваются до полного набора, который требует слой
    дорог 6.2: TileMapLayer не поворачивает квад, поэтому оси гекса и стороны
    кромки — отдельные клетки листа. Новых прогонов это не требует: всё
    выводится из уже принятых raw-ролей, байт листа стабилен при том же raw.
    """
    def surface(role_id: str) -> str:
        return "primary" if "primary" in role_id else "secondary"

    def raw_of(suffix: str) -> Path:
        for r in roads:
            if r["id"].endswith(suffix):
                if not r["path"].exists():
                    raise SystemExit(f"нет raw-роли дорог {r['path']}")
                return r["path"]
        raise SystemExit(f"в спеке нет дорожной роли {suffix}")

    tiles: list[Image.Image] = []
    cells: list[dict] = []

    def add(img: Image.Image, cell: dict, src: Path) -> None:
        cell["atlas"] = [len(tiles) % 8, len(tiles) // 8]
        cell["source"] = str(src.relative_to(ROOT))
        tiles.append(img)
        cells.append(cell)

    for kind, suffix in (("strip", "strip"), ("bridge", "bridge")):
        for role in ("primary", "secondary"):
            path = raw_of(f"{suffix}_{role}")
            base = cut_road(path, "strip")
            for axis, angle in ROAD_AXES:
                add(rotate_road(base, angle),
                    {"id": f"road_{kind}_{axis}_{role}", "kind": kind,
                     "surface": surface(role), "axis": axis}, path)

    for role in ("primary", "secondary"):
        path = raw_of(f"intersection_{role}")
        add(cut_road(path, "intersection"),
            {"id": f"road_intersection_{role}", "kind": "intersection",
             "surface": surface(role)}, path)

    for role in ("primary", "secondary"):
        path = raw_of(f"strip_{role}")
        base = cut_road(path, "strip")
        for side in SIDES:
            add(road_edge_decal(base, side),
                {"id": f"road_edge_{side}_{role}", "kind": "edge",
                 "surface": surface(role), "side": side}, path)

    sheet = Image.new("RGBA", (8 * TILE, math.ceil(len(tiles) / 8) * TILE), (0, 0, 0, 0))
    for i, t in enumerate(tiles):
        sheet.paste(t, ((i % 8) * TILE, (i // 8) * TILE))
    ROAD_IMG.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(ROAD_IMG, "WEBP", quality=QUALITY, lossless=LOSSLESS)
    fog_twin(ROAD_IMG, ROAD_FOG_IMG)
    ROAD_JSON.write_text(json.dumps({
        "tile": TILE, "image": ROAD_IMG.name, "grid": [8, math.ceil(len(tiles) / 8)],
        "format": "webp", "quality": QUALITY,
        "prompt_version": SPEC["prompt_version"], "cells": cells,
    }, ensure_ascii=False, indent=1))
    return cells


# ------------------------------------------------------------------- сборка


def whole_or_skip(category: str, present: list[dict], sheet: Path) -> list[dict]:
    """Сырьё ролей — в gitignored `image-clone/map/raw`, лист — в репо и на него уже
    смотрит игра. Поэтому неполное сырьё — не повод писать укороченный лист:
    `assemble()` перебирает наличные роли, и на машине, где половина кадров
    потеряна, он собрал бы лист из того, что есть, а манифест перестал бы описывать
    то, что игра ещё читает (у объектов 22 роли, и лист, собранный из трёх новых
    носителей тиров, ронял бы каждую карту). Категория с неполным сырьём
    пропускается с явной строкой — молчание здесь и было бы отказом."""
    total = len([r for r in roles() if r["category"] == category])
    if len(present) == total:
        return present
    if not present:
        return present                          # пусто и писать нечего — молчание честно
    if sheet.exists():
        print(f"{category}: ПРОПУЩЕНО (ролей {len(present)} из {total}, "
              f"лист {sheet.name} не тронут)")
        return []
    print(f"{category}: НЕПОЛНО (ролей {len(present)} из {total}, листа ещё нет — "
          f"пишу неполный)")
    return present


def assemble() -> int:
    mats = whole_or_skip("materials", [r for r in roles() if r["category"] == "materials"
                                       and r["path"].exists()], ATLAS_IMG)
    objs = whole_or_skip("objects", [r for r in roles() if r["category"] == "objects"
                                     and r["path"].exists()], OBJ_IMG)
    roads = whole_or_skip("roads", [r for r in roles() if r["category"] == "roads"
                                    and r["path"].exists()], ROAD_IMG)
    threats = whole_or_skip("threat", [r for r in roles() if r["category"] == "threat"
                                       and r["path"].exists()], THREAT_IMG)
    if not mats and not objs and not roads and not threats:
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

    # Варианты биома — фазы ОДНОЙ ткани, а не четыре разных рисунка (глазной приём 11.3,
    # круг 18): четыре независимых кадра различаются направлением и масштабом мазка —
    # ориентационное расхождение градиента (L1 по 18 бинам) у песка 0.94, у дороги 0.56,
    # у травы 0.27 — и карта собирается диагональной «ёлочкой»: глаз читает мозаику
    # плиток, а не ландшафт (носитель `review-11-3/phase-variants-t143.png`). Циклический
    # сдвиг зашитого тайла статистики не меняет: соседние клетки различаются зерном,
    # а не тканью. Рампа и `shift` take'а во всех, кроме нулевого, не участвуют: тон
    # варианта выравнивается к среднему биома ниже по коду, а `atlas/distinct` (8×8)
    # различает фазы и так: `atlas/distinct` 1.00 при пороге ≥0.90.
    fabric: dict[str, np.ndarray] = {}

    if mats:
        for r in mats:
            if r["take"] == 0:
                base = tile_from(r["path"], r["ramp"], r["shift"], r["id"])
                fabric[r["biome"]] = np.asarray(base)
            else:
                rng = np.random.default_rng(zlib.crc32(r["id"].encode()))
                dy, dx = rng.integers(11, 71, 2)   # фаза: не кратно 1/2 тайла, чтобы глаз не ловил период
                rolled = np.roll(np.roll(fabric[r["biome"]], int(dy), 0), int(dx), 1)
                base = Image.fromarray(make_wrap(rolled, band=WRAP_TILE_BAND), "RGBA")
            add(base, {"id": f"base_{r['biome']}_{r['take']}", "kind": "base", "biome": r["biome"],
                       "variant": r["take"], "source": str(r["path"].relative_to(ROOT))}, r["path"])
            bases.setdefault(r["biome"], []).append(base)
            first_path.setdefault(r["biome"], r["path"])

        # Средний тон вариантов одного биома выравнивается к общему (T-143, глазной
        # вердикт 11.3 «налепанные заплаты»): `variant_shift` сдвигает пороги рампы,
        # отчего среднее L* уезжает на 3…13 ΔE, и карта собирается из тоновых заплат
        # с прямым швом по ребру клетки. Выравнивается именно среднее: низкочастотное
        # пятно (`mottle`) и зерно — то, чем варианты различаются по-настоящему, —
        # остаются нетронутыми, и подписи гейтов продолжают их видеть (замер по
        # текущему атласу: после выравнивания `atlas/distinct` 8×8 и подпись
        # `frame/variety` 4×4 — 1.00, попиксельный ΔE между вариантами 8…28).
        # Среднее берётся по гексу движка, а не по квадрату 82×82: глаз видит гекс,
        # угловые треугольники не рисуются.
        hex_in = np.asarray(hex_mask()) > 0
        for biome, vs in bases.items():
            labs = [PB.rgb_to_lab(np.asarray(v.convert("RGB"), dtype=np.float64) / 255.0)
                    for v in vs]
            means = [l[hex_in].reshape(-1, 3).mean(0) for l in labs]
            target = np.mean(means, axis=0)
            for v, l, mean in zip(vs, labs, means):
                rgb = lab_to_rgb(l - (mean - target)) * 255.0
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
        mask = hex_mask()
        for i, t in enumerate(tiles):
            t = t.convert("RGBA")
            # И база, и декаль границы — гексом: движок рисует каждый тайл квадратным
            # квадом, а ряды идут с шагом 3/4 высоты, поэтому непрозрачные углы
            # наезжают на соседей и рисуют на карте сетку прямоугольников (T-143).
            t.putalpha(Image.fromarray(np.minimum(np.asarray(mask), np.asarray(t.split()[3]))))
            # Без маски (см. cut_object): paste(src, pos, src) предумножил бы RGB на альфу.
            sheet.paste(t, ((i % 8) * TILE, (i // 8) * TILE))
        ATLAS_IMG.parent.mkdir(parents=True, exist_ok=True)
        sheet.save(ATLAS_IMG, "WEBP", quality=QUALITY, lossless=LOSSLESS)
        ATLAS_JSON.write_text(json.dumps({
            "tile": TILE, "image": ATLAS_IMG.name, "grid": [8, math.ceil(len(tiles) / 8)],
            "format": "webp", "quality": QUALITY,
            "prompt_version": SPEC["prompt_version"], "model": SPEC["models"], "cells": cells,
        }, ensure_ascii=False, indent=1))

    if objs:
        ocells = []
        osheet = Image.new("RGBA", (8 * TILE, math.ceil(len(objs) / 8) * TILE), (0, 0, 0, 0))
        for i, r in enumerate(objs):
            im = cut_object(r["path"], r["fit"])
            osheet.paste(im, ((i % 8) * TILE, (i // 8) * TILE))
            ocells.append({"id": r["id"], "group": r["biome"], "anchor": [TILE // 2, TILE - 2],
                           "atlas": [i % 8, i // 8],
                           "source": str(r["path"].relative_to(ROOT))})
        OBJ_IMG.parent.mkdir(parents=True, exist_ok=True)
        osheet.save(OBJ_IMG, "WEBP", quality=QUALITY, lossless=LOSSLESS)
        fog_twin()
        OBJ_JSON.write_text(json.dumps({
            "tile": TILE, "image": OBJ_IMG.name, "grid": [8, math.ceil(len(objs) / 8)],
            "format": "webp", "quality": QUALITY,
            "prompt_version": SPEC["prompt_version"], "cells": ocells,
        }, ensure_ascii=False, indent=1))

    # Носители тиров (8.1): три маркера колец угрозы, якорь вниз как у объектов,
    # но отдельным листом — у объектов своё сырьё и свой манифест, а носитель тира
    # читается из модели и переживает смерть объектов (и наоборот). Побратима
    # «в тумане» нет: вражеские стэки в открытой, но не видимой клетке скрыты
    # целиком (вердикт В2 → (в), D-205), затемнять нечего.
    tcells: list[dict] = []
    if threats:
        tsheet = Image.new("RGBA", (8 * TILE, math.ceil(len(threats) / 8) * TILE),
                           (0, 0, 0, 0))
        for i, r in enumerate(threats):
            tsheet.paste(cut_object(r["path"], r["fit"]), ((i % 8) * TILE, (i // 8) * TILE))
            tcells.append({"id": r["id"], "group": r["biome"], "ring": i + 1,
                           "anchor": [TILE // 2, TILE - 2], "atlas": [i % 8, i // 8],
                           "source": str(r["path"].relative_to(ROOT))})
        THREAT_IMG.parent.mkdir(parents=True, exist_ok=True)
        tsheet.save(THREAT_IMG, "WEBP", quality=QUALITY, lossless=LOSSLESS)
        THREAT_JSON.write_text(json.dumps({
            "tile": TILE, "image": THREAT_IMG.name, "grid": [8, math.ceil(len(threats) / 8)],
            "format": "webp", "quality": QUALITY,
            "prompt_version": SPEC["prompt_version"], "cells": tcells,
        }, ensure_ascii=False, indent=1))

    # Дороги (6.1): декали на прозрачном фоне, по центру тайла. Отдельный лист
    # (не объекты — якорь вниз, не атлас — бесшовная база): слой дорог 6.2 строит
    # из него тайлсет, поворот полосы по направлениям гекса — в коде.
    rcells = build_road_sheet(roads) if roads else []
    parts = []
    if mats:
        parts.append(f"{ATLAS_IMG.relative_to(ROOT)}: {len(cells)} ячеек {sheet.size}, "
                     f"{ATLAS_IMG.stat().st_size // 1024} KiB")
    if objs:
        parts.append(f"{OBJ_IMG.relative_to(ROOT)}: {len(ocells)} объектов, "
                     f"{OBJ_IMG.stat().st_size // 1024} KiB")
    if roads:
        parts.append(f"{ROAD_IMG.relative_to(ROOT)}: {len(rcells)} дорог, "
                     f"{ROAD_IMG.stat().st_size // 1024} KiB")
    if tcells:
        parts.append(f"{THREAT_IMG.relative_to(ROOT)}: {len(tcells)} носителей тира, "
                     f"{THREAT_IMG.stat().st_size // 1024} KiB")
    print(" · ".join(parts))
    return 0


def contact_sheet(out: Path) -> int:
    """Лист приёмки: тайлы, объекты и дороги на фоне карты, масштаб ×2 (вердикт — за владельцем)."""
    atlas = Image.open(ATLAS_IMG).convert("RGBA")
    objs = Image.open(OBJ_IMG).convert("RGBA")
    roads = Image.open(ROAD_IMG).convert("RGBA") if ROAD_IMG.exists() else None
    threat = Image.open(THREAT_IMG).convert("RGBA") if THREAT_IMG.exists() else None
    extra = [x for x in (roads, threat) if x is not None]
    h = atlas.height + objs.height + TILE * 2 + sum(x.height + TILE for x in extra)
    w = max([atlas.width, objs.width] + [x.width for x in extra])
    bg = Image.new("RGBA", (w, h), (*PB.parse_hex("#1d2829"), 255))
    bg.paste(atlas, (0, 0), atlas)
    bg.paste(objs, (0, atlas.height + TILE), objs)
    y = atlas.height + objs.height + TILE * 2
    for x in extra:
        bg.paste(x, (0, y), x)
        y += x.height + TILE
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


def fog_twin(src: Path = OBJ_IMG, dst: Path = OBJ_FOG_IMG) -> int:
    """Затемнённый побратим листа (дефект T-150): туман войны кладёт тот же
    объект вторым источником тайлсета, и кратность обязана быть той же, что у базы
    (`GameNumbersMap.MAP_FOG_DIM` — источник истины, здесь только зеркало).

    Печатаем отдельным файлом, а не красим на лету: в этом билде Godot у `Image` нет
    ни `modulate_rect`, ни поштучной модуляции клетки, а цикл по 5 млн пикселей в
    GDScript подорожал бы каждой генерации карты."""
    im = Image.open(src).convert("RGBA")
    a = np.asarray(im).astype(np.float32)
    a[..., :3] *= MAP_FOG_DIM
    Image.fromarray(a.astype(np.uint8), "RGBA").save(
        dst, "WEBP", quality=QUALITY, lossless=LOSSLESS)
    rel = dst.relative_to(ROOT) if dst.is_relative_to(ROOT) else dst
    print(f"{rel}: ×{MAP_FOG_DIM}, {dst.stat().st_size // 1024} KiB")
    return 0


def ramp_of(biome: str) -> list[str]:
    """Рампа биома из спека (там же источник правды про тоны материалов)."""
    for it in SPEC["categories"]["materials"]["items"]:
        if it.get("biome") == biome:
            return [h.lower() for h in it["ramp"]]
    raise SystemExit(f"в спеке нет материала биома {biome}")


def tones(ramp: list[str]) -> np.ndarray:
    """Lab-тоны рампы; тон вне полосы M — ошибка вызова, а не тихая подмена."""
    bad = [h for h in ramp if h not in BAND_HEX]
    if bad:
        raise SystemExit(f"тонов вне полосы M нет: {', '.join(bad)} (полоса: {BAND_HEX})")
    return np.array([BAND_LAB[BAND_HEX.index(h)] for h in ramp], dtype=np.float64)


def lab_u8(lab: np.ndarray) -> np.ndarray:
    """Lab (0…100) → uint8 RGB тем же преобразованием, что `ramp_tile`."""
    return (lab_to_rgb(lab) * 255.0).round().clip(0, 255).astype(np.uint8)


def recolor_cell(rgb: np.ndarray, old: list[str], new: list[str]) -> np.ndarray:
    """Пиксель → его тон-кластер → новый тон, отклонение сохраняется.

    `ramp_tile` кладёт пикселю тон рампы по рангу яркости и оставляет зерно как
    отклонение L от тона; здесь тот же шаг в обратную сторону: ближайший тон старой
    рампы в Lab даёт кластер, разность пикселя с кластером (зерно, низкочастотное
    пятно `mottle`, тень декаля, следы webp-сжатия) сохраняется целиком, а кластер
    заменяется новым тоном. Поэтому фактура не меняется ни на пиксель, а цвет
    уходит целиком — в том числе тогда, когда новых тонов другое количество
    (кластеры отображаются пропорционально индексу).
    """
    lab = PB.rgb_to_lab(rgb.astype(np.float64) / 255.0)
    ot, nt = tones(old), tones(new)
    k = ((lab[:, :, None, :] - ot[None, None, :, :]) ** 2).sum(-1).argmin(-1)
    # Индекс кластера — и есть структура (ранг яркости сырья); если новых тонов
    # другое число, индексы отображаются в новый масштаб пропорционально.
    idx = k if len(new) == len(old) else np.round(
        k * (len(new) - 1) / max(1, len(old) - 1)).astype(int)
    off = lab - ot[k]
    return (lab_to_rgb(nt[idx] + off) * 255.0
            ).round().clip(0, 255).astype(np.uint8)


def recolor(mapping: dict[str, list[str]], out: Path, ab: Path | None = None) -> int:
    """Перекраска клеток уже собранного атласа в другие тоны полосы (T-163).

    Raw-кадров восьми материалов на машине сборки нет, а `assemble()` пишет лист
    только из наличных ролей, значит «поправить рампу и пересобрать» = заново
    генерировать все материалы на GPU. Этот шаг меняет только то, что меняет рампа:
    цвет тон-кластеров. Носитель не трогается — пишется лист-кандидат и манифест-
    побратим, чтобы `check_map_art.py --atlas` прогнал по нему весь набор мер.
    """
    src = Image.open(ATLAS_IMG).convert("RGBA")
    man = json.loads(ATLAS_JSON.read_text())
    if out.resolve() == ATLAS_IMG.resolve():
        raise SystemExit("носитель не перезаписывается: --recolor-out в другой путь")
    # Клетки пишутся в numpy-буфер, а не через `Image.paste`: paste с RGBA-источником
    # домножает полупрозрачные пиксели декалей на то, что лежало под ними, и граница
    # биома после перекраски «в себя» уже не совпадает с носителем.
    dst = np.asarray(src).copy()
    # Голубой тон полосы — именно он на белёсых чёрточках читается как вода (T-163).
    blue = PB.tone_lab(PB.parse_hex("#95cde5"))
    hex_in = np.asarray(hex_mask()) > 0
    for biome, new_ramp in mapping.items():
        old_ramp = ramp_of(biome)
        tones(new_ramp)
        share = [0, 0]
        total = 0
        items: list[list] = []
        for c in man["cells"]:
            if c.get("biome") != biome or c.get("kind") not in ("base", "edge"):
                continue
            x, y = int(c["atlas"][0]) * TILE, int(c["atlas"][1]) * TILE
            cell = src.crop((x, y, x + TILE, y + TILE))
            rgb = np.asarray(cell.convert("RGB"))
            new_rgb = recolor_cell(rgb, old_ramp, new_ramp)
            for i, arr in enumerate((rgb, new_rgb)):
                lab = PB.rgb_to_lab(arr.astype(np.float64) / 255.0)
                share[i] += int((PB.de76(lab, blue) < 12).sum())
            total += int(hex_in.sum())
            items.append([c["id"], (x, y), new_rgb, np.asarray(cell.split()[3])])
        # Доли тонов у вариантов различаются по замыслу (`variant_shift` фазы), поэтому
        # после смены тонов средние тона вариантов разъезжаются заново: выравнивание —
        # тот же шаг, что `assemble()` кладёт сразу за рампой, и тот же порог
        # `atlas/variant-tone`. Декаль границы собирается из средних вариантов, значит
        # получает среднее из смещений.
        bases = [it for it in items if it[0].startswith("base_")]
        delta: list[np.ndarray] = []
        if bases:
            labs = [PB.rgb_to_lab(it[2].astype(np.float64) / 255.0) for it in bases]
            means = [lab[hex_in].reshape(-1, 3).mean(0) for lab in labs]
            target = np.mean(means, axis=0)
            delta = [-(m - target) for m in means]
            for it, lab, d in zip(bases, labs, delta):
                it[2] = lab_u8(lab + d)
        edge_shift = np.mean(delta, axis=0) if delta else 0.0
        for it in items:
            if not it[0].startswith("base_"):
                it[2] = lab_u8(PB.rgb_to_lab(it[2].astype(np.float64) / 255.0) + edge_shift)
            x, y = it[1]
            dst[y:y + TILE, x:x + TILE, :3] = it[2]
            dst[y:y + TILE, x:x + TILE, 3] = it[3]
        print(f"{biome:6s} {str(old_ramp):34s} → {str(new_ramp):34s} около-голубого: "
              f"{100.0 * share[0] / max(1, total):.0f}% → {100.0 * share[1] / max(1, total):.0f}%")
    out.parent.mkdir(parents=True, exist_ok=True)
    dst_img = Image.fromarray(dst, "RGBA")
    dst_img.save(out, "WEBP", quality=QUALITY, lossless=LOSSLESS)
    man["image"] = out.name
    out.with_suffix(".json").write_text(json.dumps(man, ensure_ascii=False, indent=1))
    print(f"кандидат: {out} + {out.with_suffix('.json')} "
          f"({out.stat().st_size // 1024} KiB, носитель не тронут)")
    if ab is not None:
        recolor_ab(src, dst_img, mapping, ab)
    return 0


def recolor_ab(before: Image.Image, after: Image.Image, mapping: dict[str, list[str]],
               out: Path, scale: int = 2) -> None:
    """A/B-лист для глазного вердикта: строка биома — сначала все варианты «до»,
    затем все «после», тем же порядком манифеста, без ресайза кроме целого ×2."""
    man = json.loads(ATLAS_JSON.read_text())
    pad, lab_h = 6, 16
    cols = 4
    w = (TILE * scale + pad) * cols * 2 + pad
    h = (TILE * scale + lab_h + pad) * len(mapping) + pad
    sheet = Image.new("RGBA", (w, h), (*PB.parse_hex("#1d2829"), 255))
    d = ImageDraw.Draw(sheet)
    for r, biome in enumerate(mapping):
        y = pad + r * (TILE * scale + lab_h + pad)
        d.text((pad, y), f"{biome} BEFORE", fill=(235, 235, 225, 255))
        y0 = y + lab_h
        n = 0
        for c in man["cells"]:
            if c.get("biome") != biome or c.get("kind") != "base":
                continue
            x, yy = int(c["atlas"][0]) * TILE, int(c["atlas"][1]) * TILE
            box = (x, yy, x + TILE, yy + TILE)
            for side, im in enumerate((before, after)):
                cell = im.crop(box).resize((TILE * scale, TILE * scale), Image.NEAREST)
                sheet.paste(cell, (pad + (side * cols + n) * (TILE * scale + pad), y0), cell)
            n += 1
        d.text((pad + cols * (TILE * scale + pad), y), f"{biome} AFTER", fill=(235, 235, 225, 255))
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.convert("RGB").save(out)
    print(f"A/B: {out}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--attempts", type=int, default=3)
    ap.add_argument("--assemble", action="store_true")
    ap.add_argument("--fog-twin", action="store_true",
                    help="пересобрать затемнённый побратим листа из уже собранного листа")
    ap.add_argument("--contact-sheet", action="store_true")
    ap.add_argument("--repro", default="")
    ap.add_argument("--recolor", default="",
                    help='JSON вида {"road": ["#6d6d47", "#cdbe9b"]} — перекраска '
                         "клеток готового атласа в другие тоны полосы, без raw-кадров")
    ap.add_argument("--recolor-out", default="",
                    help="куда положить лист-кандидат (рядом ляжет манифест-побратим)")
    ap.add_argument("--recolor-ab", default="",
                    help="туда же положить A/B-лист для глазного вердикта владельца")
    a = ap.parse_args()
    if a.assemble:
        return assemble()
    if a.fog_twin:
        # Каждый лист, который уже собран: объекты и дороги — независимые носители.
        done = 0
        for sheet_src, sheet_dst in ((OBJ_IMG, OBJ_FOG_IMG), (ROAD_IMG, ROAD_FOG_IMG)):
            if sheet_src.exists():
                fog_twin(sheet_src, sheet_dst)
                done += 1
        if not done:
            raise SystemExit("нет ни одного собранного листа — сначала --assemble")
        return 0
    if a.contact_sheet:
        return contact_sheet(ROOT / SPEC["out_dir"] / "sheet_map_art.webp")
    if a.repro:
        return repro(a.repro)
    if a.recolor:
        if not a.recolor_out:
            raise SystemExit("--recolor без --recolor-out: кандидат писать некуда")
        mapping = {k.lower(): [h.lower() for h in v] for k, v in
                   json.loads(Path(a.recolor).read_text() if Path(a.recolor).exists()
                              else a.recolor).items()}
        return recolor(mapping, Path(a.recolor_out),
                       Path(a.recolor_ab) if a.recolor_ab else None)
    return render([s for s in a.only.split(",") if s], a.force, a.attempts)


if __name__ == "__main__":
    sys.exit(main())

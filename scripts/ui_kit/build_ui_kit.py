#!/usr/bin/env python3
"""Сборка виджет-графики темы по мерке макета (ui-mockup-parity, шаг 4).

ЗАЧЕМ ВЕКТОР, А НЕ ГЕНЕРАЦИЯ (отход от design.md §5 — зафиксирован там же)
--------------------------------------------------------------------------
Макет задаёт рамку фаской 45° и линиями толщиной в один пиксель. Диффузная
модель не держит ни точную геометрию угла, ни толщину линии, а 9-slice
требует, чтобы угол текстуры был ровно тем, что видно в макете: растягивать
можно только середину. Поэтому геометрия рисуется по мерке, а материал поля
берётся сэмплом зерна с той же плиты макета и калибруется по мерке яркости.
Лаборатория (`scripts/concept_art`) остаётся там, где макет ответа не даёт:
крупный художественный арт, которого в кадрах нет.

МЕРКА (reference/09_start_screen_throne.jpeg, native 2752×1552, scale 1.4333)
-----------------------------------------------------------------------------
плита кнопки  292×68 game px  (native x 2104..2522, y 749..847)
фаска угла    14 game px      (нативный срез 20 px под 45°)
рамка         блик 5 + борозда 3 + линия 2  (native 8 / 4 / 3)
шаг плит      85.6 game px, зазор между плитами 18.6
поле          медиана #233F50, яркость p5=39 p50=57 p95=75 (σ≈11)
рамка цвета   блик #7D99A7, борозда #081B2C, линия #2D4957, нижний борт #3F5C6E

СОСТОЯНИЯ (hover / pressed / disabled) — ВЫВОД, НЕ ТРЕБОВАНИЕ МАКЕТА
--------------------------------------------------------------------
В макете 09 нарисовано одно состояние (normal). Остальные выводятся из него
детерминированным преобразованием (см. STATES ниже) и помечены как вывод —
по требованию спеки «Макет молчит о состоянии».

Запуск:  python3 scripts/ui_kit/build_ui_kit.py [--out game/assets/ui/widgets]
Предпросмотр:  python3 scripts/ui_kit/build_ui_kit.py --preview /tmp/kit.png
"""

from __future__ import annotations

import argparse
import json
import math
import os
from datetime import date

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MOCKUP = os.path.join(REPO, "reference", "09_start_screen_throne.jpeg")
SCALE = 1.4333333  # native → game px (2752 / 1920)
SS = 4             # суперсэмпл: гладкие фаски и косые линии

# ─── палитра рамки (сэмплы макета, native) ───────────────────────────────────
C_OUTLINE = (5, 18, 30)      # #05121E внешний тёмный обрез
C_FRAME_TOP = (125, 153, 167)  # #7D99A7 верхний блик металла
C_FRAME_BOT = (44, 68, 84)     # #2C4454 нижний борт: свет сверху, он заметно тусклее верха
C_GROOVE = (8, 27, 44)       # #081B2C борозда между бликом и внутренней линией
C_LINE = (45, 73, 87)        # #2D4957 внутренняя линия рамки
C_FIELD_TOP = (46, 74, 90)   # #2E4A5A поле у верхнего борта
C_FIELD_BOT = (33, 61, 77)   # #213D4D поле у нижнего борта
# Скобка — гравировка, а не мазок кисти: по макету это борозда (темнее поля)
# с тонким бликом верхней кромки. Слой аддитивный, поэтому борозда отрицательная.
C_ORNAMENT = (-16, -20, -24)
C_ORNAMENT_HL = (46, 52, 56)

# Мерка поля: по ней калибруется амплитуда зерна (см. grain())
FIELD_LUM_PERCENTILES = (39.0, 57.0, 75.0)

# Плиты макета 09: верх первой и шаг (native)
PLATE_TOP_Y = 749
PLATE_PITCH = 123
PLATE_FIELD_X = (2130, 2500)


# ─────────────────────────── низкоуровневая геометрия ────────────────────────
def chamfer_path(x0, y0, x1, y1, c):
    """Восьмиугольник — прямоугольник со срезанными углами (фаска c)."""
    c = max(0.0, min(c, (x1 - x0) / 2, (y1 - y0) / 2))
    return [(x0 + c, y0), (x1 - c, y0), (x1, y0 + c), (x1, y1 - c),
            (x1 - c, y1), (x0 + c, y1), (x0, y1 - c), (x0, y0 + c)]


def shape_mask(size, inset, chamfer):
    """L-маска плиты с отступом inset; рисуется в суперсэмпл и сжимается."""
    w, h = size
    big = Image.new("L", (w * SS, h * SS), 0)
    d = ImageDraw.Draw(big)
    pts = [(x * SS, y * SS) for x, y in
           chamfer_path(inset, inset, w - inset, h - inset, max(0.5, chamfer - inset))]
    d.polygon(pts, fill=255)
    return big.resize(size, Image.LANCZOS)


def vgrad(size, top, bottom):
    """Вертикальный градиент RGB."""
    w, h = size
    t = np.linspace(0.0, 1.0, h)[:, None]
    a = np.array(top, dtype=float)
    b = np.array(bottom, dtype=float)
    col = (a + (b - a) * t).astype(np.uint8)
    return np.repeat(col[:, None, :], w, axis=1)


def composite(dst, layer_rgb, mask):
    """layer_rgb поверх dst по маске L."""
    m = np.asarray(mask, dtype=np.float32)[..., None] / 255.0
    return dst * (1 - m) + layer_rgb.astype(np.float32) * m


# ───────────────────────────────── зерно поля ────────────────────────────────
def grain(mockup=MOCKUP, tile=256):
    """Высокочастотное зерно материала поля, снятое с плит макета 09.

    Полосы поля берутся из пяти плит выше и ниже текстовой строки, из них
    вычитается сглаживание (остается фактура, без градиента и JPEG-пятен),
    амплитуда приводится к мерке яркости поля (σ из p5/p50/p95).
    Возвращается (плитка tile×tile со средним 0, провенанс).
    """
    im = np.asarray(Image.open(mockup).convert("RGB"), dtype=np.float32)
    strips = []
    for i in range(5):
        top = PLATE_TOP_Y + i * PLATE_PITCH
        x0, x1 = PLATE_FIELD_X
        for (ya, yb) in ((top + 16, top + 28), (top + 72, top + 82)):
            strips.append(im[ya:yb, x0:x1])
    band = np.concatenate(strips, axis=0)
    lum = band @ np.array([0.299, 0.587, 0.114])
    base = np.asarray(Image.fromarray(lum.astype(np.uint8)).filter(
        ImageFilter.GaussianBlur(6)), dtype=np.float32)
    hp = lum - base
    hp -= hp.mean()
    # σ яркости поля из мерки: (p95 - p5) / 3.29 ≈ σ нормального разброса
    sigma_meas = (FIELD_LUM_PERCENTILES[2] - FIELD_LUM_PERCENTILES[0]) / 3.29
    sigma_raw = float(hp.std()) or 1.0
    hp *= sigma_meas / sigma_raw
    # тайлим отражениями — швов нет ни при каком размере середины плиты
    def reflect(a, n):
        while a.shape[0] < n:
            a = np.concatenate([a, a[::-1]], axis=0)
        while a.shape[1] < n:
            a = np.concatenate([a, a[:, ::-1]], axis=1)
        return a[:n, :n]

    out = reflect(hp.astype(np.float32), tile)
    prov = {
        "source": os.path.relpath(mockup, REPO),
        "strips": [f"y {PLATE_TOP_Y + i * PLATE_PITCH + a}..{PLATE_TOP_Y + i * PLATE_PITCH + b}"
                   for i in range(5) for (a, b) in ((16, 28), (72, 82))],
        "x": list(PLATE_FIELD_X),
        "grain_sigma_raw_px": round(sigma_raw, 2),
        "grain_sigma_applied_px": round(sigma_meas, 2),
    }
    return out, prov


def grain_rgb(size, grain_tile, offset=(0, 0), iso=0.0, seed=7):
    """Зерно (одинаковое по каналам — это рельеф, не цвет) нужного размера.

    iso — доля изотропного шума: сэмпл поля снят узкими горизонтальными
    полосами и один в один даёт полосатость по X, а не фактуру.
    """
    w, h = size
    ox, oy = offset
    g = np.roll(np.roll(grain_tile, oy % grain_tile.shape[0], axis=0),
                ox % grain_tile.shape[1], axis=1)
    reps = (math.ceil(h / g.shape[0]), math.ceil((w + abs(ox)) / g.shape[1]) + 1)
    big = np.tile(g, (reps[0], reps[1]))
    out = big[oy:oy + h, ox:ox + w][..., None].repeat(3, axis=2)
    if iso:
        rng = np.random.default_rng(seed)
        sigma = out.std() or 1.0
        out = out * (1 - iso) + rng.normal(0.0, sigma, out.shape) * iso
    return out


# ─────────────────────────────────── плита ───────────────────────────────────
def plate(size, chamfer, frame=(1, 3, 2, 1, 1), ornament=False,
          grain_tile=None, tint=None, darken=0.0, desat=0.0, pressed=False,
          grain_amp=0.55, iso=0.62):
    """Стальная плита: обрез → блик → борозда → линия → поле.

    frame = (обрез, блик, борозда, линия, поле_отступ) в игровых пикселях.
    tint/darken/desat — выводные состояния (hover/pressed/disabled).
    pressed — на 1 px вниз: верхняя линия темнее, нижняя светлее (плита «утоплена»).
    """
    w, h = size
    cut, shine, groove, line, field = frame
    img = np.zeros((h, w, 3), dtype=np.float32)

    # 1) внешний обрез
    img = composite(img, vgrad(size, C_OUTLINE, C_OUTLINE), shape_mask(size, 0, chamfer))
    # 2) блик металла: сверху ярче, снизу тусклее (свет сверху — мерка 845..846)
    top = C_FRAME_TOP if not pressed else tuple(int(c * 0.72) for c in C_FRAME_TOP)
    bot = C_FRAME_BOT if not pressed else tuple(int(c * 1.18) for c in C_FRAME_BOT)
    band = vgrad((w, h), top, bot)
    if grain_tile is not None:
        band = band + grain_rgb((w, h), grain_tile, iso=iso) * 0.35 * grain_amp
    img = composite(img, band, shape_mask(size, cut, chamfer))
    # 3) борозда
    img = composite(img, vgrad(size, C_GROOVE, C_GROOVE),
                    shape_mask(size, cut + shine, chamfer))
    # 4) внутренняя линия
    img = composite(img, vgrad(size, C_LINE, tuple(int(c * 0.8) for c in C_LINE)),
                    shape_mask(size, cut + shine + groove, chamfer))
    # 5) поле: вертикальный градиент + зерно материала
    f_inset = cut + shine + groove + line
    fld = vgrad(size, C_FIELD_TOP, C_FIELD_BOT)
    if grain_tile is not None:
        fld = fld + grain_rgb((w, h), grain_tile, offset=(f_inset, f_inset), iso=iso) * grain_amp
    img = composite(img, fld, shape_mask(size, f_inset, chamfer))

    if ornament:
        img = img + ornament_layer(size, chamfer, f_inset)

    if tint:  # hover — подсветка материала и рамки
        m = np.asarray(shape_mask(size, 0, chamfer), dtype=np.float32)[..., None] / 255.0
        img = img + np.array(tint, dtype=np.float32) * m
    if desat:
        lum = img @ np.array([0.299, 0.587, 0.114])
        img = img * (1 - desat) + lum[..., None] * desat
    if darken:
        img = img * (1.0 - darken)
    # Фаска — это срезанный угол, а не залитый чёрным: без альфы плита несёт
    # непрозрачный прямоугольник, и на экране в углах тёмные треугольники
    # (замечено на снимке стартового экрана). Маска силуэта — она же сглажена
    # в суперсэмпле, поэтому край фаски остаётся ровным.
    sil = np.asarray(shape_mask(size, 0, chamfer), dtype=np.float32)[..., None]
    return np.clip(np.dstack([img, sil]), 0, 255).astype(np.uint8)


def ornament_layer(size, chamfer, inset):
    """Скобка у торца плиты с шипом внутрь на середине высоты (макет 09).

    Макет крупным планом: скобка угловатая, из отрезков под 45° — тот же угол,
    что у фаски. Кривая Безье превращала её в закорюку и не давала острия.
    Порядок: засечка вдоль внутренней линии → диагональ к рамке → вертикаль →
    шип внутрь на середине высоты → зеркально вниз.
    """
    w, h = size
    big = Image.new("L", (w * SS, h * SS), 0)
    d = ImageDraw.Draw(big)
    lw = max(1, int(round(1.2 * SS)))
    f = inset + 1
    ym = h / 2.0
    tick, arm, spike = 18.0, 13.0, 8.0  # засечка / диагональ / вылет острия
    for mirror in (0, 1):
        def x(v, m=mirror):
            return (f + v) if m == 0 else (w - f - v)
        pts = [(tick, f), (arm - 1.0, f), (1.5, f + arm), (1.5, ym - spike),
               (spike, ym), (1.5, ym + spike), (1.5, h - f - arm),
               (arm - 1.0, h - f), (tick, h - f)]
        d.line([(x(px) * SS, py * SS) for px, py in pts],
               fill=210, width=lw, joint="curve")
    m = np.asarray(big.resize(size, Image.LANCZOS), dtype=np.float32)[..., None] / 255.0
    # Борозда + блик её верхней кромки (свет сверху). Одна светлая линия читается
    # как неон: по замеру скобка макета светлее поля всего на +12…+15.
    hl = np.roll(m, 1, axis=0)
    return (np.array(C_ORNAMENT, dtype=np.float32) * m * 0.9
            + np.array(C_ORNAMENT_HL, dtype=np.float32) * hl * 0.7)


# ─────────────────────────────── состояния-выводы ────────────────────────────
# normal — из макета. Остальные — вывод (в макете 09 одного состояния).
STATES = {
    "normal":   {},
    "hover":    {"tint": (16, 18, 16), "note": "материал и рамка +~18% яркости"},
    "pressed":  {"darken": 0.22, "pressed": True,
                 "note": "−22% яркости, блик перевёрнут (плита утоплена)"},
    "disabled": {"desat": 0.72, "darken": 0.45,
                 "note": "обесцвечено на 72% и затемнено до 55%"},
}


# ───────────────────────────────── сборка ────────────────────────────────────
def save(arr, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    mode = "RGBA" if arr.shape[2] == 4 else "RGB"
    Image.fromarray(arr, mode).save(path, "PNG", optimize=True)


def build(out_dir, preview=None):
    g, gprov = grain()
    man = {
        "generated": str(date.today()),
        "generator": "scripts/ui_kit/build_ui_kit.py",
        "mockup": os.path.relpath(MOCKUP, REPO),
        "measure": {
            "plate_game_px": [292, 68], "chamfer_game_px": 14,
            "frame_px": {"outline": 1, "shine": 4, "groove": 2, "line": 1},
            "pitch_game_px": 85.6, "gap_game_px": 18.6,
            "field_lum_percentiles": list(FIELD_LUM_PERCENTILES),
        },
        "material": gprov,
        "derived_states_note": "hover/pressed/disabled — вывод из normal (макет молчит)",
        "files": {},
    }

    def put(rel, arr, margins, kind, note=""):
        save(arr, os.path.join(out_dir, rel))
        man["files"][rel] = {"size": list(arr.shape[1::-1]), "kind": kind,
                             "texture_margin": margins, "note": note}

    # ── кнопка. Две семьи: базовая (мелкие кнопки сцен: 28…48 px высотой, без
    #    орнамента — он на них рассыпается в закорюки) и MenuPlate — каноничная
    #    плита стартового экрана макета 09 (292×68) со скобкой по торцам.
    for st, spec in STATES.items():
        kw = {k: v for k, v in spec.items() if k != "note"}
        note = spec.get("note", "по макету")
        put(f"buttons/button_{st}.png",
            plate((96, 48), chamfer=10, grain_tile=g, **kw),
            [20, 12, 20, 12], "9-slice", f"состояние {st}; {note}")
        put(f"buttons/button_menu_{st}.png",
            plate((120, 68), chamfer=12, frame=(1, 5, 3, 2, 1), ornament=True,
                  grain_tile=g, **kw),
            [20, 12, 20, 12], "9-slice",
            f"MenuPlate, состояние {st}; {note}; скобка по торцам — мерка макета 09")

    # ── панель / рамка
    put("panels/panel_bg.png", plate((96, 96), chamfer=10, grain_tile=g),
        [12, 12, 12, 12], "9-slice")
    put("panels/slot_bg.png", plate((48, 48), chamfer=6,
                                    frame=(1, 3, 1, 1, 1), grain_tile=g),
        [8, 8, 8, 8], "9-slice")

    # ── полосы: фон и заполнение. Одна заполняющая текстура — одна, которую
    #    тема и ссылается (ProgressBar/styles/fill). Цвета полос боя (зелёный/
    #    синий) из макета 11 придут с шагом 6 вместе с экраном боя; заводить
    #    неиспользуемые файлы сейчас — значит завести мёртвый ассет.
    put("progress_bars/bar_bg.png", plate((40, 20), chamfer=6,
                                          frame=(1, 2, 1, 1, 1), grain_tile=g),
        [8, 8, 8, 8], "9-slice")
    put("progress_bars/fill_health.png", bar_fill((40, 20), (74, 168, 78), g),
        [6, 6, 6, 6], "9-slice",
        "вывод: цвет — зелёная полоса макета 11, форма — рамка темы")

    # ── слайдер
    put("sliders/slider_track.png", plate((40, 14), chamfer=4,
                                          frame=(1, 2, 1, 1, 1), grain_tile=g),
        [6, 6, 6, 6], "9-slice", "вывод: макет слайдера не показывает")
    put("sliders/slider_handle.png", handle((20, 20), g), [0, 0, 0, 0], "иконка",
        "вывод: макет слайдера не показывает")

    # ── чекбокс: квадратная рамка темы + галочка (макет молчит — вывод)
    for name, on in (("checkbox_unchecked", False), ("checkbox_checked", True)):
        put(f"buttons/{name}.png", checkbox((24, 24), on, g), [0, 0, 0, 0], "иконка",
            "вывод: чекбокса в макетах нет, носитель — рамка темы")

    with open(os.path.join(out_dir, "MANIFEST.json"), "w", encoding="utf-8") as fh:
        json.dump(man, fh, ensure_ascii=False, indent=1)
        fh.write("\n")

    if preview:
        make_preview(preview, out_dir)
    return man


def bar_fill(size, col, g):
    """Заполнение полосы: тёмный обрез, светлая кромка, цветное ядро с зерном."""
    w, h = size
    img = composite(np.zeros((h, w, 3), np.float32),
                    vgrad(size, C_OUTLINE, C_OUTLINE), shape_mask(size, 0, 6))
    body = vgrad(size, tuple(min(255, int(c * 1.45)) for c in col),
                 tuple(int(c * 0.72) for c in col))
    body = body + grain_rgb(size, g) * 0.5
    rgb = np.clip(composite(img, body, shape_mask(size, 1, 6)), 0, 255)
    sil = np.asarray(shape_mask(size, 0, 6), np.float32)[..., None]
    return np.clip(np.dstack([rgb, sil]), 0, 255).astype(np.uint8)


def handle(size, g):
    """Рукоятка слайдера: маленькая стальная плита-шайба."""
    return plate(size, chamfer=5, frame=(1, 3, 1, 1, 1), grain_tile=g)


def checkbox(size, checked, g):
    img = plate(size, chamfer=4, frame=(1, 3, 1, 1, 1), grain_tile=g)
    if checked:
        arr = img.astype(np.float32)
        w, h = size
        pts = [(w * 0.24, h * 0.52), (w * 0.42, h * 0.72), (w * 0.78, h * 0.26)]
        big = Image.new("L", (w * SS, h * SS), 0)
        ImageDraw.Draw(big).line([(x * SS, y * SS) for x, y in pts],
                                 fill=255, width=int(2.4 * SS), joint="curve")
        m = np.asarray(big.resize(size, Image.LANCZOS), np.float32)[..., None] / 255.0
        # Альфа силуэта остаётся: размываем только RGB, иначе галочка зальёт срезанные углы.
        rgb = arr[..., :3] * (1 - m) + np.array((158, 119, 56), np.float32) * m
        arr = np.dstack([rgb, arr[..., 3:4]])
        img = np.clip(arr, 0, 255).astype(np.uint8)
    return img


def nine_slice(tex, margins, size):
    """Рендер 9-slice так, как его рисует Godot: углы 1:1, кромки растянуты.

    Нужен для проверки глазами: смотреть PNG текстуры бессмысленно — в игре
    виден только её 9-slice на реальном размере контрола.
    """
    l, t, r, b = margins
    w, h = size
    tw, th = tex.size
    out = Image.new("RGBA", (w, h))
    out.paste(tex.crop((l, t, tw - r, th - b)).resize((max(1, w - l - r), max(1, h - t - b)), Image.BILINEAR), (l, t))
    out.paste(tex.crop((l, 0, tw - r, t)).resize((max(1, w - l - r), t), Image.BILINEAR), (l, 0))
    out.paste(tex.crop((l, th - b, tw - r, th)).resize((max(1, w - l - r), b), Image.BILINEAR), (l, h - b))
    out.paste(tex.crop((0, t, l, th - b)).resize((l, max(1, h - t - b)), Image.BILINEAR), (0, t))
    out.paste(tex.crop((tw - r, t, tw, th - b)).resize((r, max(1, h - t - b)), Image.BILINEAR), (w - r, t))
    out.paste(tex.crop((0, 0, l, t)), (0, 0))
    out.paste(tex.crop((tw - r, 0, tw, t)), (w - r, 0))
    out.paste(tex.crop((0, th - b, l, th)), (0, h - b))
    out.paste(tex.crop((tw - r, th - b, tw, th)), (w - r, h - b))
    return out


def make_preview(path, out_dir):
    """Контактный лист: 9-slice состояний на каноничной плите + рядом макет."""
    tex = Image.open(os.path.join(out_dir, "buttons/button_menu_normal.png")).convert("RGBA")
    rows = [Image.open(os.path.join(out_dir, f"buttons/button_menu_{st}.png")).convert("RGBA")
            for st in STATES]
    cw, ch = 292, 68
    mk = Image.open(MOCKUP).convert("RGB").crop((2090, 735, 2540, 865))
    sheet = Image.new("RGB", (cw + 40, (ch + 12) * (len(rows) + 1) + 130), (12, 10, 8))
    sheet.paste(mk.resize((cw, int(mk.height * cw / mk.width)), Image.LANCZOS), (20, 10))
    y = 130
    for st, t in zip(STATES, rows):
        ns = nine_slice(t, (20, 12, 20, 12), (cw, ch))
        sheet.paste(ns, (20, y), ns)  # по альфе: срезанные углы видны фоном
        y += ch + 12
    sheet.save(path)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(REPO, "game", "assets", "ui", "widgets"))
    ap.add_argument("--preview")
    a = ap.parse_args()
    m = build(a.out, a.preview)
    print(f"файлов: {len(m['files'])} → {a.out}")

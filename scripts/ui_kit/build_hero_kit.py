#!/usr/bin/env python3
"""Генератор носителей экрана «Герой» — D-278 (макет 12, пергамент+латунь).

Тот же стиль, что `build_ui_kit.py` (макет 09): векторная геометрия + зерно из
замера, диффузии нет (D-275). Отличия носителя: светлое поле (пергамент),
рваный край панелей, квадратные клетки со скруглением, плитки ×/?.

Числа — замер `reference/12_inventory_parchment_sheet.jpeg` (2816×1584;
масштаб на канву 1600×900 = ×0.5682). Образцы (координаты — пиксели макета):

    поле пергамента   окно x 808..862, y 1060..1530   #DACAB9, σ=8
    пергамент у текста/в тени                          #BDA285 (тот же шум, тень)
    край пергамента   рваный, тень по контуру          #6B523A
    латунь рамки      низ рамки портрета y 604..616    свет #C39B78,
                                                       среднее #966E4B,
                                                       тень #3C2818
    интерьер клетки   пустая клетка y 1420..1520       #1B1918, σ=7
    фон центральный   x 905..995, y 60..690 (камень)   #201919, σ=35
    полоса HP         карточка 1, y 382..386           #981C20 (блик #BC5D61)
    полоса маны       карточка 1, y 406..414           #1589C3 (блик #33A9D5)

Артефакты — PNG + MANIFEST.json (kind/размер/провенанс). Проверка носителей —
`scripts/check_ui_assets.py` (в области просмотра добавлен каталог `hero/`).
Размеры — канва 1600×900.
"""

import json
import os
import random

from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                    os.pardir, os.pardir,
                                    "game", "assets", "ui", "hero"))

# ─── палитра: значения замера макета 12 (провенанс — docstring) ────────────
PARCH = (218, 202, 185)      # #DACAB9 поле пергамента
PARCH_EDGE = (107, 82, 58)   # #6B523A рваный край/тень
BRASS_HI = (195, 155, 120)   # #C39B78 блик латуни
BRASS = (150, 110, 75)       # #966E4B среднее латуни
BRASS_DARK = (60, 40, 24)    # #3C2818 тень латуни
STONE = (32, 25, 25)         # #201919 фон центральной колонки
CELL = (27, 25, 24)          # #1B1918 интерьер клетки
HP = (152, 28, 32)           # #981C20
HP_HI = (188, 93, 97)        # #BC5D61
MANA = (21, 137, 195)        # #1589C3
MANA_HI = (51, 169, 213)     # #33A9D5


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def grain(size, base, sigma, seed):
    """Зерно носителя: гауссов шум вокруг базового цвета (σ — замер макета)."""
    rnd = random.Random(seed)
    w, h = size
    im = Image.new("RGBA", (w, h))
    px = im.load()
    for y in range(h):
        for x in range(w):
            c = [max(0, min(255, int(base[i] + rnd.gauss(0, sigma)))) for i in range(3)]
            px[x, y] = (c[0], c[1], c[2], 255)
    return im


def chamfer(size, rad, aa=2.0):
    """Маска скруглённых углов: наружу — alpha 0, кромка AA ~2 px (правило (c):
    косая кромка — дизайн, а не ореол; порог зафиксирован проверкой)."""
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1],
                                           radius=rad, fill=255)
    return mask.filter(ImageFilter.GaussianBlur(aa / 2.0))


def apply_mask(im, mask):
    im.putalpha(Image.composite(mask, Image.new("L", im.size, 0), mask))
    return im


def brass_edge(d, size, rad, thick=3):
    """Латунная рамка по контуру: блик → среднее → тень (замер профиля рамки)."""
    w, h = size
    d.rounded_rectangle([0, 0, w - 1, h - 1], radius=rad, fill=BRASS_HI + (255,))
    d.rounded_rectangle([1, 1, w - 2, h - 2], radius=rad, fill=BRASS + (255,))
    d.rounded_rectangle([thick, thick, w - 1 - thick, h - 1 - thick],
                        radius=max(2, rad - thick), fill=BRASS_DARK + (255,))


def brass_grain(im, seed, band=None, density=2.0):
    """Продольное зерно латуни: тёмные/светлые точки в полосе рамки."""
    w, h = im.size
    band = band if band is not None else 6
    rnd = random.Random(seed)
    d = ImageDraw.Draw(im)
    px = im.load()
    for _ in range(int(density * 2 * (w + h))):
        if rnd.random() < 0.5:
            x, y = rnd.randrange(w), rnd.choice([rnd.randrange(band),
                                                 h - 1 - rnd.randrange(band)])
        else:
            x, y = rnd.choice([rnd.randrange(band), w - 1 - rnd.randrange(band)]), rnd.randrange(h)
        if min(x, y, w - 1 - x, h - 1 - y) < band and px[x, y][3] > 200:
            d.point((x, y), fill=mix(BRASS_HI, BRASS_DARK, rnd.random()) + (255,))


def save(name, im, meta):
    im.save(os.path.join(OUT, name))
    print("  %-24s %sx%s" % (name, im.size[0], im.size[1]))
    return meta


def panel(name, size, margin, field, sigma, edge, rad, seed):
    """9-slice панель: поле с зерном + кромка ('brass' | 'torn').

    Проверка (a): углы прозрачны; (b): центр 50%×50% однороден (σ < 28).
    """
    w, h = size
    body = grain(size, field, sigma, seed)
    d = ImageDraw.Draw(body)
    if edge == "torn":
        # Рваный край пергамента (макет 12): тёмная неровная кромка + латунь.
        rnd = random.Random(seed + 7)
        d.rounded_rectangle([0, 0, w - 1, h - 1], radius=rad, fill=PARCH_EDGE + (255,))
        for _ in range(int((w + h) / 3)):
            side = rnd.randrange(4)
            j = rnd.randrange(5) + 1
            if side == 0:
                x, y = rnd.randrange(w), j
            elif side == 1:
                x, y = rnd.randrange(w), h - 1 - j
            elif side == 2:
                x, y = j, rnd.randrange(h)
            else:
                x, y = w - 1 - j, rnd.randrange(h)
            r = rnd.randrange(2, 5)
            d.ellipse([x - r, y - r, x + r, y + r], fill=(0, 0, 0, 0))
        d.rounded_rectangle([7, 7, w - 8, h - 8], radius=max(2, rad - 7),
                            fill=field + (255,))
        d.rounded_rectangle([7, 7, w - 8, h - 8], radius=max(2, rad - 7),
                            outline=BRASS, width=2)
        band = 9
    else:
        brass_edge(d, size, rad, thick=3)
        d.rounded_rectangle([6, 6, w - 7, h - 7], radius=max(2, rad - 6),
                            fill=field + (255,))
        band = 6
    brass_grain(body, seed + 1, band=band)
    return save(name, apply_mask(body, chamfer(size, rad)),
                {"kind": "9-slice", "size": [w, h], "margin": margin,
                 "source": "макет 12: %s (замер в docstring билдера)"
                           % ("пергамент, рваный край" if edge == "torn"
                              else "тёмный камень, латунная рамка"),
                 "note": name})


def frame9(name, size, margin, thick, rad, seed):
    """Латунная рамка с прозрачным центром (портрет, карточка, слот, строка)."""
    w, h = size
    im = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([0, 0, w - 1, h - 1], radius=rad, fill=BRASS_HI + (255,))
    d.rounded_rectangle([1, 1, w - 2, h - 2], radius=rad, fill=BRASS + (255,))
    d.rounded_rectangle([thick - 1, thick - 1, w - thick, h - thick],
                        radius=max(2, rad - thick + 1), fill=BRASS_DARK + (255,))
    rnd = random.Random(seed)
    for _ in range(int(2 * (w + h))):
        x = rnd.choice([rnd.randrange(thick), w - 1 - rnd.randrange(thick),
                        rnd.randrange(w), rnd.randrange(w)])
        y = rnd.choice([rnd.randrange(thick), h - 1 - rnd.randrange(thick),
                        rnd.randrange(h), rnd.randrange(h)])
        if min(x, y, w - 1 - x, h - 1 - y) < thick:
            d.point((x, y), fill=mix(BRASS_HI, BRASS_DARK, rnd.random()) + (255,))
    return save(name, apply_mask(im, chamfer(size, rad)),
                {"kind": "frame", "size": [w, h], "margin": margin,
                 "source": "макет 12: латунная рамка (замер в docstring)",
                 "note": name})


def grid_cell(name, size, margin, seed):
    """Клетка сетки: тёмный интерьер #1B1918, латунная рамка, скруглённые углы."""
    w, h = size
    body = grain(size, CELL, 7, seed)
    d = ImageDraw.Draw(body)
    d.rounded_rectangle([0, 0, w - 1, h - 1], radius=14, fill=BRASS_HI + (255,))
    d.rounded_rectangle([1, 1, w - 2, h - 2], radius=13, fill=BRASS + (255,))
    d.rounded_rectangle([3, 3, w - 4, h - 4], radius=12, fill=BRASS_DARK + (255,))
    d.rounded_rectangle([margin, margin, w - 1 - margin, h - 1 - margin],
                        radius=9, fill=CELL + (255,))
    brass_grain(body, seed + 1, band=margin)
    return save(name, apply_mask(body, chamfer(size, 14)),
                {"kind": "9-slice", "size": [w, h], "margin": margin,
                 "source": "макет 12: клетка сетки (замер в docstring)",
                 "note": name})


def bar(name, size, fill, hi, seed):
    """Филл полосы: блик сверху, тень снизу, AA-кромка 2 px (правило (c))."""
    w, h = size
    rad = (h - 2) // 2
    im = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for y in range(h):
        t = y / max(1, h - 1)
        c = mix(hi, fill, min(1.0, t * 2.0)) if t < 0.5 else mix(fill, (12, 12, 14), (t - 0.5) * 1.1)
        d.line([(0, y), (w - 1, y)], fill=c + (255,))
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([1, 1, w - 2, h - 2], radius=rad, fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(0.8))
    return save(name, apply_mask(im, mask),
                {"kind": "bar", "size": [w, h],
                 "source": "макет 12: полоса карточки (замер в docstring)",
                 "note": name})


def track(name, size, seed):
    """Жёлоб полосы: тёмное дно в латунной окантовке (макет: полосы в латуни)."""
    w, h = size
    rad = (h - 1) // 2
    im = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([0, 0, w - 1, h - 1], radius=rad, fill=BRASS + (255,))
    d.rounded_rectangle([1, 1, w - 2, h - 2], radius=max(1, rad - 1), fill=(12, 11, 11, 255))
    return save(name, apply_mask(im, chamfer(size, rad, aa=1.0)),
                {"kind": "track", "size": [w, h],
                 "source": "макет 12: жёлоб полосы", "note": name})


def rule(name, size, seed):
    """Латунный разделитель (тянется по X)."""
    w, h = size
    im = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    rnd = random.Random(seed)
    for y in range(h):
        t = y / max(1, h - 1)
        c = mix(BRASS_HI, BRASS_DARK, min(1.0, t * 1.5))
        for x in range(w):
            d.point((x, y), fill=mix(c, BRASS_DARK, rnd.random() * 0.3) + (255,))
    return save(name, apply_mask(im, chamfer(size, 2, aa=0.6)),
                {"kind": "rule", "size": [w, h],
                 "source": "макет 12: разделитель (замер в docstring)",
                 "note": name})


def tile(name, side, margin, seed):
    """Квадратная латунная плитка (кнопки ×/?): скруглённые углы, тёмное дно."""
    size = (side, side)
    w = h = side
    im = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([0, 0, w - 1, h - 1], radius=10, fill=BRASS_HI + (255,))
    d.rounded_rectangle([2, 2, w - 3, h - 3], radius=9, fill=BRASS + (255,))
    d.rounded_rectangle([4, 4, w - 5, h - 5], radius=8, fill=BRASS_DARK + (255,))
    body = grain((w - 12, h - 12), STONE, 9, seed)
    im.alpha_composite(body, (6, 6))
    brass_grain(im, seed + 3, band=6)
    return save(name, apply_mask(im, chamfer(size, 10)),
                {"kind": "9-slice", "size": [w, h], "margin": margin,
                 "source": "макет 12: плитка кнопки ×/? (замер в docstring)",
                 "note": name})


def main():
    os.makedirs(OUT, exist_ok=True)
    print("build_hero_kit → game/assets/ui/hero/")
    files = {}

    def put(name, meta):
        files["%s/%s" % ("hero", name)] = meta

    put("panel_parchment.png",
        panel("panel_parchment.png", (256, 256), 48, PARCH, 8, "torn", 26, 2))
    put("panel_stone.png",
        panel("panel_stone.png", (256, 256), 40, STONE, 22, "brass", 20, 4))
    put("banner_name.png",
        panel("banner_name.png", (256, 96), 36, PARCH, 8, "brass", 14, 6))
    put("frame_portrait.png", frame9("frame_portrait.png", (128, 128), 26, 10, 12, 8))
    put("frame_card.png", frame9("frame_card.png", (160, 120), 30, 9, 12, 10))
    put("slot_doll.png", frame9("slot_doll.png", (96, 96), 22, 8, 14, 12))
    put("frame_row.png", frame9("frame_row.png", (96, 96), 20, 7, 12, 14))
    put("cell_grid.png", grid_cell("cell_grid.png", (96, 96), 14, 16))
    put("bar_hp.png", bar("bar_hp.png", (12, 12), HP, HP_HI, 18))
    put("bar_mana.png", bar("bar_mana.png", (12, 12), MANA, MANA_HI, 20))
    put("bar_track.png", track("bar_track.png", (12, 12), 22))
    put("rule_brass.png", rule("rule_brass.png", (16, 8), 24))
    put("tile_brass.png", tile("tile_brass.png", 64, 12, 26))

    # Юзер-арт экран поднимает из старого плейсхолдера (тот же экран UI-2):
    # генератор их не пишет, но MANIFEST обязан их описывать — иначе гард
    # носителей ругается «файл не в MANIFEST.json». Замена арта — UI-6.
    # `banner.png`/`mini.png` из этого списка сняты актом инвентаря T-247: ни один
    # узел и ни один скрипт их не читал (grep по имени и по пути, §8 карты), файлы
    # удалены из репозитория вместе со строками MANIFEST. Возвращать их сюда можно
    # только вместе с узлом-потребителем.
    for legacy, size, note in (
            ("portrait.png", [80, 80], "плейсхолдер портрета (замена — UI-6)"),
            ("figure.png", [240, 360], "плейсхолдер фигуры героя (замена — UI-6)")):
        put(legacy, {"kind": "image", "size": size, "source": "плейсхолдер UI-2", "note": note})

    manifest = {
        "mockup": "reference/12_inventory_parchment_sheet.jpeg",
        "generator": "scripts/ui_kit/build_hero_kit.py",
        "scale": "макет 2816×1584 → канва 1600×900 (×0.5682)",
        "method": "векторная геометрия + зерно из замера, без диффузии (D-275)",
        "note": "носители экрана «Герой» (D-278). Марджины 9-slice — в px "
                "носителя; в сцене TextureRect растягивает крайнюю полосу под "
                "фактический размер (пересчёт в hero_layout.gd).",
        "files": files,
    }
    with open(os.path.join(OUT, "MANIFEST.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=1)
    print("MANIFEST.json: %d файлов" % len(files))


if __name__ == "__main__":
    main()

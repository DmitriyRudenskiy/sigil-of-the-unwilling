#!/usr/bin/env python3
"""Медальон нижней панели боя (макет 11): пластина в четыре состояния + эмблемы.

Макет 11 ставит нижний ряд боя не на плашки-плиты макета 09, а на кованые
медальоны: тёмная пластина в широком бронзовом ободе с тонкой золотой нитью, в
cентре — золотая эмблема. Первый вариант этого файла (2026-10-21) рисовал светлый
обод и пустую пластину, а роль эмблемы играл цветной emoji из текста кнопки: на
снимке сравнения с макетом это читалось как чужой UI. Теперь пластина и эмблема —
ассет, кнопка несёт только иконку.

Замеры сняты с `reference/11_battle_hex_snow.jpeg` (2816×1584) числовым разрезом
по медальону «Menu» — горизонталью через центр (128, 1462). Внешний радиус
медальона 57 px, диаметр 114 px при ширине кадра 2816 = 78 px на 1920. В сцене
стоит контрол 100 px при шаге ряда 120 px (принято вторым проходом зрения §5),
геометрия ряда эта правка не трогает. Текстура — 144 px (медальон занимает канву целиком, запас 6 px
под сдвиг нажатого состояния), рисуется в 4× и даунсэмплируется: на 144 круг зубчится.

Запуск: python3 game/scripts/ui_kit/build_round_button.py
"""

from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw

REPO = Path(__file__).resolve().parents[2]
OUT_BUTTONS = REPO / "assets/ui/widgets/buttons"
OUT_EMBLEMS = REPO / "assets/ui/widgets/emblems"

CANVAS = 144
SS = 4  # суперсэмплинг
C = CANVAS / 2

# Радиусы — доля внешнего радиуса медальона. Разрез горизонталью через центр
# медальона «Menu» (128, 1462, кадр 2816×1584), внешний радиус R = 57 px:
#
#   r 57..46   бронзовое кольцо    (116, 88, 64) … (90, 68, 45)
#   r 45..44   золотая нить        (157, 138, 121)
#   r 43..40   тёмная разделка     (16, 2, 1)
#   r 39..20   пластина            (55, 45, 44) … (48, 52, 55)
#   r 19..0    золото эмблемы      (197, 155, 95) … (202, 157, 98)
#
# Паза между ободом и нитью в макете нет — нить сидит под самим ободом. Первый
# вариант разреза посчитал медальон вместе с тенью (R = 81 вместо 57) и занижал
# обод вдвое: кольцо выходило 8% радиуса против макетных 19%.
# Диаметр 114 px при ширине кадра 2816 = 78 px на 1920; в сцене контрол 100 px
# при шаге 120 px (второй проход зрения §5), геометрия ряда этой правкой не
# трогается.
R_OUTER = 66.0
RINGS = [
    # (внешний r, внутренний r, база)
    (1.000, 0.960, (58, 42, 30)),     # тёмный внешний край — без него обод светит по силуэту
    (0.960, 0.810, (116, 88, 64)),    # бронзовое кольцо — 19% радиуса, как в макете
    (0.810, 0.770, (172, 146, 116)),  # золотая нить
    (0.770, 0.735, (18, 12, 9)),      # тёмная разделка между нитью и пластиной
]
R_PLATE = 0.735
PLATE_TOP = (74, 63, 54)
PLATE_BOTTOM = (44, 36, 31)
PLATE_EDGE = (20, 15, 12)

# Золото эмблемы — по замеру разреза: (197, 155, 95), подсветка (202, 157, 98).
# Первый вариант (185, 138, 78) давал на рендере (151, 111, 66) — мутную бронзу,
# на фоне которой пластина читалась светлее металла, а не наоборот.
GOLD = (198, 152, 92)
GOLD_LIGHT = (233, 198, 140)
GOLD_DARK = (146, 102, 54)
GOLD_SHADOW = (28, 13, 3)

# 0.55 внешнего радиуса = 0.75 радиуса пластины: в макете эмблема занимает
# пластину почти целиком (размах «Menu» 64 px при пластине 86 px).
R_EMBLEM = 0.55


def _mix(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def _bright(k: float):
    return lambda v: min(255, round(v * k))


def _canvas() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    img = Image.new("RGBA", (CANVAS * SS, CANVAS * SS), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def _s(v: float) -> float:
    return v * SS


def _disc(d, r: float, color, center=(C, C)) -> None:
    cx, cy = center
    d.ellipse([_s(cx - r), _s(cy - r), _s(cx + r), _s(cy + r)], fill=(*color, 255))


def _arc(img: Image.Image, r: float, width: float, color, a0: float, a1: float, alpha: int, center=(C, C)) -> None:
    """Дуга с альфай: ImageDraw пишет пиксели напрямую, без блендинга, поэтому
    полупрозрачная фаска рисуется отдельным слоем и композится."""
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx, cy = center
    box = [_s(cx - r), _s(cy - r), _s(cx + r), _s(cy + r)]
    d.arc(box, a0, a1, fill=(*color, alpha), width=int(_s(width)))
    img.alpha_composite(layer)


def _bevel(img: Image.Image, mid: float, w: float, color, lit: bool) -> None:
    """Фаска кольца тремя дугами разной ширины угла и нарастающей альфой:
    одна дуга с резким краём читается ступенькой на готовом рендере."""
    # верх кольца = 180°..360° (у PIL 0° вправо, 270° вверх); сужающиеся дуги
    # с растущей альфой дают плавный переход вместо ступеньки
    steps = [(188, 352, 45), (196, 344, 75), (206, 334, 115)] if lit else [(8, 172, 55), (16, 164, 90), (26, 154, 130)]
    for a0, a1, alpha in steps:
        # 0.26: при 0.42 верхний край обода выбеливался в воск — макетное золото
        # тёплое и тёмное, белого блика по всему полукругу в нём нет
        tone = _mix(color, (255, 240, 218), 0.20) if lit else _mix(color, (8, 5, 2), 0.55)
        _arc(img, mid, w, tone, a0, a1, alpha)


def _plate(size_r: float) -> Image.Image:
    """Пластина: сверху освещена, к низу уходит в тень; по верхнему краю —
    внутренняя тень, потому что пластина утоплена в ободе."""
    size = (CANVAS * SS, CANVAS * SS)
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = R_OUTER * size_r
    box = [_s(C - r), _s(C - r), _s(C + r), _s(C + r)]
    for i in range(int(_s(2 * r))):
        t = i / max(1, int(_s(2 * r)) - 1)
        d.line(
            [_s(C - r), _s(C - r) + i, _s(C + r), _s(C - r) + i],
            fill=(*_mix(PLATE_TOP, PLATE_BOTTOM, t), 255),
        )
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).ellipse(box, fill=255)
    img.putalpha(mask)

    # Тень — кольцом от кромки пластины к центру: пластина утоплена в ободе, и
    # обод кладёт тень по всему периметру. Первый вариант гасил полукругом сверху,
    # и верх пластины выходил темнее низа — светотень наоборот (в макете свет
    # сверху: (55, 45, 44) вверху против (48, 52, 55) у нижнего края).
    inner = Image.new("RGBA", size, (0, 0, 0, 0))
    d2 = ImageDraw.Draw(inner)
    band = _s(r * 0.26)
    for i in range(int(band)):
        rr = r - i / SS
        alpha = int(190 * (1 - i / band) ** 2)
        d2.ellipse([_s(C - rr), _s(C - rr), _s(C + rr), _s(C + rr)],
                   outline=(*PLATE_EDGE, alpha), width=2)
    img.alpha_composite(inner)
    return img


def build_plate() -> Image.Image:
    img, d = _canvas()
    for r_out, r_in, color in RINGS:
        _disc(d, R_OUTER * r_out, color)
    img.alpha_composite(_plate(R_PLATE))
    # фаска: верх кольца светит, низ в тени (свет в макете сверху-слева);
    # кладётся поверх пластины — дуги не заходят за mid±w/2, пластина мельче
    for r_out, r_in, color in RINGS:
        # тёмные пазы не подсвечиваем; тонкие кольца (нить, разделка) — тоже:
        # фаска по ширине размазывала нить в бледную полосу
        if color[0] < 60 or (r_out - r_in) < 0.06:
            continue
        _bevel(img, (r_out + r_in) / 2 * R_OUTER, (r_out - r_in) * R_OUTER, color, lit=True)
        _bevel(img, (r_out + r_in) / 2 * R_OUTER, (r_out - r_in) * R_OUTER, color, lit=False)
    return img.resize((CANVAS, CANVAS), Image.LANCZOS)


def _state(normal: Image.Image, state: str) -> Image.Image:
    r, g, b, a = normal.split()
    if state == "hover":
        k = 1.16
    elif state == "pressed":
        k = 0.70
    elif state == "disabled":
        gray = Image.merge("RGB", (r, g, b)).convert("L").convert("RGB")
        dim = Image.merge("RGBA", (*[ch.point(_bright(0.6)) for ch in gray.split()], a.point(lambda v: round(v * 0.66))))
        return dim
    else:
        return normal
    out = Image.merge("RGBA", (r.point(_bright(k)), g.point(_bright(k)), b.point(_bright(k)), a))
    if state == "pressed":
        shifted = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
        shifted.paste(out, (0, 3))
        return shifted
    return out


# --- эмблемы ---------------------------------------------------------------
# Каждая рисуется маской в канве 144, вписанной в радиус R_EMBLEM*R_OUTER (=29 px):
# ON=255 — металл, OFF=0 — прорезь. Форма потом заливается золотым градиентом и
# кладётся на тёмную тень со смещением — как в макете: металл лежит на пластине.

ON, OFF = 255, 0


def _m_gear(d, r):
    d.ellipse([-r, -r, r, r], fill=ON)
    for i in range(8):
        a = math.radians(i * 45)
        x, y = math.cos(a) * r * 0.86, math.sin(a) * r * 0.86
        d.ellipse([x - r * 0.26, y - r * 0.26, x + r * 0.26, y + r * 0.26], fill=ON)
    d.ellipse([-r * 0.34, -r * 0.34, r * 0.34, r * 0.34], fill=OFF)


def _m_flag(d, r):
    d.rounded_rectangle([-r * 0.74, -r * 0.96, -r * 0.44, r * 0.96], radius=_s(1.2), fill=ON)
    d.polygon(
        [(-r * 0.5, -r * 0.92), (r * 0.88, -r * 0.5), (-r * 0.5, -r * 0.06)],
        fill=ON,
    )
    d.ellipse([-r * 0.88, -r * 1.08, -r * 0.30, -r * 0.76], fill=ON)


def _m_ring(d, r):
    d.ellipse([-r, -r, r, r], fill=ON)
    d.ellipse([-r * 0.52, -r * 0.52, r * 0.52, r * 0.52], fill=OFF)
    for i in range(4):
        a = math.radians(45 + i * 90)
        x, y = math.cos(a) * r * 0.76, math.sin(a) * r * 0.76
        d.ellipse([x - r * 0.16, y - r * 0.16, x + r * 0.16, y + r * 0.16], fill=OFF)


def _m_swords(d, r):
    for s in (-1, 1):
        d.line([-r * 0.70 * s, r * 0.76, r * 0.60 * s, -r * 0.86], fill=ON, width=int(_s(3.4)))
        d.line([-r * 0.34 * s, r * 0.44, -r * 0.80 * s, r * 0.14], fill=ON, width=int(_s(2.4)))
        x, y = r * 0.78 * s, r * 0.84
        d.ellipse([x - r * 0.16, y - r * 0.16, x + r * 0.16, y + r * 0.16], fill=ON)


def _m_book(d, r):
    # раскрытая книга: две страницы с зазором на корешке и толстыми строками
    d.polygon([(-r * 0.98, -r * 0.44), (-r * 0.08, -r * 0.74), (-r * 0.08, r * 0.70), (-r * 0.98, r * 0.40)], fill=ON)
    d.polygon([(r * 0.98, -r * 0.44), (r * 0.08, -r * 0.74), (r * 0.08, r * 0.70), (r * 0.98, r * 0.40)], fill=ON)
    for i in range(3):
        y = -r * 0.16 + i * r * 0.34
        d.line([-r * 0.80, y, -r * 0.24, y - r * 0.12], fill=OFF, width=int(_s(1.6)))
        d.line([r * 0.80, y, r * 0.24, y - r * 0.12], fill=OFF, width=int(_s(1.6)))


def _m_hourglass(d, r):
    d.rounded_rectangle([-r * 0.80, -r * 1.00, r * 0.80, -r * 0.70], radius=_s(1.0), fill=ON)
    d.rounded_rectangle([-r * 0.80, r * 0.70, r * 0.80, r * 1.00], radius=_s(1.0), fill=ON)
    d.polygon([(-r * 0.62, -r * 0.62), (r * 0.62, -r * 0.62), (r * 0.06, 0)], fill=ON)
    d.polygon([(-r * 0.62, r * 0.62), (r * 0.62, r * 0.62), (-r * 0.06, 0)], fill=ON)


def _m_shield(d, r):
    d.polygon(
        [(-r * 0.82, -r * 0.72), (0, -r * 0.98), (r * 0.82, -r * 0.72),
         (r * 0.66, r * 0.34), (0, r * 0.98), (-r * 0.66, r * 0.34)],
        fill=ON,
    )
    d.line([0, -r * 0.84, 0, r * 0.84], fill=OFF, width=int(_s(1.4)))
    d.ellipse([-r * 0.2, -r * 0.2, r * 0.2, r * 0.2], fill=OFF)


def _m_skip(d, r):
    for off in (-0.52, 0.34):
        d.polygon(
            [(r * off, -r * 0.86), (r * (off + 0.62), 0), (r * off, r * 0.86),
             (r * (off - 0.16), r * 0.86), (r * (off + 0.46), 0), (r * (off - 0.16), -r * 0.86)],
            fill=ON,
        )


EMBLEMS = {
    "gear": _m_gear,
    "flag": _m_flag,
    "ring": _m_ring,
    "swords": _m_swords,
    "book": _m_book,
    "hourglass": _m_hourglass,
    "shield": _m_shield,
    "skip": _m_skip,
}


class _ShiftedDraw:
    """Прокси ImageDraw: эмблемы рисуются в координатах от центра, а PIL рисует
    от угла. Прокси сдвигает коробочки (плоские и точечные) на центр канвы."""

    def __init__(self, draw, dx, dy):
        self.d, self.dx, self.dy = draw, dx, dy

    def _box(self, box):
        return [box[0] + self.dx, box[1] + self.dy, box[2] + self.dx, box[3] + self.dy]

    def _pts(self, pts):
        if pts and not isinstance(pts[0], (tuple, list)):
            # плоский список [x0, y0, x1, y1, …] — его использует line
            return [(pts[i] + self.dx, pts[i + 1] + self.dy) for i in range(0, len(pts), 2)]
        return [(x + self.dx, y + self.dy) for x, y in pts]

    def ellipse(self, box, fill=None, width=1):
        self.d.ellipse(self._box(box), fill=fill, width=width)

    def circle(self, xy, radius, fill=None, outline=None, width=1):
        self.d.circle((xy[0] + self.dx, xy[1] + self.dy), radius, fill=fill, outline=outline, width=width)

    def rounded_rectangle(self, box, radius=0, fill=None, width=1):
        self.d.rounded_rectangle(self._box(box), radius=radius, fill=fill, width=width)

    def polygon(self, pts, fill=None):
        self.d.polygon(self._pts(pts), fill=fill)

    def line(self, pts, fill=None, width=1):
        self.d.line(self._pts(pts), fill=fill, width=width)


def build_emblem(fn) -> Image.Image:
    """Эмблема: маска формы → золотой градиент + тень со смещением."""
    size = (CANVAS * SS, CANVAS * SS)
    mask = Image.new("L", size, 0)
    fn(_ShiftedDraw(ImageDraw.Draw(mask), size[0] / 2, size[1] / 2), _s(R_EMBLEM * R_OUTER))

    # Градиент — по высоте самой эмблемы, а не канвы: на канве в форму попадала
    # средняя треть диапазона и металл выходил плоским
    grad = Image.new("RGBA", size, (0, 0, 0, 0))
    top, bottom = GOLD_LIGHT, GOLD_DARK
    r_px = _s(R_EMBLEM * R_OUTER)
    y0, y1 = _s(C) - r_px, _s(C) + r_px
    for i in range(size[1]):
        t = min(1.0, max(0.0, (i - y0) / max(1.0, y1 - y0)))
        grad.paste((*_mix(top, bottom, t), 255), (0, i, size[0], i + 1))

    out = Image.new("RGBA", size, (0, 0, 0, 0))
    shadow = Image.new("RGBA", size, (*GOLD_SHADOW, 210))
    off = Image.new("L", size, 0)
    off.paste(mask, (int(_s(1.6)), int(_s(2.0))))
    out.paste(shadow, (0, 0), off)
    body = Image.new("RGBA", size, (0, 0, 0, 0))
    body.paste(grad, (0, 0), mask)
    out.alpha_composite(body)
    return out.resize((CANVAS, CANVAS), Image.LANCZOS)


EMBLEM_USE = {
    "gear": "settings_btn — «Меню»",
    "flag": "retreat_btn — «Отступить»",
    "ring": "rescue_btn — «Спасение»",
    "swords": "attack_btn — «Атака»",
    "book": "spellbook_btn — «Книга»",
    "hourglass": "wait_btn — «Ждать»",
    "shield": "defend_btn — «Защита»",
    "skip": "skip_btn — «Пропуск»",
}


def main() -> None:
    OUT_BUTTONS.mkdir(parents=True, exist_ok=True)
    OUT_EMBLEMS.mkdir(parents=True, exist_ok=True)

    normal = build_plate()
    written = []
    for state in ("normal", "hover", "pressed", "disabled"):
        name = f"button_round_{state}.png"
        _state(normal, state).save(OUT_BUTTONS / name)
        written.append(name)

    emblems = []
    for name, fn in EMBLEMS.items():
        build_emblem(fn).save(OUT_EMBLEMS / f"emblem_{name}.png")
        emblems.append(f"emblem_{name}.png")

    manifest_path = OUT_BUTTONS.parent / "MANIFEST.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8")) if manifest_path.exists() else {}
    files = manifest.setdefault("files", {})

    plate_note = (
        "круглый медальон нижней панели боя (макет 11); генератор "
        "scripts/ui_kit/build_round_button.py; радиусы — числовой разрез макета по "
        "медальону «Menu» (бронзовое кольцо 1.00..0.90, паз 0.90..0.82, золотая "
        "нить 0.82..0.78, тёмное кольцо 0.78..0.66, пластина 0.66..0); носитель "
        "квадратный, рисуется целиком (без 9-slice): у круга нет фаски, которую "
        "можно размазать, а контрол фиксированный квадратный; состояние "
    )
    state_tails = {
        "normal": "normal — эталонная текстура, снята с макета",
        "hover": "hover — вывод: +16% яркости (макет показывает только normal)",
        "pressed": "pressed — вывод: −30% яркости и сдвиг на 3 px вниз (макет показывает только normal)",
        "disabled": "disabled — вывод: обесцвечено и затемнено до 60%, альфа 66% (макет показывает только normal)",
    }
    for state, tail in state_tails.items():
        files[f"buttons/button_round_{state}.png"] = {
            "size": [CANVAS, CANVAS],
            "kind": "full-bleed",
            "note": plate_note + tail,
        }

    emblem_note = (
        "золотая эмблема медальона нижней панели боя (макет 11) — иконка кнопки "
        "(Button.icon), а не текст: emoji-глифы рисуются цветной битмап-шрифтом, "
        "поэтому font_color их не красит в золото макета; генератор "
        "scripts/ui_kit/build_round_button.py; форма своя (в макете — сюжетные "
        "картинки: пирог, колчан с шаром, конь с кольцом), металл общий — золото с "
        "вертикальным градиентом и тенью со смещением; носитель: "
    )
    for name, use in EMBLEM_USE.items():
        files[f"emblems/emblem_{name}.png"] = {
            "size": [CANVAS, CANVAS],
            "kind": "icon",
            "note": emblem_note + use,
        }

    manifest["round_button"] = {
        "generator": "scripts/ui_kit/build_round_button.py",
        "mockup": "reference/11_battle_hex_snow.jpeg — нижний ряд боя: кованые медальоны, а не плиты макета 09",
        "measure": {
            "cut": "медальон «Menu», разрез y=1462 от x=44 к центру x=128, кадр 2816×1584, R=81 px",
            "rings_ratio_of_outer_radius": {
                "bronze_ring": [1.00, 0.90],
                "dark_groove": [0.90, 0.82],
                "gold_thread": [0.82, 0.78],
                "dark_ring": [0.78, 0.66],
                "plate": [0.66, 0.0],
                "emblem": [0.48, 0.0],
            },
            "colors": {
                "bronze_ring": (101, 74, 55), "gold_thread": (154, 122, 97),
                "groove": (12, 15, 18), "plate_top": PLATE_TOP, "plate_bottom": PLATE_BOTTOM,
                "emblem": GOLD, "emblem_lit": GOLD_LIGHT, "emblem_dark": GOLD_DARK,
            },
            "diameter_px_at_2816": 162,
            "diameter_px_at_1920": 110,
            "button_game_px": 100,
            "pitch_px": 120,
            "note": "в сцене контрол 100 px при шаге 120 px — принято вторым проходом зрения §5; геометрия ряда этой правкой не трогается",
        },
        "derived_states_note": "hover/pressed/disabled выведены из normal; в макете нарисовано только normal.",
        "files": written,
    }
    manifest["battle_emblems"] = {
        "generator": "scripts/ui_kit/build_round_button.py",
        "mockup": "reference/11_battle_hex_snow.jpeg — золотые эмблемы на пластине, не цветные иконки",
        "note": (
            "Эмблема — иконка кнопки (Button.icon), пластина — stylebox. Золото с "
            "вертикальным градиентом и тенью со смещением: металл лежит на пластине. "
            "Формы свои (шестерня/флаг/спаскруг/мечи/книга/песочные часы/щит/шевроны), "
            "сюжеты эмблем макета (пирог, колчан с шаром, конь с кольцом) не переносились: "
            "они нечитаемы на 44 px и не связаны с командами игры."
        ),
        "files": emblems,
    }
    # indent=1 — конвенция MANIFEST.json: indent=2 переписывает весь файл (+660 строк диффа).
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print("пластины:", ", ".join(written))
    print("эмблемы:", ", ".join(emblems))


if __name__ == "__main__":
    main()

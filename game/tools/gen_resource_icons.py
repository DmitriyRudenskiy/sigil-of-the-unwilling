#!/usr/bin/env python3
"""ASSET-1: генератор собственных иконок ресурсов по формуле [[13-art-bible]] §7.1.

Рисует 20 файлов `assets/ui/icons/resources/icon_resource_<id>.png` (32×32, PNG-32
с альфой, ≤ 6 КБ) — словарь игры (19 id бывшего HoMM-атласа + `food`), а не словарь
чужого листа. Вход «пиксели HoMM → перекрас → файл» отсутствует по построению:
скрипт не читает ни `assets/textures/resources.png`, ни `reference/`, ни
`___STYLE_BOOK/` — только константы ниже. Гард от этого — тест
`tests/unit/assets/test_resource_icons_asset1.gd` (в т.ч. расстояние dHash до
закоммиченных констант 16 ячеек референса 21).

Шаги формулы и где они исполняются:

  1 канвас 32×32 (сетка 8)      → CANVAS
  2 поле = канвас − 8 px        → FIELD, все координаты рисуются в поле 16×16
  3 силуэт читается в 16 px     → форма, а не цвет; проверка — тест + приёмка глазом
  4 свет один, тёплый, ~45°     → shade(): клин «к свету»/«от света» относительно центра масс
  5 обводка 1.5 px `#16100a`    → outline(): кольцо сажи + полутоновое кольцо внутрь
  6 массы из полосы, один акцент→ TOKENS (замер §4.6), роль accent ≤ ACCENT_MAX
  7 редкость не кодируется      → одного варианта на id, окантовок нет
  8 PNG-32, ≤ 6 КБ, имя         → export(), NAME_RE

Состав материала каждой иконки — таблица MATERIALS: три тона полосы (тёмный/масса/
свет) + один акцент. Плоская заливка, без градиентов: свет передан выбором токена,
а не арифметикой, поэтому палитра остаётся точной (§8.5).

Запуск:  python3 game/tools/gen_resource_icons.py [--out <dir>]
Проверка без записи: тот же запуск с --check (падение, если файл в репо
  отличается от перегенерированного — генератор детерминирован).
"""
import argparse
import io
import os
import re
import sys

from PIL import Image, ImageDraw

SCALE = 4                      # супер-сэмплинг: контуры сCoverage при точных RGB
CANVAS = 32
FIELD = 8                      # отступ поля содержимого (шаг 2): 32 − 8 − 8 = 16
SS = CANVAS * SCALE            # 128
OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                       "assets", "ui", "icons", "resources")
NAME_RE = re.compile(r"^icon_resource_[a-z_]+\.png$")
SIZE_LIMIT = 6144              # §8.2: иконка ≤ 6 КБ
ACCENT_MAX = 0.08              # §7.1 шаг 6: один акцент ≤ 8 % площади
CARRIER = (0x28, 0x1C, 0x0F)   # §4.1 тёмное дерево поля: фон, на котором читают силуэт
L_MIN = 0.20                   # яркость массы ≥ (урок невидимого угля, §11 п.1)
L_DELTA_MIN = 0.08             # и контраст против носителя

# --- роли пикселя (плоская заливка, шаг 6) -----------------------------------
EMPTY, DARK, MASS, LIT, ACCENT = 0, 1, 2, 3, 4

# --- полоса (§4.6, замер) -----------------------------------------------------
# Токены берутся из измеренных полос: A (UI-хром), C (карта/бой), D (здания),
# B1 (иконки — замер 60 живых artifacts тем же методом, что и §4.6), плюс канон
# §4.1 (сажа, дерево, золото, пергамент, алый). Массы иконок квантованы в неё
# по построению — арифметика света выбирает соседний токен полосы, а не новый цвет.
TOKENS = {
    # A. UI-хром
    "a1": (0x11, 0x11, 0x12), "a2": (0x1d, 0x20, 0x1f), "a3": (0x2b, 0x27, 0x23),
    "a4": (0x41, 0x2c, 0x22), "a5": (0x60, 0x4e, 0x3a), "a6": (0x76, 0x71, 0x60),
    "a7": (0xbd, 0xae, 0x93), "a8": (0x3b, 0x44, 0x44),
    # C. Карта/бой
    "c1": (0x18, 0x10, 0x0f), "c2": (0x40, 0x39, 0x29), "c3": (0x58, 0x64, 0x4b),
    "c4": (0x7d, 0x73, 0x4b), "c5": (0x8c, 0x94, 0x7c), "c6": (0xbe, 0xb2, 0x8f),
    "c7": (0x5a, 0x3e, 0x29), "c8": (0x29, 0x26, 0x1d),
    # D. Здания
    "d1": (0x32, 0x1c, 0x12), "d2": (0x41, 0x38, 0x28), "d3": (0x6e, 0x33, 0x1d),
    "d4": (0x7d, 0x4c, 0x2f), "d5": (0xa8, 0x6d, 0x41), "d6": (0xac, 0x8e, 0x5b),
    "d7": (0xd4, 0xc0, 0x9d),
    # B1. Иконки (замер 60 живых artifacts, 8 кластеров)
    "b1": (0xbf, 0x99, 0x26), "b2": (0xf1, 0xd1, 0x67), "b3": (0x40, 0x72, 0xbc),
    "b4": (0x5e, 0x47, 0x2c), "b5": (0x88, 0x9e, 0xa6), "b6": (0xd6, 0xbe, 0x6e),
    "b7": (0x7b, 0x72, 0x59),
    # канон §4.1
    "soot": (0x16, 0x10, 0x0a), "wood": (0x28, 0x1c, 0x0f),
    "gold": (0x8a, 0x6a, 0x3a), "gold_bright": (0x9e, 0x77, 0x38),
    "parchment": (0xe8, 0xd5, 0xa8), "crimson": (0x7a, 0x10, 0x0c),
    "ok": (0x7a, 0xa8, 0x5a),
}
PALETTE = set(TOKENS.values())
SOOT = TOKENS["soot"]
DETAIL_ORDER = {9: 0, 10: 1, ACCENT: 2, DARK: 3, LIT: 4, MASS: 5}

# --- материалы: тёмный / масса / свет / акцент (акцент — один, ≤ 8 %) ---------
MATERIALS = {
    "wood":       ("wood", "b4", "d5", None),
    "oak":        ("wood", "b4", "d5", "c3"),
    "stone":      ("c8", "a6", "a7", "d7"),
    "ore":        ("c8", "a5", "d6", "a7"),
    "gold_ore":   ("c8", "b4", "d6", "b2"),
    "bog_iron":   ("c2", "a6", "d6", "d7"),
    "coal":       ("c1", "a5", "a6", "d7"),
    "coal_swamp": ("c1", "a5", "b5", "b3"),
    "gold":       ("gold", "b1", "b2", "parchment"),
    "silver":     ("a8", "b5", "a7", "parchment"),
    "mercury":    ("a8", "b5", "a7", "parchment"),
    "saltpeter":  ("b7", "a7", "parchment", "parchment"),
    "sulfur":     ("gold", "b6", "b2", "b2"),
    "crystal":    ("a8", "b3", "b5", "parchment"),
    "quartz":     ("b7", "a7", "parchment", "parchment"),
    "gems":       ("c3", "ok", "d7", "parchment"),
    "turquoise":  ("a8", "b3", "b5", "c6"),
    "cinnabar":   ("d1", "d3", "d5", "crimson"),
    "limonite":   ("c2", "c4", "c6", "d7"),
    "food":       ("gold", "b6", "b2", "d7"),
}


# --- примитивы в координатах поля (0..16, y вниз) -----------------------------
class Sheet:
    def __init__(self):
        self.roles = Image.new("L", (SS, SS), EMPTY)
        self.d = ImageDraw.Draw(self.roles)

    def p(self, x, y):
        return (int(round((FIELD + x) * SCALE)), int(round((FIELD + y) * SCALE)))

    def box(self, x0, y0, x1, y1, role):
        self.d.rectangle([*self.p(x0, y0), *self.p(x1, y1)], fill=role)

    def rbox(self, x0, y0, x1, y1, r, role):
        self.d.rounded_rectangle([*self.p(x0, y0), *self.p(x1, y1)], radius=r * SCALE, fill=role)

    def ell(self, x0, y0, x1, y1, role):
        self.d.ellipse([*self.p(x0, y0), *self.p(x1, y1)], fill=role)

    def circ(self, cx, cy, r, role):
        self.ell(cx - r, cy - r, cx + r, cy + r, role)

    def poly(self, pts, role):
        self.d.polygon([self.p(*pt) for pt in pts], fill=role)

    def line(self, pts, w, role):
        self.d.line([self.p(*pt) for pt in pts], fill=role, width=max(1, int(w * SCALE)))

    def dot(self, x, y, role):
        self.circ(x, y, 0.6, role)


# --- фигуры 20 ресурсов: только силуэт, цвет делает роль -----------------------
def draw_wood(s):
    for y, x0 in ((1.5, 1.5), (6.0, 2.5), (10.5, 0.5)):
        s.rbox(x0, y, x0 + 12.5, y + 3.5, 1.7, MASS)
        s.circ(x0 + 1.8, y + 1.8, 1.4, LIT)                          # срез
        s.circ(x0 + 1.8, y + 1.8, 0.6, DARK)
        s.line([(x0 + 5, y + 1.1), (x0 + 10, y + 1.1)], 0.5, DARK)   # волокно


def draw_oak(s):
    """Дуб = один крупный жёлудь: орех, чашечка с чешуйками, хвостик."""
    s.ell(3.6, 6.4, 12.4, 15.8, MASS)                                # орех
    s.ell(2.8, 4.6, 13.2, 9.4, DARK)                                 # чашечка
    s.line([(8, 4.6), (9.6, 1.2)], 1.3, DARK)                        # хвостик
    for x in (5.2, 8, 10.8):                                         # чешуйки чашечки
        s.circ(x, 7.4, 0.9, MASS)
    s.circ(6.2, 11.6, 1.6, LIT)
    s.circ(10.6, 13.2, 0.8, ACCENT)


def draw_stone(s):
    """Два колотых клина со сколотой гранью: плоские основания, прямые рёбра."""
    s.poly([(0.5, 15.5), (0.5, 10.5), (4.5, 7.5), (8.5, 10.5), (8.5, 15.5)], MASS)
    s.poly([(8.5, 15.5), (8.5, 8.5), (12, 5), (15.5, 8.5), (15.5, 15.5)], MASS)
    s.poly([(0.5, 10.5), (4.5, 7.5), (8.5, 10.5), (4.5, 11.5)], LIT)
    s.poly([(8.5, 8.5), (12, 5), (15.5, 8.5), (12, 9.5)], LIT)
    s.line([(8.5, 10.5), (8.5, 15.5)], 0.8, DARK)


def draw_ore(s):
    """Округлая осыпь с вкраплениями минерала — купол, не крыша."""
    s.ell(0.5, 6.5, 15.5, 15.5, MASS)
    s.box(0.5, 14, 15.5, 15.5, MASS)
    s.poly([(3.5, 7.5), (5.5, 4), (8.5, 5.5), (7.5, 8)], MASS)
    for x, y in ((4, 10), (8, 11.5), (12, 10), (6.5, 13), (10, 7.5)):
        s.dot(x, y, DARK)
    s.line([(2.5, 8), (4.5, 9.5)], 0.6, ACCENT)


def draw_coal(s):
    """Уголь = один острый кубовидный кусок со сколами + два отłamка у ноги:
    асимметрия отделяет его от симметричной осыпи руды (dHash coal↔ore был 2)."""
    s.poly([(2.5, 15.5), (1.5, 8.5), (6, 1.5), (11.5, 4.5), (13, 12), (10, 15.5)], MASS)
    s.poly([(6, 1.5), (11.5, 4.5), (9, 7), (5, 5.5)], LIT)
    s.line([(5, 5.5), (6.5, 15.5)], 0.7, DARK)
    s.line([(9, 7), (10.4, 15)], 0.6, DARK)
    s.poly([(12.6, 15.5), (13.2, 12.4), (15.5, 13.4), (15.2, 15.5)], MASS)
    s.poly([(0.5, 15.5), (0.8, 13.2), (2.6, 13.8), (2.4, 15.5)], MASS)
    s.line([(3.4, 9.6), (4.6, 12.6)], 0.5, ACCENT)


def draw_coal_swamp(s):
    """Два низких куска, наполовину в воде; вода — три связанные волны."""
    s.poly([(1.5, 10.5), (3.5, 4.5), (7, 3.5), (8.5, 10.5)], MASS)
    s.poly([(8, 10.5), (10, 4), (13.5, 5.5), (14.8, 10.5)], MASS)
    for y in (11.8, 14.4):                                           # вода — тон полосы
        pts = [(0.5 + i * 2.5, y - (0.9 if i % 2 else 0)) for i in range(7)]
        s.line(pts, 1.6, LIT)
    s.circ(12.6, 6.2, 0.9, ACCENT)


def draw_gold_ore(s):
    """Угловатый монолит с золотыми прожилками — один камень, не осыпь."""
    s.poly([(2.5, 15.5), (1.5, 8), (5.5, 1.5), (11, 3), (14, 10), (13, 15.5)], MASS)
    s.poly([(5.5, 1.5), (11, 3), (9, 6.5), (4.5, 5)], LIT)
    s.line([(4.2, 12.4), (8.2, 8.4)], 0.9, ACCENT)
    s.line([(4.5, 5), (5.5, 1.5)], 0.6, DARK)


def draw_bog_iron(s):
    """Пористая болотная железа: округлый кусок с порами + smaller сзади."""
    s.circ(11.5, 6.5, 3.2, MASS)
    s.ell(1, 5.5, 12.5, 15.5, MASS)
    s.box(1, 13.5, 12.5, 15.5, MASS)
    for x, y, r in ((4, 9, 1.0), (7.5, 11.5, 0.9), (9.5, 8, 0.8), (5.5, 13, 0.7)):
        s.circ(x, y, r, DARK)
    s.line([(2.5, 7), (5, 6.2)], 0.6, ACCENT)


def draw_gold(s):
    """Три монеты: две за, одна передняя с кольцом и точкой в центре."""
    for cx, cy in ((3.4, 11.4), (12.6, 11.4), (8, 11.4), (8, 5.4)):
        s.circ(cx, cy, 3.5, MASS)
    s.circ(8, 11.4, 3.5, MASS)
    for cx, cy in ((3.4, 11.4), (12.6, 11.4), (8, 5.4)):
        s.circ(cx, cy, 2.1, DARK)
        s.circ(cx, cy, 1.4, LIT)
    s.circ(8, 11.4, 2.2, DARK)
    s.circ(8, 11.4, 1.5, LIT)
    s.circ(7.1, 10.5, 0.8, ACCENT)


def draw_silver(s):
    """Слиток лёжа + самородок рядом у ноги."""
    s.poly([(1, 15), (2.8, 9.5), (12.5, 9.5), (14.5, 15)], MASS)
    s.poly([(3.4, 9.5), (11.9, 9.5), (10.6, 7), (4.7, 7)], LIT)
    s.line([(2.8, 9.5), (12.5, 9.5)], 0.6, DARK)
    s.line([(5.5, 12), (10, 12)], 0.5, DARK)
    s.poly([(11.5, 6), (12.8, 2.5), (15.5, 3.5), (15.5, 6)], ACCENT)


def draw_mercury(s):
    """Толстая капля над широкой лужицей с зазором + спутник."""
    s.circ(8, 7.5, 4.2, MASS)
    s.poly([(4.6, 5.6), (8, 0.5), (11.4, 5.6)], MASS)
    s.ell(1, 12.6, 11.5, 15.6, MASS)
    s.circ(13.6, 13, 1.7, MASS)
    s.circ(6.4, 6.2, 1.5, ACCENT)
    s.line([(10.2, 3.6), (11, 6)], 0.5, LIT)


def draw_saltpeter(s):
    """Мешок рафинированной селитры: корпус, перевязь, блёстки внутри."""
    s.rbox(2, 6.5, 14, 15.5, 2.4, MASS)
    s.poly([(5.5, 6.5), (6.2, 3.2), (9.8, 3.2), (10.5, 6.5)], MASS)
    s.line([(5.6, 4.6), (10.4, 4.6)], 0.9, DARK)
    for x, y in ((5.5, 9.5), (9.8, 10.5), (7.2, 13)):
        s.circ(x, y, 0.8, ACCENT)
    s.line([(3.2, 12.5), (4.6, 13.6)], 0.6, DARK)


def draw_sulfur(s):
    """Три гексагональных призма серы разной высоты со светлыми верхними гранями."""
    for x0, top, h in ((0.5, 8.5, 7), (5.5, 4.5, 11), (10.5, 7, 8.5)):
        s.poly([(x0, 15.5), (x0, top + 1.6), (x0 + 2.2, top), (x0 + 4.4, top + 1.6),
                (x0 + 4.4, 15.5)], MASS)
        s.poly([(x0, top + 1.6), (x0 + 2.2, top), (x0 + 4.4, top + 1.6), (x0 + 2.2, top + 3)], LIT)
        s.line([(x0 + 2.2, top + 3), (x0 + 2.2, 15.5)], 0.5, DARK)
    s.line([(1.2, 13), (4, 13)], 0.6, ACCENT)


def draw_crystal(s):
    s.poly([(0.5, 15.5), (1, 9.5), (3.6, 6.5), (5.2, 15.5)], MASS)
    s.poly([(15.5, 15.5), (14.8, 8.5), (12.2, 5.5), (10.8, 15.5)], MASS)
    s.poly([(4.8, 15.5), (4.4, 6), (8, 0.5), (11.6, 6), (11.2, 15.5)], MASS)
    s.poly([(4.4, 6), (8, 0.5), (11.6, 6), (8, 8)], LIT)
    s.line([(8, 8), (8, 15)], 0.6, DARK)
    s.line([(6.2, 4), (6.4, 14)], 0.5, LIT)


def draw_quartz(s):
    """Короткий столбчатый кристалл с большой верхней гранью и отщепом у ноги."""
    s.poly([(4, 15.5), (3.6, 6.5), (8, 3), (12.4, 6.5), (12, 15.5)], MASS)
    s.poly([(3.6, 6.5), (8, 3), (12.4, 6.5), (8, 8.6)], LIT)
    s.line([(8, 8.6), (8, 15.5)], 0.6, DARK)
    s.line([(5.6, 6), (5.8, 14)], 0.5, LIT)
    s.poly([(12.6, 15.5), (13.2, 12), (15.5, 13), (15.2, 15.5)], MASS)


def draw_gems(s):
    """Ромбовидные самоцветы: верхняя половина светлая, нижняя тёмная — грань тоном."""
    for cx, cy, r in ((6, 9.5, 5.6), (12.8, 12, 3.4)):
        s.poly([(cx, cy - r), (cx + r * 0.7, cy), (cx, cy + r), (cx - r * 0.7, cy)], MASS)
        s.poly([(cx, cy - r), (cx + r * 0.7, cy - r * 0.1), (cx - r * 0.7, cy - r * 0.1)], LIT)
        s.line([(cx - r * 0.7, cy - r * 0.1), (cx + r * 0.7, cy - r * 0.1)], 0.6, DARK)
        s.circ(cx - r * 0.24, cy - r * 0.42, 0.75, ACCENT)


def draw_turquoise(s):
    """Кабошон бирюзы в тёмной оправе с матричными прожилками."""
    s.ell(0.5, 3.5, 15.5, 14.5, DARK)
    s.ell(1.6, 4.6, 14.4, 13.4, MASS)
    s.line([(3, 7.5), (6, 9.5), (8.5, 6.8), (11.5, 9.2), (13.4, 7.2)], 0.7, DARK)
    s.line([(4, 11.5), (7, 12.6), (10.5, 11.2)], 0.6, DARK)
    s.ell(4, 5.8, 8.5, 8.4, LIT)
    s.circ(11.6, 11.4, 1.0, ACCENT)


def draw_cinnabar(s):
    """Киноварь = колотый пласт с плоской верхней гранью и алыми вкраплениями:
    пласт, а не осыпь (у осыпи-руды силуэт купола, dHash был 4)."""
    s.poly([(0.6, 15.5), (0.6, 11.4), (5.4, 8.4), (15.4, 8.4), (15.4, 15.5)], MASS)
    s.poly([(0.6, 11.4), (5.4, 8.4), (15.4, 8.4), (11, 11.4)], LIT)
    s.line([(11, 11.4), (15.4, 8.4)], 0.6, DARK)
    s.poly([(4.4, 8.4), (6.4, 4.4), (10.4, 5.4), (9.4, 8.4)], MASS)
    s.poly([(6.4, 4.4), (10.4, 5.4), (8.6, 6.4), (6.8, 6.2)], LIT)
    s.poly([(3.4, 12.6), (5, 11.8), (5.6, 13.6), (4, 14.2)], ACCENT)
    s.poly([(10.6, 12.2), (12.2, 11.6), (12.6, 13.2)], ACCENT)


def draw_limonite(s):
    """Бурожелезистый желвак: приплюснутый слева, с наростом справа и порошистой."""
    s.ell(0.6, 6.4, 11.4, 15.6, MASS)
    s.circ(12.8, 11.4, 3.2, MASS)
    s.circ(4.6, 3.8, 2.6, MASS)
    s.line([(9.6, 8.4), (9, 14.4)], 0.7, DARK)
    s.line([(10.4, 11.6), (14.8, 11.2)], 0.6, DARK)
    for x, y in ((3.4, 10.4), (6.4, 12.8), (12.6, 8.6)):
        s.circ(x, y, 0.8, DARK)
    s.circ(3.4, 7.6, 1.5, LIT)


def draw_food(s):
    """Колос: стержень и пять пар зёрен, прикреплённых к стержню (ёлочкой)."""
    s.line([(8, 15.5), (8, 2)], 1.2, MASS)
    for k in range(4):
        y = 1.6 + 2.3 * k
        s.ell(3.6, y, 8, y + 2.6, LIT)
        s.ell(8, y, 12.4, y + 2.6, MASS)
    s.poly([(8, 0.4), (6.2, 3), (9.8, 3)], LIT)                      # верхушка
    s.box(5.4, 11.4, 10.6, 12.8, DARK)                               # перевязь
    s.line([(8, 13.6), (4.6, 15.6)], 1.0, MASS)
    s.line([(8, 13.6), (11.4, 15.6)], 1.0, MASS)

SHAPES = {
    "wood": draw_wood, "oak": draw_oak, "stone": draw_stone, "ore": draw_ore,
    "gold_ore": draw_gold_ore, "bog_iron": draw_bog_iron, "coal": draw_coal,
    "coal_swamp": draw_coal_swamp, "gold": draw_gold, "silver": draw_silver,
    "mercury": draw_mercury, "saltpeter": draw_saltpeter, "sulfur": draw_sulfur,
    "crystal": draw_crystal, "quartz": draw_quartz, "gems": draw_gems,
    "turquoise": draw_turquoise, "cinnabar": draw_cinnabar, "limonite": draw_limonite,
    "food": draw_food,
}


# --- пост-обработка: свет (шаг 4) и обводка (шаг 5) ---------------------------
def clip_to_field(s):
    """Всё, что вышло за поле содержимого (шаг 2), — обрезаем, а не рисуем снаружи."""
    px = s.roles.load()
    lo, hi = FIELD * SCALE, (CANVAS - FIELD) * SCALE
    for y in range(SS):
        for x in range(SS):
            if not (lo <= x < hi and lo <= y < hi):
                px[x, y] = EMPTY


def shade(s):
    """Один тёплый свет ~45° сверху-слева (шаг 4): первый ряд внутри обводки,
    повёрнутый к свету, берёт светлый токен полосы, противоположный — тёмный;
    середина остаётся массой. Плоская заливка без градиента (§13: flat shading),
    детали фигур (жилки, сколы, вкрапления) светом не перекрашиваются."""
    px = s.roles.load()
    solid = [(x, y) for y in range(SS) for x in range(SS) if px[x, y]]
    if not solid:
        return
    cx = sum(x for x, _ in solid) / len(solid)
    cy = sum(y for _, y in solid) / len(solid)                       # центр масс
    n4 = lambda x, y: [(a, b) for a, b in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))
                       if 0 <= a < SS and 0 <= b < SS]
    for x, y in solid:
        if px[x, y] != MASS:
            continue
        if not any(not px[a, b] for a, b in n4(x, y)):
            continue                                                 # не край — не трогаем
        px[x, y] = LIT if (x - cx) + (y - cy) < 0 else DARK
    


def outline(s):
    """Гравюрная обводка 1.5 px сажей внутри канваса: кольцо 1 px + полутоновое
    кольцо внутрь. Цветная обводка и «шнур» — анти-паттерн §11 п.7."""
    px = s.roles.load()
    n4 = lambda x, y: [(a, b) for a, b in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))
                       if 0 <= a < SS and 0 <= b < SS]
    ring = [(x, y) for y in range(SS) for x in range(SS)
            if px[x, y] and any(not px[a, b] for a, b in n4(x, y))]
    for x, y in ring:
        px[x, y] = 9                                                 # кольцо сажи 1 px
    for x, y in [(a, b) for b in range(SS) for a in range(SS)
                 if px[a, b] in (DARK, MASS, LIT, ACCENT)]:
        if any(px[a, b] == 9 for a, b in n4(x, y)):
            px[x, y] = 10                                            # +0.5 px внутрь
    


def render(sid):
    """Один файл: фигуры → свет → обводка → квантование в полосу → PNG-32."""
    s = Sheet()
    SHAPES[sid](s)
    clip_to_field(s)
    dark_t, mass_t, lit_t, accent_t = MATERIALS[sid]
    shade(s)
    outline(s)
    roles = s.roles.load()
    img = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    acc = tot = 0
    for y in range(CANVAS):
        for x in range(CANVAS):
            block = [roles[x * SCALE + dx, y * SCALE + dy]
                     for dy in range(SCALE) for dx in range(SCALE)]
            solid = [r for r in block if r]
            if not solid:
                continue
            tot += 1
            # Тонкие детали (0.5 px = 2/16 подвыборок) тонули бы в мажоритарной
            # заливке, поэтому берём самую редкую роль блока, но не случайный шум:
            # от 3 px. Обводка и акцент выживают, плоская масса — нет.
            counts = {r: solid.count(r) for r in set(solid)}
            cand = [(c, DETAIL_ORDER.get(r, 9), r) for r, c in counts.items() if c >= 3]
            role = min(cand)[2] if cand else max(counts, key=counts.get)
            if role == 9:
                rgb, a_full = SOOT, 255
            elif role == 10:
                base = [r for r in solid if r in (DARK, MASS, LIT, ACCENT)]
                rgb = _mix(_color(base[0] if base else MASS, dark_t, mass_t, lit_t, accent_t),
                           SOOT, 0.5)
            else:
                if role == ACCENT:
                    acc += 1
                rgb = _color(role, dark_t, mass_t, lit_t, accent_t)
                a_full = 255
            alpha = int(255 * len(solid) / len(block))
            img.putpixel((x, y), (*rgb, min(255, alpha)))
    return img, acc, tot


def _mix(a, b, t):
    return tuple(int(round(a[i] * (1 - t) + b[i] * t)) for i in range(3))


def _color(role, dark_t, mass_t, lit_t, accent_t):
    return {DARK: TOKENS[dark_t], MASS: TOKENS[mass_t], LIT: TOKENS[lit_t],
            ACCENT: TOKENS[accent_t] if accent_t else TOKENS[mass_t]}[role]


def check(sid, img, acc, tot):
    bad = []
    if img.size != (CANVAS, CANVAS):
        bad.append("канвас ≠ 32×32")
    for y in range(CANVAS):
        for x in range(CANVAS):
            inside = FIELD <= x < CANVAS - FIELD and FIELD <= y < CANVAS - FIELD
            if img.getpixel((x, y))[3] > 0 and not inside:
                bad.append("пиксель вне поля содержимого (%d,%d)" % (x, y))
    if tot and acc / tot > ACCENT_MAX:
        bad.append("акцент %.1f %% > 8 %%" % (100 * acc / tot))
    lum = lambda c: (0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]) / 255.0
    body = [img.getpixel((x, y)) for y in range(CANVAS) for x in range(CANVAS)
            if img.getpixel((x, y))[3] > 128]
    mean = sum(lum(p) for p in body) / len(body)
    if mean < L_MIN:
        bad.append("масса слишком тёмная: средняя яркость %.3f < %.2f" % (mean, L_MIN))
    if mean - lum(CARRIER) < L_DELTA_MIN:
        bad.append("силуэт не читается на носителе: Δяркости %.3f < %.2f"
                   % (mean - lum(CARRIER), L_DELTA_MIN))
    # плоская заливка — из токенов; вне палитры допустимы только края (анти-алиасинг)
    for y in range(1, CANVAS - 1):
        for x in range(1, CANVAS - 1):
            p = img.getpixel((x, y))
            if p[3] < 255 or p[:3] in PALETTE:
                continue
            if all(img.getpixel((x + dx, y + dy))[3] == 255
                   for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                bad.append("вне палитры §4.6: %r в (%d,%d)" % (p[:3], x, y))
    return bad


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=OUT_DIR)
    ap.add_argument("--check", action="store_true", help="не писать, падать на расхождении")
    ap.add_argument("--only", default=None)
    args = ap.parse_args()

    ids = [args.only] if args.only else sorted(SHAPES)
    os.makedirs(args.out, exist_ok=True)
    problems = []
    for sid in ids:
        img, acc, tot = render(sid)
        problems += ["%s: %s" % (sid, m) for m in check(sid, img, acc, tot)]
        path = os.path.join(args.out, "icon_resource_%s.png" % sid)
        buf = io.BytesIO()
        img.save(buf, "PNG", optimize=True)
        if buf.tell() > SIZE_LIMIT:
            problems.append("%s: вес %d Б > 6 КБ" % (sid, buf.tell()))
        if args.check:
            if not os.path.exists(path) or open(path, "rb").read() != buf.getvalue():
                problems.append("%s: файл в репо ≠ перегенерированный" % sid)
        else:
            with open(path, "wb") as fh:
                fh.write(buf.getvalue())
            print("  icon_resource_%s.png  %5d Б  сил. %d px  акцент %.1f %%"
                  % (sid, buf.tell(), tot, 100 * acc / max(1, tot)))
    if problems:
        print("\n".join(problems), file=sys.stderr)
        sys.exit(1)
    print("%s: %d иконок, все по формуле (§7.1), ≤ 6 КБ" % ("OK" if args.check else "готово", len(ids)))


if __name__ == "__main__":
    main()

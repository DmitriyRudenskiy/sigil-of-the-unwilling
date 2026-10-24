#!/usr/bin/env python3
"""Ассет-гард UI (ui-verification-gates, задачи 3.1–3.2).

Проверки (proposal: «прозрачность углов у кнопок/слотов/иконок, однородность
центрального тайла 9-slice-панелей (порог stddev), тёмные ореолы на
полупрозрачных краях»):

  (a) ПРОЗРАЧНЫЕ УГЛЫ — у ассетов с прозрачным фоном все 4 угла обязаны
      иметь alpha < 10 (сплошной угол = артефакт автокропа). Полностью
      непрозрачные плитки (весь периметр alpha > 240) — дизайн, проверке
      не подлежат.
  (b) 9-SLICE — центральный тайл (25%–75% по обеим осям) обязан быть
      однородным: stddev яркости непрозрачных пикселей (alpha > 128) < 28,
      иначе центр панели «рвётся» при растяжении. Применяется к файлам
      MANIFEST.json с kind == "9-slice".
  (c) ТЁМНЫЙ ОРЕОЛ — периметр изображения, шаг 7 px; условие
      10 < alpha < 200 и r+g+b < 60 (почти чёрный полупрозрачный).
      Отчёт: файл + число образцов. Внутренность не сканируется: мягкие
      тени внутри иконок (низко-альфовый чёрный) — техника рисования, не
      ореол; ореол — на кромке изображения (proposal: «на полупрозрачных
      краях»). Исключение — **область скола по углу** (T-156, вариант (а)):
      размер скола измеряется по самой альфе (профиль края) и обязательно
      доказывается диагональной силуэтой; внутри этой зоны AA-кромка
      сигнатурной формы плитки (арт-библия §4.1) образцом не считается.
      Прямые рёбра проверяются полностью, скошенных углов нет — исключения
      нет тоже.

`--self-test` — проверка самого гарда (задача 3.2, протокол мутаций): синтетический
ореол на прямом краю обязан быть найден, синтетический чамфер — не найден.
Без самопроверки «зелёный гейт» после исключения T-156 ничего не значит.

Область: game/assets/ui/widgets/ (buttons/panels/sliders/progress_bars;
классификация — MANIFEST.json, kind "9-slice"/"иконка") +
game/assets/ui/icons/.

Exit: 0 — чистый набор; 1 — перечень нарушений; 2 — ошибка среды
(нет Pillow / нет MANIFEST / битый PNG).

Конвенция — scripts/check_docs_links.py (системный python3 + Pillow).
"""

import json
import math
import os
import sys

try:
    from PIL import Image
except ImportError:
    print("check_ui_assets: нет Pillow (python3 -m pip install --user Pillow)")
    sys.exit(2)

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UI_ROOT = os.path.join(REPO, "game", "assets", "ui")
WIDGET_DIRS = ("buttons", "panels", "sliders", "progress_bars")
ICONS_DIR = os.path.join(UI_ROOT, "icons")
MANIFEST = os.path.join(UI_ROOT, "widgets", "MANIFEST.json")

CORNER_ALPHA_MAX = 10      # (a): угол считается прозрачным при alpha < 10
OPAQUE_RING_MIN = 240      # весь периметр > 240 -> плитка с непрозрачным фоном (дизайн)
CENTER_STDDEV_MAX = 28.0   # (b): порог однородности центрального тайла
HALO_STEP = 7              # (c): шаг выборки периметра
HALO_ALPHA_LO = 10         # (c): 10 < alpha < 200
HALO_ALPHA_HI = 200
HALO_RGB_SUM_MAX = 60      # (c): r+g+b < 60 — почти чёрный
CHAMFER_AA = 2             # (c): ширина AA-кромки скола, px (запас к измеренному)


def corner_alphas(im):
    px = im.load()
    w, h = im.size
    return [px[0, 0][3], px[w - 1, 0][3], px[0, h - 1][3], px[w - 1, h - 1][3]]


def ring_min_alpha(im):
    px = im.load()
    w, h = im.size
    m = 255
    for x in range(w):
        m = min(m, px[x, 0][3], px[x, h - 1][3])
    for y in range(h):
        m = min(m, px[0, y][3], px[w - 1, y][3])
    return m


def opaque_tile(im):
    """Плитка с непрозрачным фоном по дизайну: весь периметр opaque."""
    return ring_min_alpha(im) > OPAQUE_RING_MIN


def check_corners(im):
    """(a) -> список нарушений (пусто = чисто)."""
    if opaque_tile(im):
        return []
    cs = corner_alphas(im)
    bad = [i for i, a in enumerate(cs) if a >= CORNER_ALPHA_MAX]
    if not bad:
        return []
    names = ["L", "R", "T", "B"]
    return ["углы %s непрозрачны (alpha %s, порог < %d)"
            % (",".join(names[i] for i in bad), cs, CORNER_ALPHA_MAX)]


def center_stddev(im):
    """(b) -> (stddev, n) по непрозрачным пикселям центрального тайла."""
    px = im.load()
    w, h = im.size
    x0, x1 = int(w * 0.25), int(w * 0.75)
    y0, y1 = int(h * 0.25), int(h * 0.75)
    vals = []
    for y in range(y0, y1):
        for x in range(x0, x1):
            r, g, b, a = px[x, y]
            if a > 128:
                vals.append(0.2126 * r + 0.7152 * g + 0.0722 * b)
    if not vals:
        return None, 0
    m = sum(vals) / len(vals)
    return math.sqrt(sum((v - m) ** 2 for v in vals) / len(vals)), len(vals)


def check_center(im):
    """(b) -> список нарушений."""
    sd, n = center_stddev(im)
    if sd is None:
        return ["центральный тайл пуст (нет непрозрачных пикселей)"]
    if sd >= CENTER_STDDEV_MAX:
        return ["stddev центра %.1f >= %g (n=%d) — 9-slice рвётся при растяжении"
                % (sd, CENTER_STDDEV_MAX, n)]
    return []


def _opaque(v):
    return v > OPAQUE_RING_MIN


def _col_start(px, x0_range, y):
    """Первый непрозрачный x в строке y (силуэт слева); None — строка пуста."""
    for x in x0_range:
        if _opaque(px[x, y][3]):
            return x
    return None


def _row_start(px, y0_range, x):
    """Первый непрозрачный y в столбце x (силуэт сверху); None — столбец пуст."""
    for y in y0_range:
        if _opaque(px[x, y][3]):
            return y
    return None


def chamfer_cuts(im):
    """(c) -> {'tl': c, 'tr': c, 'bl': c, 'br': c} — измеренные сколы углов.

    Размер скола — сколько пикселей от угла вдоль края альфа ещё не непрозрачная
    (профиль края). Одного профиля мало: его даёт и ореол автокропа, залегший по
    всему краю. Поэтому требуется **диагональная силуэта**: у настоящего скола
    левый край силуэта в строке y=c уже у устья (x=0), а в строке y=0 он стоит у
    x=c; у ореола над прямолинейным краем силуэт в обеих строках начинается в
    одном и том же месте. Без подтверждения скол не засчитывается, исключение не
    действует, образец остаётся нарушением (T-156, вариант (а)).
    """
    px = im.load()
    w, h = im.size
    xs = range(w)
    ys = range(h)
    cuts = {}

    def ramp(vals):
        n = 0
        for v in vals:
            if _opaque(v):
                break
            n += 1
        return n

    top = [px[x, 0][3] for x in xs]
    bottom = [px[x, h - 1][3] for x in xs]
    left = [px[0, y][3] for y in ys]
    right = [px[w - 1, y][3] for y in ys]
    cand = {
        "tl": (ramp(top), ramp(left)),
        "tr": (ramp(top[::-1]), ramp(right)),
        "bl": (ramp(bottom), ramp(left[::-1])),
        "br": (ramp(bottom[::-1]), ramp(right[::-1])),
    }
    for corner, (cx, cy) in cand.items():
        c = max(cx, cy)
        if c <= 0:
            cuts[corner] = 0
            continue
        c = min(c, w // 2, h // 2)
        if not _chamfer_proven(px, w, h, corner, c):
            cuts[corner] = 0
            continue
        cuts[corner] = c
    return cuts


def _chamfer_proven(px, w, h, corner, c):
    """Диагональная силуэта: кромка у угла уходит внутрь под 45 градусов."""
    d = min(c, w // 2, h // 2)
    y_far = d
    y_near = 0 if corner in ("tl", "tr") else h - 1
    if y_far == y_near:
        return False
    if corner in ("tl", "bl"):
        near = _col_start(px, range(w), y_near)
        far = _col_start(px, range(w), y_far)
        if near is None or far is None:
            return False
        return near >= c - 1 and far <= 1
    near = _col_start(px, range(w - 1, -1, -1), y_near)
    far = _col_start(px, range(w - 1, -1, -1), y_far)
    if near is None or far is None:
        return False
    return near <= w - c and far >= w - 2


def _in_chamfer(cuts, w, h, x, y):
    """Лежит ли точка периметра в зоне скола какого-нибудь угла."""
    for corner, c in cuts.items():
        if c <= 0:
            continue
        r = c + CHAMFER_AA
        dx = x if corner in ("tl", "bl") else w - 1 - x
        dy = y if corner in ("tl", "tr") else h - 1 - y
        if dx <= r and dy <= r:
            return True
    return False


def halo_samples(im, cuts=None):
    """(c) -> список (x, y, alpha, rgb) на периметре, шаг HALO_STEP."""
    px = im.load()
    w, h = im.size
    if cuts is None:
        cuts = chamfer_cuts(im)
    pts = []
    seen = set()

    def add(x, y):
        if (x, y) in seen:
            return
        seen.add((x, y))
        if _in_chamfer(cuts, w, h, x, y):
            return
        r, g, b, a = px[x, y]
        if HALO_ALPHA_LO < a < HALO_ALPHA_HI and r + g + b < HALO_RGB_SUM_MAX:
            pts.append((x, y, a, (r, g, b)))

    for x in range(0, w, HALO_STEP):
        add(x, 0)
        add(x, h - 1)
    for y in range(0, h, HALO_STEP):
        add(0, y)
        add(w - 1, y)
    return pts


def check_halo(im):
    pts = halo_samples(im)
    if not pts:
        return []
    return ["тёмный ореол: %d образцов, напр. %s"
            % (len(pts), pts[:3])]


def self_test():
    """Протокол мутаций для самого гарда (задача 3.2).

    (1) синтетический ореол автокропа (тёмная полупрозрачная кромка по прямому
        краю) обязан быть найден — иначе проверка пустая;
    (2) синтетический чамфер (диагональный скол с AA) обязан НЕ найтись — иначе
        исключение T-156 не отличает дизайн от дефекта.
    """
    fails = []

    # (1) ореол: прямоугольник с непрозрачным телом и кромкой 2 px alpha=150,
    #     почти чёрная; по всему периметру.
    w, h = 60, 40
    body = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    pb = body.load()
    for y in range(h):
        for x in range(w):
            pb[x, y] = (120, 90, 40, 255)
    for t in range(2):
        for x in range(w):
            for y in (t, h - 1 - t):
                pb[x, y] = (4, 10, 16, 150)
        for y in range(h):
            for x in (t, w - 1 - t):
                pb[x, y] = (4, 10, 16, 150)
    got = check_halo(body)
    if not got:
        fails.append("мутация «ореол на прямом краю» не найдена — проверка (c) пуста")

    # (2) чамфер: тот же прямоугольник, но у каждого угла срезан угол 45
    #     градусов, AA-кромка лежит по диагонали и красится той же почти
    #     чёрной краской (сигнатурная форма плитки, арт-библия §4.1).
    c = 12
    ch = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    pc = ch.load()
    for y in range(h):
        for x in range(w):
            smin = min(x + y, (w - 1 - x) + y, x + (h - 1 - y), (w - 1 - x) + (h - 1 - y))
            if smin < c:
                continue  # снаружи скола
            if smin < c + 2:
                pc[x, y] = (4, 10, 16, 150)  # AA диагональной кромки
            else:
                pc[x, y] = (120, 90, 40, 255)
    got2 = check_halo(ch)
    if got2:
        fails.append("мутация «чамфер-AA по углам» найдена как ореол — исключение "
                     "T-156 не отличает дизайн от дефекта: %s" % got2)

    # (3) подмножество: у прямоугольника без сколов исключений нет вовсе.
    if chamfer_cuts(body) != {"tl": 0, "tr": 0, "bl": 0, "br": 0}:
        fails.append("у прямоугольника без сколов измерились сколы — исключение "
                     "шире, чем должно быть")
    cuts = chamfer_cuts(ch)
    if min(cuts.values()) <= 0:
        fails.append("у чамфер-плитки скол не измерился (%s) — исключение не сработает "
                     "и на реальном ките" % cuts)

    if fails:
        print("check_ui_assets: SELF-TEST ПРОВАЛЕН:")
        for f in fails:
            print("  - %s" % f)
        return 1
    print("check_ui_assets: SELF-TEST OK — ореол на прямом краю ловится, "
          "чамфер-AA не ловится, скошенный прямоугольник без исключений")
    return 0


def main():
    if "--self-test" in sys.argv[1:]:
        return self_test()
    if len(sys.argv[1:]):
        print("использование: check_ui_assets.py [--self-test]")
        return 2

    if not os.path.isfile(MANIFEST):
        print("check_ui_assets: нет MANIFEST: %s" % MANIFEST)
        return 2
    with open(MANIFEST, encoding="utf-8") as f:
        manifest = json.load(f)["files"]

    violations = []
    checked = 0

    def audit(path, rel, kind):
        nonlocal checked
        checked += 1
        try:
            im = Image.open(path).convert("RGBA")
            im.load()
        except Exception as e:
            violations.append("%s: битый PNG (%s)" % (rel, e))
            return
        for v in check_corners(im):
            violations.append("%s: (a) %s" % (rel, v))
        if kind == "9-slice":
            for v in check_center(im):
                violations.append("%s: (b) %s" % (rel, v))
        for v in check_halo(im):
            violations.append("%s: (c) %s" % (rel, v))

    for d in WIDGET_DIRS:
        dd = os.path.join(UI_ROOT, "widgets", d)
        if not os.path.isdir(dd):
            continue
        for name in sorted(os.listdir(dd)):
            if not name.endswith(".png"):
                continue
            rel = "widgets/%s/%s" % (d, name)
            # Ключи MANIFEST.json — относительно game/assets/ui/widgets/.
            meta = manifest.get("%s/%s" % (d, name))
            if meta is None:
                violations.append("%s: файл не в MANIFEST.json" % rel)
                continue
            audit(os.path.join(dd, name), rel, meta.get("kind", ""))

    if os.path.isdir(ICONS_DIR):
        for name in sorted(os.listdir(ICONS_DIR)):
            if not name.endswith(".png"):
                continue
            audit(os.path.join(ICONS_DIR, name), "icons/%s" % name, "иконка")

    print("check_ui_assets: проверено %d файлов (widgets + icons)" % checked)
    if violations:
        print("check_ui_assets: %d нарушений:" % len(violations))
        for v in violations:
            print("  - %s" % v)
        return 1
    print("check_ui_assets: OK — чистый набор")
    return 0


if __name__ == "__main__":
    sys.exit(main())

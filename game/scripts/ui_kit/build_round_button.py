#!/usr/bin/env python3
"""Круглая плашка боевой кнопки (макет 11) — четыре состояния.

Макет 11 ставит нижний ряд боя не на плашки-плиты макета 09, а на круглые
кованые медальоны с золотым ободом. Пропорции и цвета сняты с самого макета
разрезом по центру кнопки (см. замеры ниже), а не на глаз: диффузионный
генератор не держит тонкое кольцо, а ручная рисовка ушла бы от макета.

Замер (нормированный кадр макета 1600×900, кнопка «Menu», центр (65, 810)):

    r 43..35   фон поля (внешняя область — остаётся прозрачной)
    r 33..30   тёмная внешняя нить      (16, 26, 34)
    r 29..24   золото обода             (150, 110, 70)
    r 23..21   тёмный паз               (17, 15, 16)
    r 19..17   светлый блик обода       (200, 176, 152)
    r 16..0    основание медальона      (62, 57, 53)

Диаметр медальона в макете — ~94 px при ширине кадра 1920, шаг ряда — 120 px.
Текстура пишется в 144 px, медальон занимает канву целиком (внешняя нить 66 из 72),
в игре контрол 100 px + зазор 20 px = те же 120 px шага.

Запуск: python3 game/scripts/ui_kit/build_round_button.py
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / "assets/ui/widgets/buttons"
CANVAS = 144
C = CANVAS / 2
# Радиусы переведены из замера (диаметр 80 → 96 в игре: коэффициент 1.2), затем
# развёрнуты так, чтобы медальон занял канву почти целиком: иначе контрол 96 px
# рисует диск 55 px и вёрстка расходится с макетом. Внешняя нить на 66 из 72 —
# запас 6 px под сдвиг нажатого состояния.
R_OUTLINE = 66
R_RIM = 58
R_GROOVE = 48
R_SHINE = 39
R_PLATE = 35

C_OUTLINE = (14, 20, 26)
C_RIM = (150, 110, 70)
C_RIM_SHINE = (206, 182, 154)
C_GROOVE = (18, 14, 12)
C_PLATE = (62, 57, 53)
C_PLATE_EDGE = (36, 32, 29)


def _mix(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))  # type: ignore[return-value]


def _bright(k: float):
    """Точка для Image.point: яркость с потолком 255."""
    return lambda v: min(255, round(v * k))


def _plate(size: int, center: float, base: tuple[int, int, int], edge: tuple[int, int, int]) -> Image.Image:
    """Основание медальона: радиальное затемнение к краю."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = size / 2
    for r in range(center, 0, -1):
        t = r / center
        d.ellipse([c - r, c - r, c + r, c + r], fill=(*_mix(base, edge, t * t), 255))
    return img


def build(state: str) -> Image.Image:
    img = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    def ring(r: float, color: tuple[int, int, int]) -> None:
        d.ellipse([C - r, C - r, C + r, C + r], fill=(*color, 255))

    ring(R_OUTLINE, C_OUTLINE)
    ring(R_RIM, C_RIM)
    ring(R_GROOVE, C_GROOVE)
    ring(R_SHINE, C_RIM_SHINE)
    plate = _plate(CANVAS, R_PLATE, C_PLATE, C_PLATE_EDGE)
    img.alpha_composite(plate)

    # Золотой обод светит сверху: половина дуги ярче, как на макете.
    shine = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shine)
    sd.arc(
        [C - (R_RIM + R_GROOVE) / 2, C - (R_RIM + R_GROOVE) / 2,
         C + (R_RIM + R_GROOVE) / 2, C + (R_RIM + R_GROOVE) / 2],
        200, 340, fill=(*C_RIM_SHINE, 190), width=int(R_RIM - R_GROOVE),
    )
    img.alpha_composite(shine)

    r, g, b, a = img.split()
    if state == "hover":
        k = 1.14
        img = Image.merge("RGBA", (r.point(_bright(k)), g.point(_bright(k)), b.point(_bright(k)), a))
    elif state == "pressed":
        k = 0.72
        pressed = Image.merge("RGBA", (r.point(_bright(k)), g.point(_bright(k)), b.point(_bright(k)), a))
        img = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
        img.paste(pressed, (0, 3))
    elif state == "disabled":
        gray = Image.merge("RGB", (r, g, b)).convert("L").convert("RGB")
        img = Image.merge("RGBA", (*[ch.point(_bright(0.55)) for ch in gray.split()], a.point(lambda v: round(v * 0.62))))
    return img


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    written = []
    for state in ("normal", "hover", "pressed", "disabled"):
        name = f"button_round_{state}.png"
        build(state).save(OUT / name)
        written.append(name)
    manifest_path = OUT.parent / "MANIFEST.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8")) if manifest_path.exists() else {}
    manifest["round_button"] = {
        "generator": "scripts/ui_kit/build_round_button.py",
        "mockup": "reference/11_battle_hex_snow.jpeg — нижний ряд боя: кованые медальоны, а не плиты макета 09",
        "measure": {
            "button_game_px": 100,
            "pitch_px": 120,
            "cut": "кнопка «Menu», центр (65, 810) нормированного кадра 1600×900",
            "rings_px_at_1600": {"outline": [30, 33], "rim": [24, 29], "groove": [21, 23], "shine": [17, 19], "plate": [0, 16]},
            "colors": {"outline": C_OUTLINE, "rim": C_RIM, "shine": C_RIM_SHINE, "groove": C_GROOVE, "plate": C_PLATE},
        },
        "derived_states_note": "hover/pressed/disabled выведены из normal затемнением/подсветкой; в макете нарисовано только normal.",
        "files": written,
    }
    # indent=1 — конвенция MANIFEST.json: indent=2 переписывает весь файл (+660 строк диффа).
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print("написано:", ", ".join(written), "в", OUT)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Укладка кадров контура на носители экрана «Карта» (T-274, D-281).

Кадры рисует `scripts/concept_art/generate.py` по спеке
`campaign_ui_spec.json` (отбор — ux-review кадрового листа, 2026-07-29: вариант
`u2_slate_brass`, три плитки заменены хроматическим `u2b_chromatic`). Фон,
обрезка по контенту и вписка — общие функции кита «Герой»
(`place_hero_art.keyed/trim/fit`), второй реализации альфа-ключа здесь нет.

Бокс иконки = пропорция прямоугольника строки реестра `docs/21-ux-map-screen.md`
(кадр 1920×1080), округлённая вверх: TextureRect растягивает носитель под
фактический размер, чужая пропорция = искажённый рисунок. Плита 9-slice своей
пропорции не меняет — её носитель и есть сам рисунок (см. `plate_box`).

Запуск: python3 scripts/ui_kit/place_campaign_art.py [--only id1,id2] [--dry]
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from place_hero_art import fit, keyed, trim  # общий альфа-ключ

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "image-clone"
OUT = ROOT / "game/assets/ui/campaign_screen"
GENERATOR = "krea2 (ComfyUI) / qwen-image-text-to-image"

# id кадра → (вариант, носитель, бокс w×h, kind, строка реестра). kind
# «иконка» рисуется в своём размере и берёт бокс; «9-slice» растягивается,
# поэтому его бокс — справка по клетке реестра, а размер носителя даёт
# plate_box().
TARGETS: dict[str, tuple[str, str, tuple[int, int], str, str]] = {
    # знаки и малые круглые кнопки
    "camp_medallion_ring": ("u2_slate_brass", "medallion_ring", (256, 256), "иконка", "medallion_ring"),
    "camp_turn_swords": ("u2_slate_brass", "button_swords", (80, 80), "иконка", "turn_swords"),
    "camp_turn_globe": ("u2_slate_brass", "button_globe", (88, 88), "иконка", "turn_globe"),
    "camp_date_gear": ("u2_slate_brass", "gear_date", (48, 48), "иконка", "date_gear"),
    "camp_tile_reset": ("u2_slate_brass", "tile_reset", (80, 80), "иконка", "tile_reset"),
    "camp_sign_food": ("u2b_chromatic", "chip_food", (48, 48), "иконка", "sign_food"),
    # медальон цели и чипы плашки имени
    "camp_medallion": ("u2_slate_brass", "medallion", (256, 256), "иконка", "medallion"),
    "camp_medallion_badge": ("u2_slate_brass", "medallion_badge", (80, 80), "иконка", "medallion_badge"),
    "camp_sign_coins": ("u2_slate_brass", "chip_coins", (48, 48), "иконка", "sign_coins"),
    "camp_sign_house": ("u2_slate_brass", "chip_house", (48, 48), "иконка", "sign_house"),
    "camp_sign_apple": ("u2_slate_brass", "chip_apple", (48, 48), "иконка", "sign_apple"),
    "camp_cart": ("u2_slate_brass", "cart_button", (96, 96), "иконка", "cart_button"),
    "camp_hero_marker": ("u2_slate_brass", "hero_marker", (80, 80), "иконка", "hero_marker"),
    "camp_button_book": ("u2_slate_brass", "button_book", (80, 80), "иконка", "button_book"),
    "camp_button_gear": ("u2_slate_brass", "button_gear", (80, 80), "иконка", "button_gear"),
    "camp_turn_big": ("u2_slate_brass", "turn_button", (192, 192), "иконка", "turn_button"),
    # глифы вертикальной плиты и иконки счётчиков
    "camp_glyph_tower": ("u2_slate_brass", "tile_city", (80, 80), "иконка", "tile_city"),
    "camp_glyph_rune": ("u2_slate_brass", "tile_party", (80, 80), "иконка", "tile_party"),
    "camp_glyph_chevron": ("u2_slate_brass", "tile_menu", (80, 80), "иконка", "tile_menu"),
    "camp_icon_drop_red": ("u2b_chromatic", "icon_drop_red", (48, 48), "иконка", "counter_drop_red"),
    "camp_icon_gem_green": ("u2b_chromatic", "icon_gem_green", (48, 48), "иконка", "counter_gem_green"),
    "camp_icon_coins": ("u2b_chromatic", "icon_gold", (48, 48), "иконка", "counter_gold"),
    # плиты (9-slice)
    "camp_plate_ability": ("u2_slate_brass", "plate_ability", (256, 128), "9-slice", "ability_frame"),
    "camp_plate_minimap": ("u2_slate_brass", "plate_minimap", (256, 256), "9-slice", "minimap"),
    "camp_plate_party": ("u2_slate_brass", "plate_party", (640, 112), "9-slice", "party_frame"),
    "camp_plate_counter": ("u2_slate_brass", "plate_counter", (512, 64), "9-slice", "counter_frame"),
    "camp_plate_slot": ("u2_slate_brass", "plate_slot", (96, 96), "9-slice", "party_block_left"),
    "camp_plate_sign": ("u2_slate_brass", "plate_sign", (256, 48), "9-slice", "sign_plaque"),
    "camp_plate_date": ("u2_slate_brass", "plate_date", (256, 48), "9-slice", "date_plaque"),
    "camp_plate_strip": ("u2_slate_brass", "plate_strip", (96, 256), "9-slice", "tile_city"),
    "camp_plate_panel": ("u2_slate_brass", "plate_panel", (640, 128), "9-slice", "counter_frame (плита полосы)"),
}
# Носитель, который едет ФОНОМ узла (stylebox), а не иконкой рядом с подписью:
# диск узла хода — это сама кнопка (пустой центр под надписью «ХОД»), а не знак.
STYLEBOX = {"turn_button"}
MARGIN = {"9-slice": 24}
PLATE_SHORT = 192    # короткая сторона плиты: margin 24 + центр, который тянется
PLATE_LONG = 640     # потолок длинной стороны (бюджет [[17-ui-style-guide]] §6.1)


def plate_box(im) -> tuple[int, int]:
    """Носитель 9-slice = сам рисунок в своей пропорции: растягивает его
    TextureRect, а `margin` защищает углы. Подгонка под широкую клетку реестра
    оставила бы в носителе прозрачные поля — они растягиваются в дыру вместо
    плитки (прецедент — квадратные `hero/panel_*.png` 256² с margin 40–48)."""
    s = PLATE_SHORT / min(im.size)
    if max(im.size) * s > PLATE_LONG:
        s = PLATE_LONG / max(im.size)
    return (max(1, round(im.width * s)), max(1, round(im.height * s)))


def seeds() -> dict[str, dict]:
    """(вариант, id) кадра → запись манифеста генератора (провенанс)."""
    path = SRC / "campaign_ui/manifest.json"
    if not path.is_file():
        return {}
    return {
        (r["variant"], r["id"]): r
        for r in json.loads(path.read_text(encoding="utf-8")).values()
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only")
    ap.add_argument("--dry", action="store_true")
    a = ap.parse_args()
    only = set(a.only.split(",")) if a.only else None
    seeds_ = seeds()
    files, rows = {}, []
    for cid, (variant, name, box, kind, reg) in TARGETS.items():
        src = next(iter(sorted((SRC / "campaign_ui").glob(f"*/{variant}/**/{cid}.webp"))), None)
        if src is None:
            print(f"{cid}: КАДРА НЕТ ({variant})")
            return 1
        im = trim(keyed(Image.open(src)))
        if kind == "9-slice":
            box = plate_box(im)
        out = fit(im, box, "contain")
        dest = OUT / f"{name}.png"
        rel = f"campaign_screen/{name}.png"
        rec = seeds_.get((variant, cid), {})
        meta = {
            "kind": kind,
            "size": [box[0], box[1]],
            **({"margin": MARGIN[kind]} if kind in MARGIN else {}),
            **({"mount": "stylebox"} if name in STYLEBOX else {}),
            "source": (
                f"{GENERATOR}, спек campaign_ui_spec.json, вариант {variant}, "
                f"seed {rec.get('seed', '?')}, кадр {'×'.join(map(str, rec.get('size', ['?', '?'])))}, "
                f"эталон — кропы макета 10 etalons_campaign/{rec.get('category', '?')}"
            ),
            "note": f"строка реестра: {reg}",
        }
        files[rel] = meta
        if not a.dry:
            dest.parent.mkdir(parents=True, exist_ok=True)
            out.save(dest)
        rows.append(f"{rel} {out.size} {kind}")
    if not a.dry:
        OUT.mkdir(parents=True, exist_ok=True)
        (OUT / "MANIFEST.json").write_text(
            json.dumps(
                {
                    "mockup": "design/single_window_layout/all_screens_ui.png (экран «Карта») + реестр docs/21-ux-map-screen.md",
                    "generator": GENERATOR,
                    "variants": ["u2_slate_brass (отбор: 27 кадров)", "u2b_chromatic (4 плитки)"],
                    "method": "контурный генератор scripts/concept_art/generate.py; "
                    "фон срезан альфа-ключом кита «Герой», обрезка по контенту, "
                    "вписка в бокс пропорции строки реестра",
                    "note": "отбор кадров — ux-review кадрового листа (T-274, D-281); "
                    "пиксели в git не идут без .import (D-185)",
                    "files": files,
                },
                ensure_ascii=False,
                indent=1,
            )
            + "\n",
            encoding="utf-8",
        )
    print("\n".join(rows))
    print(f"итого: {len(rows)} носителей → {OUT.relative_to(ROOT)}" + (" (dry)" if a.dry else ""))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

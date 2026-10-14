#!/usr/bin/env python3
"""Перекраска 9-slice текстур кнопки из синего семейства (П-1) в дерево/латунь канона.

Синее семейство кнопок (`#2659bf` и т.д.) — находка П-1/К-1 реестра
docs/17-ui-style-guide.md §9: оно жило и в коде (ThemeConfig.C_BTN_*), и в этих
четырёх текстурах. Геометрия текстур правильная (2 px рамка + поле, 32×32), цвет —
нет. Скрипт меняет только цвет: яркость каждого пикселя источника становится
коэффициентом смешивания двух канонических опор (поле → рамка), поэтому рамка,
поле и сглаживание по краям сохраняются побайтово-пропорционально.

Значения — токены [[13-art-bible]] §4.1 / гайд §1.2, новых чисел нет:
  normal   поле C_PANEL_BORDER  #3a2415, рамка C_GOLD        #8a6a3a
  hover    поле C_PANEL         #4a3423, рамка C_GOLD_BRIGHT #9e7738
  pressed  поле C_BG            #281c0f, рамка C_GOLD        #8a6a3a
  disabled поле #241d16,         рамка #4a3d2c  (латунь в 50% саже, §4.1 disabled)

Запуск: python3 game/tools/recolor_button_textures.py [--dry-run]
"""
import sys
from pathlib import Path

from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "assets/ui/widgets/buttons"

# (поле, рамка) — канонические опоры на состояние
STATES = {
    "button_normal": ("#3a2415", "#8a6a3a"),
    "button_hover": ("#4a3423", "#9e7738"),
    "button_pressed": ("#281c0f", "#8a6a3a"),
    "button_disabled": ("#241d16", "#4a3d2c"),
}


def rgb(h: str) -> tuple[int, int, int]:
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def recolor(src: Path, field: str, frame: str) -> bytes:
    lo, hi = rgb(field), rgb(frame)
    im = Image.open(src).convert("RGBA")
    px = im.load()
    lum = lambda p: 0.3 * p[0] + 0.6 * p[1] + 0.1 * p[2]
    vals = [lum(px[x, y]) for y in range(im.height) for x in range(im.width)]
    vmin, vmax = min(vals), max(vals)
    span = max(vmax - vmin, 1.0)
    for y in range(im.height):
        for x in range(im.width):
            p = px[x, y]
            t = (lum(p) - vmin) / span
            px[x, y] = tuple(round(lo[i] + (hi[i] - lo[i]) * t) for i in range(3)) + (p[3],)
    import io
    buf = io.BytesIO()
    im.save(buf, "PNG")
    return buf.getvalue()


def main() -> int:
    dry = "--dry-run" in sys.argv
    for name, (field, frame) in STATES.items():
        src = OUT / f"{name}.png"
        data = recolor(src, field, frame)
        print(f"{'dry ' if dry else 'WROTE'} {src.relative_to(OUT.parent.parent.parent)}"
              f"  field={field} frame={frame}  {len(data)} B")
        if not dry:
            src.write_bytes(data)
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Нарезка фигур боя из арта владельца (alpha-battle-field 3.1).

Носитель — пять отдельных кадров героя на белом фоне (`~/Downloads/
Interface_battle/1793072846892-…_NN_….png`). Фон снимается существующим
вырезателем экрана «Герой» (`place_hero_art.keyed`), а не вторым экземпляром
формулы: правило «мелкое белое — блик, остаётся» уже отлажено на светлых
носителях, и переписывать его здесь значило бы получить второй, худший.

Фигуры пишутся в `game/assets/units/figures/` — НЕ в `assets/units/`: там
лежат портреты юнитов тех же ключей (`assets/units/archers.png`), и файл
фигуры по тому же пути молча съел бы портрет.

Размер не подгоняется: масштаб и опорная точка — решение поля (3.3), запечь
его здесь означало бы переписывать ассеты после каждой правки камеры.

Листа существ (дракон, скорпион, змея, волк) среди присланного нет — в
композиционном референсе волки нарисованы внутри сцены, а не отдельным комплектом
на белом, поэтому `wolves`/`red_dragon` остаются портретами (правило 3.2
«нет совпадения силуэта — нет фигуры»).

Запуск: python3 scripts/ui_kit/place_battle_art.py [--dry]
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import place_hero_art as kit  # noqa: E402  (тот же вырезатель, не второй экземпляр)

ROOT = Path(__file__).resolve().parents[2]
SRC = Path.home() / "Downloads/Interface_battle"
OUT = ROOT / "game/assets/units/figures"
ALPHA_TRIM = 8            # порог отреза: ниже — уже фон, а не кромка фигуры

# хвост имени носителя → (файл фигуры, силуэт). Имена — хвосты UUID-кадров,
# целиком они меняются от выгрузки к выгрузке.
FIGURES = {
    "_00_3717846d.png": ("archers", "лучник в капюшоне, лук"),
    "_01_03e1a4a1.png": ("swordsmen", "мечник в плаще, меч остриём вниз"),
    "_02_0939b37c.png": ("knights", "рыцарь в закрытом шлеме, бердыш"),
    "_03_e623e376.png": ("battle_dwarf", "дворф с молотом, килт"),
    "_12_cdd81032.png": ("paladin", "паладин с булавой, щит и знамя"),
}


def cut(src: Path) -> Image.Image:
    fig = kit.keyed(Image.open(src).convert("RGB"))
    # trim по порогу, а не по «любой ненулевой альфе»: мягкая кромка вырезателя
    # оставляет у краёв кадра альфу 1–8, и без порога bbox = весь кадр, то есть
    # «стопы в нижней строке» (опора, 3.3) уезжают на несколько пикселей.
    bbox = fig.split()[-1].point(lambda a: 255 if a > ALPHA_TRIM else 0).getbbox()
    return fig.crop(bbox) if bbox else fig


def report(name: str, fig: Image.Image) -> str:
    """Мера приёмки: альфа есть, фон прозрачен, светлое не съедено."""
    alpha = fig.split()[-1]
    opaque = sum(1 for a in alpha.tobytes() if a > 128)
    corners = [alpha.getpixel(p) for p in [(0, 0), (fig.width - 1, 0),
                                           (0, fig.height - 1), (fig.width - 1, fig.height - 1)]]
    raw = fig.convert("RGB").tobytes()
    light = sum(1 for i in range(0, len(raw), 3)
                if min(raw[i:i + 3]) >= kit.NEAR_WHITE)  # светлые детали внутри фигуры
    return (f"{name}: {fig.width}×{fig.height}, непрозрачных {opaque} "
            f"({100.0 * opaque / (fig.width * fig.height):.0f}%), углы {max(corners)}, "
            f"светлых пикселей {100.0 * light / (fig.width * fig.height):.1f}%")


def main() -> int:
    dry = "--dry" in sys.argv
    OUT.mkdir(parents=True, exist_ok=True)
    bad = 0
    for tail, (name, _) in FIGURES.items():
        src = next(SRC.glob(f"*{tail}"), None)
        if src is None:
            print(f"  нет носителя *{tail} в {SRC}")
            bad += 1
            continue
        fig = cut(src)
        line = report(name, fig)
        if fig.split()[-1].getextrema()[1] == 0 or max(
                fig.split()[-1].getpixel(p) for p in [(0, 0), (fig.width - 1, fig.height - 1)]) > 0:
            line += "  ⚠ фон не прозрачен / альфы нет"
            bad += 1
        print(" ", line)
        if not dry:
            fig.save(OUT / f"{name}.png")
    print(("проверка (без записи) " if dry else "записано в ") + str(OUT))
    return 1 if bad else 0


if __name__ == "__main__":
    raise SystemExit(main())

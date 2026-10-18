#!/usr/bin/env python3
"""Замер полосы «содержимое» (C′) по живым ассетам.

Основание: Q-M43 → (а) (владелец, 2026-10-16). Полоса содержимого выводится из того,
что уже стоит в игре (`building_*.webp`), а не из референса: референс-носитель
полосы C (`reference/01`) утрачен 2026-10-17 и чисел не даёт. Лист `world_tiles.webp`
из пула снят 2026-10-18 (шаг 4.1 world-map-art-variety: файл удалён, карта принята
полосой M, D-203) — вердикт о судьбе `C′` без тайлов открыт, Q-M89.

Приёмка нового ассета содержимого: каждый его кластер в ΔE ≤ 12 (CIE76) до ближайшего
тона полосы C′. Порог — прежний допуск §8.5, изменён только носитель полосы.

Замер тот же, что в §4.6: k-means по содержимому (8 кластеров), почти-белый фон и
прозрачные пиксели исключены, lum/sat — по пикселям кластера.

Запуск:  python3 scripts/measure_palette_band.py [--game game]
"""

from __future__ import annotations

import argparse
import glob
import math
import os

import numpy as np
from PIL import Image

K = 8                 # кластеров на файл — та же мера, что в §4.6
SEED = 0              # замер должен быть воспроизводим
ITERS = 12
MIN_ALPHA = 16        # прозрачные пиксели листа не участвуют
MAX_LUM = 0.92        # почти-белый фон листа исключён
BAND_K = 7            # тонов в описании полосы — столько же, сколько было у полосы C в §4.6
ACCEPT_DE = 12.0      # допуск приёмки (§8.5)
DOM_SHARE = 0.08      # кластер файла считается доминирующим тоном (входит в носитель полосы)
MERGE_DE = ACCEPT_DE  # тона полосы совпадают, если ближе допуска приёмки: полоса = максимум
                      # множество тонов, попарно разнесённых на ΔE > 12
SAMPLE = 20_000       # пикселей на файл в общий пул (вес файла одинаков, размер не важен)


def srgb_to_linear(c: np.ndarray) -> np.ndarray:
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def lum(rgb: np.ndarray) -> np.ndarray:
    """Относительная яркость (та же формула, что в WCAG-таблицах §4.2/§4.5)."""
    lin = srgb_to_linear(rgb)
    return lin[..., 0] * 0.2126 + lin[..., 1] * 0.7152 + lin[..., 2] * 0.0722


def sat(rgb: np.ndarray) -> np.ndarray:
    """Насыщенность HSL (не HSV) — как в замерах §4.6."""
    mx = rgb.max(axis=-1)
    mn = rgb.min(axis=-1)
    denom = np.maximum(1.0 - np.abs(mx + mn - 1.0), 1e-9)
    return np.where(mx == mn, 0.0, (mx - mn) / denom)


def rgb_to_lab(rgb: np.ndarray) -> np.ndarray:
    """sRGB → CIE76 Lab (D65)."""
    lin = srgb_to_linear(rgb)
    m = np.array([[0.4124564, 0.3575761, 0.1804375],
                  [0.2126729, 0.7151522, 0.0721750],
                  [0.0193339, 0.1191920, 0.9503041]])
    xyz = lin @ m.T
    xyz = xyz / np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    lab = np.empty_like(xyz)
    lab[..., 0] = 116 * f[..., 1] - 16
    lab[..., 1] = 500 * (f[..., 0] - f[..., 1])
    lab[..., 2] = 200 * (f[..., 1] - f[..., 2])
    return lab


def de76(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    return np.sqrt(((a - b) ** 2).sum(axis=-1))


def kmeans(px: np.ndarray, k: int = K) -> list[tuple[tuple[int, int, int], float, float, float]]:
    """Кластеры [(hex, доля, lum, sat)], отсортированные по доле. `px` — (N,3) uint8."""
    px = px.reshape(-1, 3).astype(np.float64) / 255.0
    rng = np.random.default_rng(SEED)
    cent = px[rng.choice(len(px), size=k, replace=False)]
    for _ in range(ITERS):
        d = ((px[:, None, :] - cent[None, :, :]) ** 2).sum(axis=-1)
        lab = d.argmin(axis=1)
        for j in range(k):
            m = lab == j
            if m.any():
                cent[j] = px[m].mean(axis=0)
    d = ((px[:, None, :] - cent[None, :, :]) ** 2).sum(axis=-1)
    lab = d.argmin(axis=1)
    out = []
    for j in range(k):
        m = lab == j
        if not m.any():
            continue
        share = float(m.mean())
        tone = np.clip(cent[j], 0, 1)
        out.append((
            (int(round(tone[0] * 255)), int(round(tone[1] * 255)), int(round(tone[2] * 255))),
            share,
            float(lum(tone)[()]),
            float(sat(tone)[()]),
        ))
    return sorted(out, key=lambda t: -t[1])


def load_pixels(path: str) -> np.ndarray | None:
    """Непрозрачные пиксели файла без почти-белого фона: (N,3) uint8."""
    im = Image.open(path).convert("RGBA")
    a = np.asarray(im)
    keep = a[..., 3] >= MIN_ALPHA
    rgb = a[..., :3][keep]
    if len(rgb) == 0:
        return None
    rgb = rgb[lum(rgb.astype(np.float64) / 255.0) <= MAX_LUM]
    return rgb if len(rgb) else None


def sample(rgb: np.ndarray, n: int = SAMPLE, seed: int = SEED) -> np.ndarray:
    if len(rgb) <= n:
        return rgb
    rng = np.random.default_rng(seed)
    return rgb[rng.choice(len(rgb), size=n, replace=False)]


def family(px: np.ndarray) -> list[tuple[tuple[int, int, int], float, float, float]]:
    """Семейство тонов-носителей пула пикселей: доминирующие, с близкими слиянием."""
    out: list[tuple[tuple[int, int, int], float, float, float]] = []
    for tone, share, l, s in sorted(kmeans(px), key=lambda m: -m[1]):
        if share < DOM_SHARE:
            continue
        if any(de76(tone_lab(tone), tone_lab(t[0])) < MERGE_DE for t in out):
            continue
        out.append((tone, share, l, s))
    out.sort(key=lambda t: t[2])
    return out


def hexs(tone: tuple[int, int, int]) -> str:
    return "#{:02x}{:02x}{:02x}".format(*tone)


def tone_lab(tone: tuple[int, int, int]) -> np.ndarray:
    rgb = np.array(tone, dtype=np.float64)[None, :] / 255.0
    return rgb_to_lab(rgb)[0]


def contrast(fg: tuple[int, int, int], bg: tuple[int, int, int]) -> float:
    """WCAG 1.4.11 / 1.4.3: (L1+0.05)/(L2+0.05)."""
    a = float(lum(np.array(fg, dtype=np.float64) / 255.0)[()])
    b = float(lum(np.array(bg, dtype=np.float64) / 255.0)[()])
    hi, lo = max(a, b), min(a, b)
    return (hi + 0.05) / (lo + 0.05)


def parse_hex(s: str) -> tuple[int, int, int]:
    s = s.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))  # type: ignore[return-value]


def _check(paths: list[str], tones: list[tuple[tuple[int, int, int], float, float, float]]) -> int:
    print(f"\n== проверка кандидата (порог ΔE {ACCEPT_DE:.0f}) ==")
    bad = 0
    for path in paths:
        px = load_pixels(path)
        if px is None:
            print(f"  {os.path.basename(path):34s} — не читается")
            bad += 1
            continue
        worst, worst_tone = 0.0, "—"
        for tone, share, _l, _s in kmeans(px):
            if share < DOM_SHARE:
                continue
            d = float(min(de76(tone_lab(tone), tone_lab(t[0])) for t in tones))
            if d > worst:
                worst, worst_tone = d, hexs(tone)
        verdict = "в допуске" if worst <= ACCEPT_DE else "ВНЕ ДОПУСКА"
        bad += worst > ACCEPT_DE
        print(f"  {os.path.basename(path):34s} max ΔE {worst:5.1f} (тон {worst_tone}) → {verdict}")
    return 1 if bad else 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--game", default="game", help="каталог проекта (game/)")
    ap.add_argument("--json", action="store_true", help="машинный вывод полосы")
    ap.add_argument("--check", nargs="+", metavar="ФАЙЛ", help="проверить ассет-кандидат на полосу")
    ap.add_argument("--tone", nargs="+", metavar="#RRGGBB",
                    help="lum/sat/контраст тона к подложке (--on), проверка правил §4.7/§9.2")
    ap.add_argument("--on", default="#281c0f", help="подложка для --tone (по умолчанию тон тайла)")
    ap.add_argument("--band-m", action="store_true",
                    help="приёмка не по C′ (выведена из проверяемых ассетов), а по фиксированной "
                         "полосе M из map_art_gates.json — полосе КАРТЫ. Нужна, чтобы отличить "
                         "«ассет плох» от «меру приложили не к тому классу ассетов»")
    ap.add_argument("--pool-include", metavar="ФАЙЛ",
                    help="добавить файл в пул C′ (тест вакуумности: вернуть в пул удалённый "
                         "носитель и посмотреть, щёлкнет ли приёмка при неизменных зданиях)")
    ap.add_argument("--band-from", metavar="ФАЙЛ",
                    help="полоса и семейство тонов произвольного кадра-эталона "
                    "(носитель полосы — канонический кадр, а не живые ассеты)")
    args = ap.parse_args()

    if args.tone:
        bg = parse_hex(args.on)
        print(f"тона против подложки {args.on} (контраст — WCAG, порог 3:1 для нетекстового носителя)")
        for raw in args.tone:
            tone = parse_hex(raw)
            rgb = np.array(tone, dtype=np.float64) / 255.0
            l, s = float(lum(rgb)[()]), float(sat(rgb)[()])
            c = contrast(tone, bg)
            print(f"  {hexs(tone)}  lum {l:.2f}  sat {s:.2f}  контраст {c:5.2f}:1  "
                  f"{'OK' if c >= 3.0 else 'НИЖЕ 3:1'}")
        return 0

    if args.band_from:
        px = load_pixels(args.band_from)
        if px is None:
            print(f"{args.band_from}: нет непрозрачных пикселей")
            return 2
        print(f"== полоса кадра {os.path.basename(args.band_from)} ({BAND_K} тонов) ==")
        for tone, share, l, s_ in sorted(kmeans(px, BAND_K), key=lambda b: b[2]):
            print(f"  {hexs(tone)}  lum {l:.2f}  sat {s_:.2f}  {share:5.1%}")
        fam = family(px)
        print(f"\n== семейство тонов-носителей кадра (слияние ΔE < {MERGE_DE:.0f}) ==")
        for tone, _share, l, s_ in fam:
            print(f"  {hexs(tone)}  lum {l:.2f}  sat {s_:.2f}")
        print(f"  тонов: {len(fam)}")
        if args.check:
            return _check(args.check, fam)
        return 0

    buildings = sorted(glob.glob(os.path.join(args.game, "assets/textures/objects/building_*.webp")))
    extra = [args.pool_include] if args.pool_include else []
    if not buildings:
        print(f"живых ассетов не найдено под {args.game}/assets — запускать из корня репо")
        return 2
    print("носитель C′ — живые здания; карта (лист world_tiles.webp удалён 2026-10-18) "
          "принимается полосой M — см. D-203, Q-M89")

    measured: list[tuple[str, tuple[int, int, int], float, float, float]] = []
    pool: list[np.ndarray] = []
    print("== замер живых ассетов содержимого (k-means, k=8, seed=0) ==")
    for path in buildings:
        name = os.path.basename(path)
        px = load_pixels(path)
        if px is None:
            print(f"  {name:34s} — нет непрозрачных пикселей")
            continue
        pool.append(sample(px))
        for tone, share, l, s in kmeans(px):
            measured.append((name, tone, share, l, s))
            print(f"  {name:34s} {hexs(tone)}  lum {l:.2f}  sat {s:.2f}  {share:5.1%}")

    for path in extra:
        px = load_pixels(path)
        if px is None:
            print(f"  {os.path.basename(path)}: не читается — в пул не добавлен")
            continue
        pool.append(sample(px))
        print(f"  + в пул C′ добавлен внешний носитель: {os.path.basename(path)} "
              f"(не здание; приёмка зданий при этом меряется по тем же 12 файлам)")

    # Полоса C′ = k-кластерное квантование ОБЪЕДИНЁННОГО содержимого живых ассетов.
    # Вес файла одинаков (проба на файл), чтобы один крупный лист не переопределил полосу.
    print(f"\n== полоса C′ (носитель — живые ассеты; {BAND_K} тонов, общий пул проб) ==")
    band = []
    for tone, share, l, s in kmeans(np.concatenate(pool, axis=0), BAND_K):
        band.append((tone, share, l, s))
    band.sort(key=lambda b: b[2])
    for tone, share, l, s in band:
        print(f"  {hexs(tone)}  lum {l:.2f}  sat {s:.2f}  {share:5.1%}")
    print(f"  тонов полосы: {len(band)}")

    # Носитель приёмки — не сжатые 7 тонов, а семейство доминирующих тонов живых
    # ассетов: новый ассет обязан попасть в ΔE ≤ 12 к одному из них.
    tones = family(np.concatenate(pool, axis=0))
    print(f"\n== семейство тонов-носителей (доля ≥ {DOM_SHARE:.0%}, слияние ΔE < {MERGE_DE:.0f}) ==")
    for tone, share, l, s in tones:
        print(f"  {hexs(tone)}  lum {l:.2f}  sat {s:.2f}")
    print(f"  тонов: {len(tones)}")
    print("\nПриёмка нового ассета: --check <файл> → максимум ΔE его доминирующих тонов")
    print(f"до ближайшего тона-носителя; порог {ACCEPT_DE:.0f} (прежний допуск §8.5).")

    if args.check and args.band_m:
        import json
        cfg = json.load(open(os.path.join(args.game, "data/config/map_art_gates.json"), encoding="utf-8"))
        band_m = [(parse_hex(h), 1.0, 0.0, 0.0) for h in cfg["palette"]["band_m"]]
        print(f"\n== приёмка по полосе M ({len(band_m)} тонов, фиксированный конфиг "
              f"map_art_gates.json; к пулу C′ отношения не имеет) ==")
        print("   ПОЛОСА M — ЭТО ПОЛОСА КАРТЫ (строка §4.6 «M. Палитра карты», гейт atlas/palette). "
              "Здания канонически принимаются по C′ (§9.1, §4.6 «здания … C′»), поэтому «вне M» для "
              "здания — не дефект, а признак другого класса ассетов; читать вывод надо так же, как "
              "32.0: это расстояние между классами, а не падение.")
        return _check(args.check, band_m)

    if args.check:
        return _check(args.check, tones)

    if args.json:
        import json
        print(json.dumps({
            "band": [{"hex": hexs(t), "lum": round(l, 3), "sat": round(s, 3)} for t, _sh, l, s in band],
            "tones": [{"hex": hexs(t), "lum": round(l, 3), "sat": round(s, 3)} for t, _sh, l, s in tones],
            "accept_de": ACCEPT_DE,
        }, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

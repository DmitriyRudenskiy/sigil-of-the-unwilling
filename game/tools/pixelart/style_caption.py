#!/usr/bin/env python3
"""Подписи-капшены к нарезке юнитов — одним файлом, для обучения LoRA.

    python3 game/tools/pixelart/style_caption.py \
        --images ~/Downloads/_make_for_lora/units_tight

Строка файла: `путь\\tкапшен`, где капшен = фиксированная префиксная фраза
(«A descriptive caption for this image, art style and body proportion:») и три
блока через `; ` — стиль (палитра, насыщенность, значения, штрих, тёмная масса,
тёплое/холодное, разброс оттенков), пропорции силуэта (аспект, плотность,
компактность, центр массы, зазубренность) и словесная форма тега стиля. Тег в
капшен вписан словом, а не папкой, потому что трейнер капшен читает, а
директорию — нет.

Откуда слова. Каждый числовой признак режется по **терцилям самого корпуса**:
«muted colours» значит «в нижней трети корпуса по насыщенности», а не «на глаз
бледно». Стилевые признаки — из реестра `style_features.csv` (из него же
выросли теги), пропорции — из силуэта кадра той же функцией `geometry()`, что и
в `style_probe.py`.

Чего в подписях нет, и почему. Ни одной анатомической числи («голов в рост»,
доля головы) — измерить голову по силуэту этого корпуса не удалось: кадры
обрезаны по оружию, знамёнам и плащам, поэтому «верхняя полоса» это не голова.
Измеренные проксии головы не отделяют тег `4_anime_chibi`
(AUC 0.52–0.58 при 0.674 у всей геометрии целиком и 0.974 у ViT, см.
`docs/18-lora-style-groups.md`), а писать «large head» на глаз — значит
утверждать про кадр то, чего не мерили. Слово `chibi` вносит это вместе со
смыслом тега, числа от меня там нет.

Оговорка: `style_features.csv` снят с кадров до правки вырезания (светлый
костюм вырезался как фон), то есть стилевые слова местами описывают чуть более
«белую» версию кадра; пересчёт партиции — остаток T-210.
"""
from __future__ import annotations

import argparse
import csv
import os
import sys
from collections import Counter

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from style_probe import geometry, read_csv  # noqa: E402

PREFIX = 'A descriptive caption for this image, art style and body proportion:'

# Стиль: признак реестра → три фразы (нижняя терциль / середина / верхняя).
STYLE = [
    ('ncol', ['limited palette', 'moderate-size palette', 'rich palette']),
    ('sat', ['muted low-saturation colours', 'moderately saturated colours',
             'vivid high-saturation colours']),
    ('val', ['dark low-key values', 'mid-tone values', 'bright high-key values']),
    ('valstd', ['flat shading with little value spread', 'moderate value range',
                'broad value range with strong light-to-dark steps']),
    ('chromastd', ['narrow chroma range', 'moderate chroma range', 'wide chroma range']),
    ('edge', ['soft low-contrast edges', 'clear edges', 'crisp high-contrast linework']),
    ('dark', ['mostly light masses', 'balanced light and dark masses',
              'heavy dark mass with bold shadows']),
    ('warm', ['cool hue bias', 'neutral hue balance', 'warm hue bias']),
    ('hue_entropy', ['broad hue spread', 'moderate hue spread',
                     'narrow hue-focused palette']),
]
# Пропорции: индекс скаляра в векторе geometry() → три фразы.
GEOM = [
    (288, ['narrow tall silhouette', 'medium-width silhouette', 'broad squat silhouette']),
    (289, ['sparse spindly silhouette', 'average silhouette density', 'dense solid silhouette']),
    (290, ['loose irregular outline', 'moderately compact outline', 'compact convex outline']),
    (294, ['mass centred high, heavy upper body', 'mass centred at the waist',
           'mass centred low, heavy lower body']),
    (297, ['smooth outline', 'moderately detailed outline', 'spiky detail-heavy outline']),
]
# Тег → словесная форма (то, что тег значит для промпта, а не имя папки).
GROUP = {
    '1_cartoon': 'cartoon-style figure',
    '2_comic_fx': 'comic-book style figure with effects',
    '3_warm_pastel': 'warm pastel-toned figure',
    '4_anime_chibi': 'anime chibi-style figure',
}


def bucket(v, q, phrases):
    return phrases[int((v > q).sum())]        # q — две границы терцилей


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--images', required=True, help='папка нарезки (units_tight)')
    ap.add_argument('--labels', default=os.path.join(HERE, 'style_labels.csv'))
    ap.add_argument('--features', default=os.path.join(HERE, 'style_features.csv'))
    ap.add_argument('--out', default=None,
                    help='TSV путь\\tкапшен; по умолчанию <images>/../captions.tsv')
    a = ap.parse_args()
    images = os.path.abspath(a.images)
    out = a.out or os.path.join(os.path.dirname(images), 'captions.tsv')

    feats = {r['cell']: r for r in read_csv(a.features)}
    group = {r['cell']: r['group'] for r in read_csv(a.labels)}
    files = []
    for root, _, names in os.walk(images):        # кадры в подкаталогах по тегам
        for f in sorted(names):
            if f.endswith('.png'):
                files.append(os.path.relpath(os.path.join(root, f), images))
    if not files:
        raise SystemExit(f'в {images} нет ни одного .png')
    cells = ['_'.join(os.path.basename(f)[:-4].split('_')[:2]) for f in files]
    miss = [c for c in cells if c not in feats]
    if miss:
        raise SystemExit(f'{len(miss)} кадров без строк в {a.features} '
                         f'(пример {miss[0]}) — реестр не по этой нарезке')

    S = {k: np.array([float(feats[c][k]) for c in cells]) for k, _ in STYLE}
    G = np.array([geometry(os.path.join(images, f)) for f in files])
    sq = {k: np.quantile(v, [1 / 3, 2 / 3]) for k, v in S.items()}
    gq = {i: np.quantile(G[:, i], [1 / 3, 2 / 3]) for i, _ in GEOM}

    lines, slots = [], {}
    for i, (f, c) in enumerate(zip(files, cells)):
        style = [bucket(S[k][i], sq[k], w) for k, w in STYLE]
        style[0] = f'{int(S["ncol"][i])}-colour {style[0]}'
        prop = [bucket(G[i, j], gq[j], w) for j, w in GEOM]
        parts = style + prop + [GROUP[group[c]]]
        for n, p in enumerate(parts):
            slots.setdefault((n, 'slot'), Counter())[p] += 1
        lines.append(f'{f}\t{PREFIX} {"; ".join(parts)}.')

    with open(out, 'w') as fh:
        fh.write('\n'.join(lines) + '\n')

    # Контроль нетривиальности: если слот выродился в одно слово на всём
    # корпусе — терцили не разделили признак, подписи врут однообразием.
    dead = [n for (n, _), c in slots.items() if len(c) == 1]
    print(f'капшенов {len(lines)} → {out}')
    print(f'слотов {len(slots)}, выродившихся (одно значение у всех кадров): {len(dead)}'
          + (f' — {sorted(dead)}' if dead else ''))
    for n in sorted(slots)[:3]:
        top = slots[n].most_common(2)
        print(f'  слот {n[0]:2d}: ' + ' · '.join(f'{w} ×{k}' for w, k in top))
    return 1 if dead else 0


if __name__ == '__main__':
    sys.exit(main())

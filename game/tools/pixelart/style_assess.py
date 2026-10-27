#!/usr/bin/env python3
"""Оценка стиля нарезки: цветово-краевые признаки, близость к известным тегам,
число стилевых направлений в самой партии.

Смысл чисел (важнее самих чисел): признаки — только цвет и штрих, контент
(поза, типаж, реквизит) не контролируется. Поэтому «кадр ближе к центру
`2_comic_fx`» — утверждение о палитре и контуре, а не о том, что диффуз
послушно различит теги при генерации. Арбитр тегов — ablation LoRA, T-210
(урок D-259: линейная декодируемость ≠ стиль для условной генерации).

Признаки считаются по кадру целиком, силуэт = «не почти-белый» (минимум
каналов < 245), палитра — RGB по 4 бита на канал:

  ncol        цветов в палитре силуэта
  sat         средняя насыщенность (HSV S)
  val         средняя яркость (HSV V)
  valstd      разброс яркости
  chromastd   разброс хроматичности (max−min по каналам)
  edge        средний модуль градиента серого — мера «жёсткости штриха»
  dark        доля тёмных пикселей (V < 0.35)
  warm        доля тёплого hue среди насыщенных (S > 0.15)
  hue_entropy энтропия гистограммы hue (36 бинов), делённая на log 36
  hue_max     доля крупнейшего бина hue

Прогон:

    python3 style_assess.py --old ~/Downloads/_make_for_lora/units_tight \\
                            --new ~/Downloads/objects_flat
"""
from __future__ import annotations

import argparse
import csv
import os

import cv2
import numpy as np
from PIL import Image
from sklearn.cluster import KMeans
from sklearn.metrics import silhouette_score
from sklearn.preprocessing import StandardScaler

KEYS = ['ncol', 'sat', 'val', 'valstd', 'chromastd', 'edge', 'dark', 'warm',
        'hue_entropy', 'hue_max']
SEED = 0


def features(path: str) -> list[float]:
    """Десять цветово-краевых признаков кадра. Только цвет и штрих."""
    rgb = np.asarray(Image.open(path).convert('RGB'), dtype=np.float32)
    m = rgb.min(2) < 245.0
    px = rgb[m]
    if len(px) < 64:
        return [0.0] * len(KEYS)
    hsv = cv2.cvtColor(rgb.astype(np.uint8), cv2.COLOR_RGB2HSV)   # H 0..179, S/V 0..255
    h, s, v = hsv[..., 0][m], hsv[..., 1][m], hsv[..., 2][m]
    gray = cv2.cvtColor(rgb.astype(np.uint8), cv2.COLOR_RGB2GRAY).astype(np.float32)
    gx, gy = cv2.Sobel(gray, cv2.CV_32F, 1, 0), cv2.Sobel(gray, cv2.CV_32F, 0, 1)
    grad = np.hypot(gx, gy)[m] / 255.0
    chroma = px.max(1) - px.min(1)
    hist = np.histogram(h[s > 38], bins=36, range=(0, 180))[0]
    p = hist / max(hist.sum(), 1)
    ent = -(p[p > 0] * np.log(p[p > 0])).sum() / np.log(36)
    warm = ((h < 45) | (h > 165)) & (s > 38)
    return [float(len(np.unique((rgb[m] // 16).astype(np.int16), axis=0))),
            float(s.mean() / 255), float(v.mean() / 255), float(v.std() / 255),
            float(chroma.std() / 255), float(grad.mean()),
            float((v < 89).mean()), float(warm.sum() / max((s > 38).sum(), 1)),
            float(ent), float(p.max())]


def load(root: str) -> tuple[list[str], np.ndarray, np.ndarray]:
    """Кадры дерева (рекурсивно) → пути, признаки, тег из подкаталога ('' если его нет)."""
    files, rows, tags = [], [], []
    for dirpath, _, names in os.walk(root):
        for name in sorted(n for n in names if n.endswith('.png')):
            files.append(os.path.relpath(os.path.join(dirpath, name), root))
            rows.append(features(os.path.join(dirpath, name)))
            rel = os.path.relpath(dirpath, root)
            tags.append('' if rel == '.' else rel)
    return files, np.array(rows), np.array(tags)


def nearest(X: np.ndarray, cent: np.ndarray, tags: np.ndarray):
    """Ближайший центр тега и его отрыв от второго (margin, в z-единицах)."""
    d = ((X[:, None, :] - cent[None, :, :]) ** 2).sum(-1) ** 0.5
    order = np.argsort(d, axis=1)
    tag = tags[order[:, 0]]
    margin = d[np.arange(len(X)), order[:, 1]] - d[np.arange(len(X)), order[:, 0]]
    return tag, margin, d.min(1)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--old', help='размеченная нарезка (подкаталоги = теги)')
    ap.add_argument('--new', help='оцениваемая нарезка')
    ap.add_argument('--out', default=None, help='csv вида кадр,тег,отрыв')
    ap.add_argument('--selftest', action='store_true')
    args = ap.parse_args()
    if args.selftest:
        return selftest()
    if not (args.old and args.new):
        ap.error('нужны --old и --new (или --selftest)')

    _, Xo, yo = load(args.old)
    files, Xn, _ = load(args.new)
    scaler = StandardScaler().fit(Xo)
    Zo, Zn = scaler.transform(Xo), scaler.transform(Xn)
    tags = np.unique(yo)
    cent = np.array([Zo[yo == t].mean(0) for t in tags])

    print(f'старая нарезка: {len(Xo)} кадров, теги {[(t, int((yo == t).sum())) for t in tags]}')
    print(f'новая нарезка : {len(Xn)} кадров')
    print('\nсредние признаки (старое → новое, z = сдвиг нового относительно старого):')
    for i, k in enumerate(KEYS):
        mu, sd = Xo[:, i].mean(), Xo[:, i].std() or 1.0
        z = (Xn[:, i].mean() - mu) / sd
        print(f'  {k:<12} {mu:8.3f} → {Xn[:, i].mean():8.3f}   z={z:+.2f}')

    do_all = ((Zo[:, None, :] - cent[None, :, :]) ** 2).sum(-1) ** 0.5
    to, mo, do = nearest(Zo, cent, tags)
    tn, mn, dn = nearest(Zn, cent, tags)
    print(f'\nближайший центр восстанавливает старую разметку на '
          f'{100 * (to == yo).mean():.0f}% (in-sample) — таков предел точности '
          f'этого признака, доли ниже читать с ним')
    print('\nтег ближайшего центра (новая нарезка):')
    for i, t in enumerate(tags):
        m = tn == t
        own = do_all[yo == t, i]
        pos = 100 * float((own[None, :] < dn[m][:, None]).mean()) if m.any() else float('nan')
        print(f'  {t:<14} {m.mean() * 100:5.1f}% кадров; дистанция нового кадра до '
              f'центра — {pos:.0f}-й процентиль старых кадров этого тега')
    print(f'  отрыв 1-го центра от 2-го: медиана {np.median(mn):.2f} '
          f'(у старой разметки {np.median(mo):.2f})')

    pair = ((Zo[:, None, :] - Zo[None, :, :]) ** 2).sum(-1) ** 0.5
    np.fill_diagonal(pair, np.inf)
    env = pair.min(1)
    nn = (((Zn[:, None, :] - Zo[None, :, :]) ** 2).sum(-1) ** 0.5).min(1)
    print(f'\nогибающая старого корпуса: медиана расстояния до ближайшего '
          f'старого кадра {np.median(nn):.2f} у нового против {np.median(env):.2f} '
          f'у самого старого; за 95-м процентилем старого — '
          f'{100 * (nn > np.percentile(env, 95)).mean():.1f}% новых кадров')

    print('\nчисло направлений в самой новой нарезке (k-means по z-признакам):')
    for k in range(2, 7):
        lab = KMeans(k, n_init=10, random_state=SEED).fit_predict(Zn)
        print(f'  k={k}  silhouette {silhouette_score(Zn, lab):.3f}')
    lab = KMeans(2, n_init=10, random_state=SEED).fit_predict(Zn)
    print('  k=2 по средним признакам:')
    for i in range(2):
        mu = Xn[lab == i].mean(0)
        print(f'    {i} (n={int((lab == i).sum())}): '
              + ' '.join(f'{k}={v:.2f}' for k, v in zip(KEYS, mu)))
    print('    старое (все): '
          + ' '.join(f'{k}={v:.2f}' for k, v in zip(KEYS, Xo.mean(0))))

    if args.out:
        with open(args.out, 'w', newline='') as f:
            w = csv.writer(f)
            w.writerow(['frame', 'tag', 'margin', 'dist'])
            w.writerows(zip(files, tn, np.round(mn, 3), np.round(dn, 3)))
        print(f'\nзаписано: {args.out}')
    return 0


def selftest() -> int:
    """Признаки детерминированы и не врут на синтетике."""
    import tempfile
    with tempfile.TemporaryDirectory() as d:
        white = os.path.join(d, 'w.png')
        Image.fromarray(np.full((64, 64, 3), 255, np.uint8)).save(white)
        red = os.path.join(d, 'r.png')
        img = np.full((64, 64, 3), 255, np.uint8)
        img[8:56, 20:44] = (200, 20, 20)
        Image.fromarray(img).save(red)
        assert features(white) == [0.0] * len(KEYS), 'пустой кадр должен дать нули'
        a, b = features(red), features(red)
        assert a == b, 'признаки не детерминированы'
        f = dict(zip(KEYS, features(red)))
        assert f['ncol'] == 1 and f['warm'] > 0.9 and f['hue_max'] > 0.9, f
        assert 0.0 < f['sat'] < 1.0 and 0.0 < f['edge'], f
    print('selftest: пустой кадр — нули, красный квадрат — тёплый и одноцветный')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

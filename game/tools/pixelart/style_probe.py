#!/usr/bin/env python3
"""Стоят ли четыре тега стиля (`1_cartoon` / `2_comic_fx` / `3_warm_pastel` /
`4_anime_chibi`) того, чтобы учить их раздельно LoRA.

Мандат. Прежний вердикт «ViT-CLS не делит cartoon/comic_fx/pastel → делить
 нечего» опирался на ARI(k-means, партиция) ≈ 0 и silhouette(k-means) = 0.16.
 Это тест не на тот вопрос: ARI измеряет согласие двух *несмотрящих друг на
 друга* разбиений, а теги заданы человеком, и низкий ARI говорит лишь «k-means
 ищет не там». Ниже — корректные формулировки того же вопроса.

Что считается (секции отчёта):
  1. партиция **как labels**: silhouette/CH/DB против перестановочного нуля
     случайных партиций **той же формы** (классы одинакового размера);
  2. линейная декодируемость тегов (logreg) и kNN + CV-ноль на перемешанных
     метках — «теги вообще что-то кодируют или это шум»;
  3. контроль контента: геометрия силуэта (без цвета и штриха) как отдельный
     пробник, R²(геометрия → ViT), logreg по остаткам, AUC «одна группа против
     остальных» до и после вычитания геометрии;
  4. контроль пакета: лист-источник (63 листа по ~12 кадров) как группа в CV —
     тест на «это не переименованные пакеты генерации»;
  5. контент-сопоставимые пары: косинус ViT у пар с одинаковым силуэтом, ноль —
     перестановка меток **внутри** контентных страт (связь «контент↔метка»
     сохраняется, разрушается только «стиль↔вектор»).

Числа в отчёте = числа `docs/18-lora-style-groups.md`. Что отчёт НЕ доказывает,
сказано в конце отчёта и в доке: линейная декодируемость тега — не «стильность»,
арбитр — ablation LoRA.

Запуск (нужны кадры нарезки, в git пиксели не идут — D-185):
    python3 game/tools/pixelart/style_probe.py --images ~/Downloads/_make_for_lora/units_tight
Кэш векторов и геометрии — `--emb` (по умолчанию `<images>/../style_probe_cache.npz`),
пересчитывается при отсутствии. Время: ~3 мин на MPS, ~1 мин на CPU после кэша.
"""
from __future__ import annotations

import argparse
import csv
import os
import sys
import time

import cv2
import numpy as np
from PIL import Image
from sklearn.cluster import KMeans
from sklearn.decomposition import PCA
from sklearn.linear_model import LogisticRegression, RidgeCV
from sklearn.metrics import (calinski_harabasz_score, davies_bouldin_score,
                             normalized_mutual_info_score, roc_auc_score,
                             silhouette_score)
from sklearn.model_selection import (GroupKFold, KFold, StratifiedGroupKFold,
                                     StratifiedKFold)
from sklearn.neighbors import KNeighborsClassifier
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler

HERE = os.path.dirname(os.path.abspath(__file__))
KEYS = ['ncol', 'sat', 'val', 'valstd', 'chromastd', 'edge', 'dark', 'warm',
        'hue_entropy', 'hue_max']       # признаки, по которым метки были получены
N_PERM = 200          # перестановок для нулевого распределения силуэта
N_NULL = 200          # прогонов для нулевой точности пробников
SEED = 0


# ------------------------------------------------------------------ вход
def read_csv(path):
    with open(path, newline='') as f:
        return list(csv.DictReader(f))


def load_registry(labels_csv, features_csv):
    """Метки — детерминированная функция k-means(6) по 10 цветово-краевым
    признакам (реестр `style_features.csv`), свёрнутая в 4 тега. Пересчёт
    k-means по признакам дал бы те же метки, но в зависимость от версии
    sklearn — держим готовой партицией.

    Ключ — **ячейка** `лист_строка_столбец`, а не имя файла: хэш в имени кадра
    меняется при каждой перенарезке (после правки вырезания отличались 720
    кадров из 733), а ячейка — стабильный идентификатор."""
    rows = read_csv(labels_csv)
    feats = {r['cell']: r for r in read_csv(features_csv)}
    cells = [r['cell'] for r in rows]
    y = np.array([r['group'] for r in rows])
    sheet = np.array([r['sheet'] for r in rows])
    X = np.array([[float(feats[c][k]) for k in KEYS] for c in cells])
    return cells, y, sheet, X


def geometry(path):
    """Признаки **только формы** (298): бинарный силуэт → сетка занятости 16×16,
    профили массы строк/столбцов, аспект, заполнение, выпуклость, верхняя
    «головная» полоса, положения центра массы, лог-площади, относительный
    периметр. Ни цвета, ни насыщенности, ни штриха — контроль «тип/поза»."""
    a = np.asarray(Image.open(path).convert('RGB')).min(2)
    m = (a < 245).astype(np.uint8)          # «не почти-белый» = силуэт
    ys, xs = np.nonzero(m)
    m = m[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    h, w = m.shape
    cnt = cv2.findContours(m, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)[0][0]
    rows, cols = m.mean(1), m.mean(0)
    return np.concatenate([
        cv2.resize(m.astype(np.float32), (16, 16), cv2.INTER_AREA).ravel(),
        np.interp(np.linspace(0, 1, 16), np.arange(h), rows) - 0.5,
        np.interp(np.linspace(0, 1, 16), np.arange(w), cols) - 0.5,
        [w / h, m.mean(),
         cv2.contourArea(cv2.convexHull(cnt)) / max(m.sum(), 1),
         m[:max(1, int(0.12 * h))].mean(1).max() / max(cols.max(), 1e-6),
         float(np.argmax(cols)) / w, float(np.argmax(rows)) / h,
         float((np.cumsum(rows) / rows.sum() > 0.5).argmax()) / h,
         float(np.log(m.sum())), float(np.log(w * h)),
         cv2.arcLength(cnt, True) / np.sqrt(m.sum())]])


def resolve(cells, images):
    """Ячейка → файл нарезки (имя несёт хэш содержимого, потому не ключ)."""
    by_cell = {}
    for f in os.listdir(images):
        if f.endswith('.png'):
            by_cell.setdefault('_'.join(f[:-4].split('_')[:2]), []).append(f)
    bad = {c: by_cell.get(c) for c in cells if not by_cell.get(c) or len(by_cell[c]) > 1}
    if bad:
        raise SystemExit(f'{len(bad)} ячеек не находятся в {images} однозначно '
                         f'(пример: {list(bad.items())[:1]}) — нарезка не та или перепутана папка')
    return [by_cell[c][0] for c in cells]


def embed(files, images, model_id, device):
    """ViT-CLS по кадрам. Только CLS: [CLS] — глобальный «что на картинке»,
    а не карта патчей, то есть про промпт-сопоставимость диффуза эти числа
    ничего не утверждают."""
    import torch
    from transformers import AutoModel, AutoProcessor

    proc = AutoProcessor.from_pretrained(model_id)
    net = AutoModel.from_pretrained(model_id).to(device).eval()
    out, bs = np.zeros((len(files), net.config.hidden_size), np.float32), 64
    for i in range(0, len(files), bs):
        imgs = [Image.open(os.path.join(images, f)).convert('RGB') for f in files[i:i + bs]]
        with torch.no_grad():
            out[i:i + bs] = net(**proc(images=imgs, return_tensors='pt').to(device)).last_hidden_state[:, 0] \
                .float().cpu().numpy()
        print(f'  эмбеддинги {min(i + bs, len(files))}/{len(files)}', end='\r', flush=True)
    print()
    return out


def registry(cells, images, emb_path, model_id, device):
    """Кэш векторов + геометрии. Считается один раз; протухание — по составу ячеек."""
    if os.path.exists(emb_path):
        z = np.load(emb_path, allow_pickle=True)
        if list(z['cells']) == cells:
            return z['E'], z['C']
    files = resolve(cells, images)
    E = embed(files, images, model_id, device)
    C = np.array([geometry(os.path.join(images, f)) for f in files])
    np.savez_compressed(emb_path, E=E, C=C, cells=np.array(cells))
    return E, C


# ------------------------------------------------------------------ пробы
# Предобработка — ВНУТРИ фолда (scaler/PCA подгоняются на трейне), иначе в
# тестовый фолд утекает статистика всего датасета, и «честный» проба перестаёт
# быть честным.
def pipe(kind, balanced=False):
    steps = [StandardScaler()]
    if kind == 'geo':
        steps.append(PCA(50, whiten=True))          # 298 признаков формы → 50
    steps.append(LogisticRegression(max_iter=5000, class_weight='balanced' if balanced else None))
    return make_pipeline(*steps)


def cv_acc(X, y, folds, kind='vit', balanced=False):
    """Точность logreg out-of-fold на готовой разбивке."""
    pred = np.empty(len(y), y.dtype)
    for tr, te in folds:
        p = pipe(kind).fit(X[tr], y[tr])
        pred[te] = p.predict(X[te])
    if not balanced:
        return float((pred == y).mean())
    return float(np.mean([(pred[y == c] == c).mean() for c in np.unique(y)]))


def cv_auc(X, yb, folds, kind='vit'):
    pred = np.zeros(len(yb))
    for tr, te in folds:
        p = pipe(kind, balanced=True).fit(X[tr], yb[tr])
        pred[te] = p.decision_function(X[te])
    return roc_auc_score(yb, pred)


def knn_acc(X, y, folds, k=10):
    pred = np.empty(len(y), y.dtype)
    for tr, te in folds:
        s = StandardScaler().fit(X[tr])
        pred[te] = KNeighborsClassifier(k).fit(s.transform(X[tr]), y[tr]).predict(s.transform(X[te]))
    return float((pred == y).mean())


def ridge_cv(X, Z):
    """CV-предсказание Z по X (форма → ViT): (предсказание, R²). Ridge + PCA —
    внутри фолда. R² обязан считаться на трейне/тесте одними шагами: без
    этого он бывает отрицательным и ничего не значит."""
    pred = np.zeros_like(Z)
    for tr, te in KFold(5, shuffle=True, random_state=SEED).split(X):
        p = make_pipeline(StandardScaler(), PCA(50, whiten=True),
                          RidgeCV(alphas=np.logspace(-1, 4, 12))).fit(X[tr], Z[tr])
        pred[te] = p.predict(X[te])
    return pred, 1 - ((Z - pred) ** 2).sum() / ((Z - Z.mean(0)) ** 2).sum()


# ------------------------------------------------------------------ отчёт
def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--images', required=True, help='папка кадров (units_tight)')
    ap.add_argument('--labels', default=os.path.join(HERE, 'style_labels.csv'))
    ap.add_argument('--features', default=os.path.join(HERE, 'style_features.csv'))
    ap.add_argument('--emb', default=None, help='кэш npz (по умолчанию рядом с --images)')
    ap.add_argument('--model', default='google/vit-large-patch16-384')
    ap.add_argument('--device', default='auto')
    a = ap.parse_args()
    images = os.path.expanduser(a.images)
    emb_path = a.emb or os.path.join(os.path.dirname(images.rstrip('/')), 'style_probe_cache.npz')
    device = a.device
    if device == 'auto':
        device = ('mps' if __import__('torch').backends.mps.is_available()
                  else 'cuda' if __import__('torch').cuda.is_available() else 'cpu')

    cells, y, sheet, X = load_registry(a.labels, a.features)
    names = sorted(set(y))
    y = np.searchsorted(names, y)          # метки — целые: logreg/kNN на строках падают
    t0 = time.time()
    E, C = registry(cells, images, emb_path, a.model, device)
    En = (E - E.mean(0)) / E.std(0)        # для метрик Минковского и logreg
    Ec = E / np.linalg.norm(E, axis=1, keepdims=True)    # для косинуса
    rng = np.random.default_rng(SEED)
    groups = list(range(len(names)))
    sizes = [int((y == g).sum()) for g in groups]
    base = max(sizes) / len(y)
    skf = list(StratifiedKFold(5, shuffle=True, random_state=SEED).split(En, y))
    sgkf = list(StratifiedGroupKFold(5, shuffle=True, random_state=SEED).split(En, y, sheet))
    gkf = list(GroupKFold(5).split(En, y, sheet))     # лист целиком за пределами трейна
    print(f'кадров {len(cells)} · групп {len(names)} · листов {len(set(sheet))} · вектор {E.shape[1]} '
          f'· {device} · {(time.time() - t0) / 60:.1f} мин\n')

    print('== 1. партиция как labels: есть ли в ней структура ==')
    lab6 = KMeans(6, n_init=10, random_state=SEED).fit_predict(StandardScaler().fit_transform(X))
    print(f'  метки = f(реестра признаков): NMI(k-means(6) по {len(KEYS)} цвет.-краев. '
          f'признакам, партиция) = {normalized_mutual_info_score(lab6, y):.3f} — отсюда циркулярность '
          f'проб на самих признаках; пробы на ViT не циркулярны')
    s_mine = silhouette_score(Ec, y, metric='cosine')
    km = KMeans(len(names), n_init=10, random_state=SEED).fit_predict(En)
    print(f'  silhouette (косинус): партиция {s_mine:.3f} · k-means({len(names)}) '
          f'{silhouette_score(Ec, km, metric="cosine"):.3f}')
    print(f'  CH (евклид) {calinski_harabasz_score(En, y):.1f} (k-means {calinski_harabasz_score(En, km):.1f}) · '
          f'DB {davies_bouldin_score(En, y):.2f} (k-means {davies_bouldin_score(En, km):.2f})')
    null_s = []
    for _ in range(N_PERM):
        yp = rng.permutation(np.concatenate([[i] * n for i, n in enumerate(sizes)]))
        null_s.append(silhouette_score(Ec, yp, metric='cosine'))
    null_s = np.array(null_s)
    p = (1 + int((null_s >= s_mine).sum())) / (N_PERM + 1)
    print(f'  ноль (случайные партиции той же формы, {N_PERM}): {null_s.mean():+.3f} ± {null_s.std():.3f} · '
          f'p95 {np.quantile(null_s, 0.95):+.3f} · p ≤ {p:.4f}')
    cent = np.array([Ec[y == g].mean(0) for g in groups])
    cent /= np.linalg.norm(cent, axis=1, keepdims=True)
    for i, g in enumerate(groups):
        m = y == g
        own = float((Ec[m] @ cent[i]).mean())
        near = float((Ec[m] @ np.delete(cent, i, 0).T).max(1).mean())
        print(f'    {names[g]:16s} n={int(m.sum()):4d}  к своему центру {own:+.3f} · '
              f'к ближайшему чужому {near:+.3f} · разрыв {own - near:+.3f}')

    print('\n== 2. декодируемость тегов ==')
    acc = cv_acc(En, y, skf)
    null_acc = np.array([cv_acc(En, rng.permutation(y), skf) for _ in range(N_NULL)])
    print(f'  logreg CV {acc:.3f} · сбаланс. {cv_acc(En, y, skf, balanced=True):.3f} · '
          f'kNN {knn_acc(En, y, skf):.3f} · бейзлайн {base:.3f} · '
          f'ноль {null_acc.mean():.3f} ± {null_acc.std():.3f} · '
          f'p ≤ {(1 + int((null_acc >= acc).sum())) / (N_NULL + 1):.4f}')

    print('\n== 3. контроль контента (геометрия силуэта) ==')
    pred_c, r2 = ridge_cv(C, En)
    R = En - pred_c
    print(f'  признаков формы {C.shape[1]} · R²(геометрия → ViT, CV) {r2:.3f} — столько ViT '
          f'предсказуемо силуэтом')
    print(f'  logreg: геометрия {cv_acc(C, y, skf, "geo"):.3f} · ViT {acc:.3f} · '
          f'остатки ViT−геометрия {cv_acc(R, y, skf):.3f} · бейзлайн {base:.3f}')
    print(f'  {"группа":16s} {"ViT":>7s} {"лист скрыт":>11s} {"геометрия":>10s} {"остатки":>8s}')
    for g in groups:
        yb = (y == g).astype(int)
        print(f'  {names[g]:16s} {cv_auc(En, yb, skf):7.3f} {cv_auc(En, yb, sgkf):11.3f} '
              f'{cv_auc(C, yb, skf, "geo"):10.3f} {cv_auc(R, yb, skf):8.3f}   '
              f'(AUC одна против остальных)')

    print('\n== 4. контроль пакета (лист-источник целиком за пределами трейна) ==')
    print(f'  NMI(группа, лист) {normalized_mutual_info_score(y, sheet):.3f} · '
          f'медиана групп на лист {int(np.median([len(set(y[sheet == s])) for s in set(sheet)]))}')
    for g in groups:
        top = max(int(((sheet == s) & (y == g)).sum()) for s in set(sheet))
        n = sum(1 for s in set(sheet) if (y[sheet == s] == g).any())
        print(f'    {names[g]:16s} лежит на {n} листах из {len(set(sheet))}, '
              f'максимальный лист даёт {top / (y == g).sum():.0%} группы')
    print(f'  logreg, лист скрыт: {cv_acc(En, y, gkf):.3f} · '
          f'сбаланс. {cv_acc(En, y, gkf, balanced=True):.3f} · бейзлайн {base:.3f} · '
          f'геометрия {cv_acc(C, y, gkf, "geo"):.3f}')

    print('\n== 5. контент-сопоставимые пары (при фиксированной форме) ==')
    Cn = C / np.linalg.norm(C, axis=1, keepdims=True)
    D = 1 - Cn @ Cn.T
    np.fill_diagonal(D, np.inf)
    thr = np.quantile(D[np.triu_indices(len(D), 1)], 0.01)
    i, j = np.where(np.triu(D <= thr, 1))
    sim = (Ec[i] * Ec[j]).sum(1)
    same = y[i] == y[j]
    t = sim[same].mean() - sim[~same].mean()
    strata = KMeans(24, n_init=10, random_state=SEED).fit_predict(StandardScaler().fit_transform(C))
    null_t = []
    for _ in range(500):
        yp = y.copy()
        for s in np.unique(strata):
            m = np.where(strata == s)[0]
            yp[m] = rng.permutation(y[m])
        sm = yp[i] == yp[j]
        null_t.append(sim[sm].mean() - sim[~sm].mean())
    null_t = np.array(null_t)
    print(f'  пар {len(i)} (ближайшие 1% по форме): косинус ViT одна группа {sim[same].mean():.4f} · '
          f'разные {sim[~same].mean():.4f} · разница {t:+.4f}')
    print(f'  ноль (метки переставлены внутри 24 контентных страт, 500 раз): '
          f'{null_t.mean():+.4f} ± {null_t.std():.4f} · p ≤ {(1 + int((null_t >= t).sum())) / 501:.4f}')
    print('\nЧто отчёт НЕ доказывает: линейная декодируемость тега из ViT-CLS —'
          '\nне «стильность» и не утверждение про текстовый энкодер диффуза. Арбитр — ablation LoRA.')


if __name__ == '__main__':
    sys.exit(main())

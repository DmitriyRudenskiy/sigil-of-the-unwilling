#!/usr/bin/env python3
"""Отбор по 9 — родным алгоритмом `dataset_prep.py`, плюс антидубль и порядок листов.

Родная часть (grid search `run_pipeline`, строки 786–883 того файла): KMeans с
выбором базового `k` по силуэту, сетка `k_offset −3..+3` × 5 режимов квот,
оценка по LRS/DS/coverage, выбор лучшего набора. Функции `compute_quotas`,
`build_selection_for_mode` и `calculate_quality_scores` **импортированы** из
`dataset_prep`, а не переписаны — переписан только цикл вокруг них, потому что
`run_pipeline` — монолит со своим инференсом и файловым входом.

Сверху — две вещи, которых в родном скрипте нет (он похожие пары только считает
в метриках): запрет дублю внутри девятки и порядок листов по центроидам.
"""
import itertools
import sys

import numpy as np
from scipy.optimize import linear_sum_assignment
from sklearn.cluster import KMeans
from sklearn.metrics import silhouette_score

VISIONEMBED = "/Users/user/PycharmProjects/VisionEmbed-CLI"
if VISIONEMBED not in sys.path:
    sys.path.insert(0, VISIONEMBED)
import dataset_prep as dp  # noqa: E402

K_OFFSETS = [-3, -2, -1, 0, 1, 2, 3]
MODES = ["proportional", "uniform", "sqrt", "log", "inverse"]


def clusters_meta(E, k, seed, min_cluster_size=2, outlier_percentile=95.0):
    labels = KMeans(n_clusters=k, random_state=seed, n_init=10).fit_predict(E)
    sil = float(silhouette_score(E, labels))
    meta = {}
    for cid in range(k):
        members = [i for i, lbl in enumerate(labels) if lbl == cid]
        if len(members) < min_cluster_size:
            continue
        center = E[members].mean(0)
        center /= np.linalg.norm(center)
        dists = 1.0 - (E[members] @ center)
        clean = [m for m, d in zip(members, dists) if d <= np.percentile(dists, outlier_percentile)]
        if len(clean) >= min_cluster_size:
            meta[cid] = {"size": len(clean), "members": clean, "center": center}
    return meta, sil


def select_nine(E, pool, n=9, seed=43, max_clusters=10, min_cluster_size=2, outlier_percentile=95.0):
    """Одна девятка из `pool` (список индексов строк `E`).

    -> (выбор индексов, метаданные стратегии). Порядок внутри девятки — родной
    TSP-обход; он не задаёт порядок клеток 3×3.
    """
    pool = list(pool)
    if len(pool) < 4:
        return pool[:n], {"mode": "pool<4", "target_k": 1, "lrs": 0.0}

    Ep = E[pool]
    vp = [{"global_idx": g, "path": None, "size": 0, "emb": Ep[j]} for j, g in enumerate(pool)]
    dist = np.clip(1.0 - (Ep @ Ep.T), 0.0, 2.0).astype(np.float32)

    max_k = max(2, min(max_clusters, len(pool) // 2))
    base, best_sil, best_k = {}, -1.0, 2
    for k in range(2, max_k + 1):
        meta, sil = clusters_meta(Ep, k, seed, min_cluster_size, outlier_percentile)
        if sil > best_sil:
            base, best_sil, best_k = meta, sil, k
    if not base:
        return pool[:n], {"mode": "no-clusters", "target_k": 0, "lrs": 0.0}

    C, cache, cands, sidx = len(base), {best_k: (base, best_sil)}, [], 0
    for off in K_OFFSETS:
        tk = max(2, min(C + off, max_clusters, len(pool) // 2))
        if tk < 2:
            continue
        if tk not in cache:
            cache[tk] = clusters_meta(Ep, tk, seed, min_cluster_size, outlier_percentile)
        meta, sil = cache[tk]
        if not meta:
            continue
        cur_n = min(n, sum(m["size"] for m in meta.values()))
        if cur_n < 2:
            continue
        for mode in MODES:
            sidx += 1
            r = dp.build_selection_for_mode(meta, cur_n, mode, vp, seed + sidx * 1000,
                                            full_dist_matrix_dedup=dist, ss_score=sil)
            r["target_k"], r["k_offset"], r["mode"], r["strategy_idx"] = tk, off, mode, sidx
            cands.append(r)
    if not cands:
        return pool[:n], {"mode": "no-strategies", "target_k": 0, "lrs": 0.0}

    best = sorted(cands, key=lambda x: (x["lrs"], x["ds"], x["mean_coverage"]), reverse=True)[0]
    return [pool[j] for j in best["ordered_indices"]], best


def fix_nine(nine, S, same_object, unused, thr):
    """Антидубль: пары выше `thr` и пары «тот же объект» не делят девятку.

    Худший (второй) член пары меняется на самого далёкого неиспользованного
    кандидата, который сам ничего не нарушает. Менять нечего -> предупреждение.
    """
    nine, warns = list(nine), []
    for _ in range(len(unused) + 1):
        bad = next(((a, b) for a, b in itertools.combinations(range(len(nine)), 2)
                    if same_object[nine[a]] == same_object[nine[b]] or S[nine[a], nine[b]] > thr), None)
        if bad is None:
            return nine, warns
        a, b = bad
        keys = {same_object[x] for x in nine}
        taken = set(nine)

        def ok(c):
            if same_object[c] in keys:
                return False
            return all(S[c, x] <= thr for x in nine if x != nine[b])

        cand = [c for c in unused if c not in taken and ok(c)]
        if not cand:
            warns.append(f"некем заменить {nine[b]} (пара с {nine[a]}), оставлено как есть")
            return nine, warns
        far = max(cand, key=lambda c: (min(S[c, x] for x in nine if x != nine[b]), -c))
        nine[b] = far
    return nine, warns


def topup(nine, S, same_object, unused, n, thr):
    """Добор до `n` штук самым далёким неиспользованным кандидатом — то же
    правило, что у замены в `fix_nine`. Родные квоты могут дать меньше 9, когда
    размер кластера меньше квоты. -> (девять, добрать нечем)"""
    nine = list(nine)
    while len(nine) < n:
        taken, keys = set(nine), {same_object[x] for x in nine}
        cand = [c for c in unused if c not in taken and same_object[c] not in keys
                and all(S[c, x] <= thr for x in nine)]
        if not cand:
            cand = [c for c in unused if c not in taken]
        if not cand:
            return nine, True
        nine.append(max(cand, key=lambda c: (min(S[c, x] for x in nine), -c)))
    return nine, False


def pair_books(files, emb_by_file):
    """11 пар «одна книга в двух съёмках» венгерским назначением по среднему
    построчному максимуму сходства. -> dict файл -> id книги."""
    files = sorted(files)
    if len(files) < 2:
        return {f: 0 for f in files}  # нечего спаривать (отладочный прогон с --limit 1)
    M = np.zeros((len(files), len(files)), dtype=np.float64)
    for i, a in enumerate(files):
        for j, b in enumerate(files):
            if i != j:
                M[i, j] = (emb_by_file[a] @ emb_by_file[b].T).max(axis=1).mean()
    r, c = linear_sum_assignment(-M)
    books, bid = {}, 0
    for i, j in zip(r, c):
        if i < j:
            books[files[i]] = books[files[j]] = bid
            bid += 1
    if len(books) != len(files):
        raise SystemExit(f"не все файлы спарились в книги: {len(books)}/{len(files)}")
    return books


def centroids(nines, E):
    C = np.vstack([E[n].mean(axis=0) for n in nines])
    return C / np.linalg.norm(C, axis=1, keepdims=True)


def order_sheets(C):
    """Первая и последняя позиция — самая далёкая пара центроидов, середина —
    по убыванию расстояния к краям. Детерминировано: при равенстве — меньший номер.

    -> (перестановка девятонок, расстояние первый<->последний)
    """
    n = len(C)
    if n < 3:
        return list(range(n)), float(1 - C[0] @ C[-1]) if n > 1 else 0.0
    D = 1.0 - (C @ C.T)
    i, j = (int(x) for x in np.unravel_index(int(np.argmax(D)), D.shape))
    pos = [None] * n
    pos[0], pos[-1] = i, j
    free = sorted(set(range(n)) - {i, j})
    slots = [k for pair in zip(range(1, n - 1), range(n - 2, 0, -1)) for k in pair]
    for p in slots:
        if pos[p] is not None or not free:
            continue
        neigh = [q for q in (p - 1, p + 1) if 0 <= q < n and pos[q] is not None]
        best = max(free, key=lambda s: (min(D[s, pos[q]] for q in neigh) if neigh else 0.0))
        pos[p] = best
        free.remove(best)
    return pos, float(D[i, j])


if __name__ == "__main__":
    rng = np.random.default_rng(0)
    # восемь плотных кластеров по 6 точек вокруг ортогональных центров
    E = np.vstack([rng.normal(loc=c, scale=.05, size=(6, 8)) for c in np.eye(8)]).astype("float32")
    E /= np.linalg.norm(E, axis=1, keepdims=True)
    S = E @ E.T

    nine, meta = select_nine(E, list(range(len(E))), n=9, seed=43, max_clusters=9)
    assert len(nine) == 9 and len(set(nine)) == 9, nine
    assert meta["mode"] in MODES and meta["target_k"] >= 2, meta
    same = list(range(len(E)))
    fixed, warns = fix_nine(nine, S, same, [i for i in range(len(E)) if i not in nine], thr=1.01)
    assert fixed == nine and not warns, (fixed, warns)

    # близнецы 48/49: 48 — «тот же объект», что 0; 49 — далёкий кандидат на замену
    far = np.ones((1, 8), dtype="float32") / np.sqrt(8)  # косинус ~0.35 к любому из 8 центров
    E2 = np.vstack([E, E[0:1], far])
    E2 /= np.linalg.norm(E2, axis=1, keepdims=True)
    S2 = E2 @ E2.T
    same2 = list(range(len(E))) + [0, 99]
    nine9 = [0, 48] + [6 * i for i in range(1, 8)]
    got, w2 = fix_nine(nine9, S2, same2, [49], thr=0.9)
    assert 48 not in got and 49 in got and len(got) == 9 and not w2, (got, w2)
    got, w2 = fix_nine(nine9, S2, same2, [], thr=0.9)
    assert w2 and 48 in got, (got, w2)

    C = centroids([list(range(9)), list(range(9, 18)), list(range(18, 24))], E2)
    order, d = order_sheets(C)
    assert sorted(order) == [0, 1, 2] and d > 0
    print("ok")

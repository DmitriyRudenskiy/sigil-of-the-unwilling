#!/usr/bin/env python3
"""Сверка готового прогона: 264 = 29×9 + 3, каждый кроп ровно один раз,
внутри листа нет запрещённых пар, крайние листы — максимум по центроидам.

    python3 tools/spellbook_sheets/check.py --out reference/spellbook
"""
import argparse
import itertools
import json
import sys
from pathlib import Path

import numpy as np

ap = argparse.ArgumentParser()
ap.add_argument("--out", required=True)
ap.add_argument("--max-intra-sim", type=float, default=0.80)
ap.add_argument("--crops-dir", help="где лежат кропы (по умолчанию <out>/crops)")
a = ap.parse_args()

out, rep = Path(a.out), json.loads((Path(a.out) / "sheets.json").read_text())
CD = Path(a.crops_dir) if a.crops_dir else out / "crops"
E = np.load(Path(a.out) / "embeddings.npz", allow_pickle=True)["E"]
names = [str(n) for n in np.load(Path(a.out) / "embeddings.npz", allow_pickle=True)["names"]]
row = {n: i for i, n in enumerate(names)}
det = json.loads((Path(a.out) / "detections.json").read_text())
books = rep["books"]

cells = [c for s in rep["sheets"] for c in s["cells"]]
fail = []


def want(cond, msg):
    if not cond:
        fail.append(msg)


# 1. состав пула и использование
total = sum(len(d["crops"]) for d in det)
want(total == len(names), f"кропов в detections {total} != векторов {len(names)}")
want(total == len(cells) + len(rep["residual"]),
     f"{total} != {len(cells)} использовано + {len(rep['residual'])} остатка")
want(len(set(cells)) == len(cells), "кроп использован больше одного раза")
want(not (set(cells) & set(rep["residual"])), "остаток пересекается с листами")
want(len(cells) % 9 == 0, f"{len(cells)} использованных не делится на 9")
for n in cells + rep["residual"]:
    want((CD / n).is_file(), f"нет файла {n}")
for s in rep["sheets"]:
    want((Path(a.out) / "sheets" / f"sheet_{s['sheet']:02d}.png").is_file(), f"нет листа {s['sheet']}")

# 2. запрет внутри листа: порог и «та же книга + та же ячейка»
stem = {f.rsplit(".", 1)[0]: b for f, b in books.items()}
key = {n: (stem[n.rsplit("_", 1)[0]], n[-6:-4]) for n in names}
for s in rep["sheets"]:
    v = [row[c] for c in s["cells"]]
    want(len(v) == 9, f"лист {s['sheet']}: клеток {len(v)}")
    sims = [float(E[i] @ E[j]) for i, j in itertools.combinations(v, 2)]
    want(max(sims) <= a.max_intra_sim + 1e-6,
         f"лист {s['sheet']}: сходство {max(sims):.3f} > {a.max_intra_sim}")
    ks = [key[c] for c in s["cells"]]
    want(len(set(ks)) == len(ks), f"лист {s['sheet']}: повтор книги+ячейки {ks}")
    want(abs(max(sims) - s["max_intra_sim"]) < 1e-3, f"лист {s['sheet']}: метрика отчёта врёт")

# 3. крайние листы — максимум по парам центроидов
C = np.vstack([E[[row[c] for c in s["cells"]]].mean(0) for s in rep["sheets"]])
C /= np.linalg.norm(C, axis=1, keepdims=True)
D = 1.0 - (C @ C.T)
want(abs(D[0, -1] - D.max()) < 1e-6,
     f"крайние листы {D[0, -1]:.4f} != максимум пар {D.max():.4f}")
want(abs(D[0, -1] - rep["first_last_centroid_distance"]) < 1e-3, "метрика первого<->последнего врёт")

print(f"проверено: {total} кропов · {len(rep['sheets'])} листов · остаток {len(rep['residual'])} · "
      f"макс intra {max(s['max_intra_sim'] for s in rep['sheets']):.3f} · "
      f"первый<->последний {D[0, -1]:.3f}")
if fail:
    print(f"\nПРОБЛЕМЫ ({len(fail)}):")
    print("\n".join(f"- {x}" for x in fail))
    sys.exit(1)
print("OK")

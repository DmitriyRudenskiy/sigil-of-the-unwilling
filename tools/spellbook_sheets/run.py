#!/usr/bin/env python3
"""Кромы -> CLIP -> отбор по 9 -> листы 3×3.

    python3 tools/spellbook_sheets/run.py --input <сырьё> --out reference/spellbook --yes

Без `--yes` инструмент останавливается на прототипе: детекция + кроп + QC-кадры
первого листа, чтобы человек сверил рамки до полного прогона.
"""
import argparse
import datetime as dt
import hashlib
import json
import platform
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import detect as D  # noqa: E402
import embed as V  # noqa: E402
import pick as S  # noqa: E402

Image.MAX_IMAGE_PIXELS = None


def sources(input_dir):
    out = []
    for p in sorted(Path(input_dir).iterdir()):
        if p.suffix.lower() in (".png", ".jpg", ".jpeg", ".webp"):
            out.append(p)
    return out


def crop_all(srcs, out, args, predictor=None, qc_only=False):
    """Детекция + кроп. -> (список записей по листам, список путей кропов)."""
    crops_dir, qc_dir = out / "crops", out / "qc"
    crops_dir.mkdir(parents=True, exist_ok=True)
    qc_dir.mkdir(parents=True, exist_ok=True)
    rows, paths = [], []
    for i, src in enumerate(srcs):
        im = Image.open(src).convert("RGB")
        if predictor is None:
            boxes, mode, n_masks = D._grid_boxes(*im.size), "fallback-grid", 0
        else:
            boxes, mode, n_masks = D.detect(predictor, im, args.prompt, args.min_frac)
        rec = {"source": src.name, "width": im.size[0], "height": im.size[1],
               "mode": mode, "masks": n_masks, "clamped": [], "crops": []}
        for cell, box in enumerate(boxes):
            sq = D.square(box, *im.size, pad=args.pad)
            crop = im.crop(sq[:4]).resize((args.cell, args.cell), Image.LANCZOS)
            name = f"{src.stem}_{cell + 1:02d}.png"
            crop.save(crops_dir / name)
            rec["crops"].append(name)
            rec["clamped"].append(cell + 1) if sq[4] else None
            paths.append(crops_dir / name)
        D.overlay(im, boxes).save(qc_dir / f"{src.stem}_overlay.jpg", quality=82)
        D.contact_sheet(im, boxes).save(qc_dir / f"{src.stem}_crops.png")
        print(f"  [{i + 1}/{len(srcs)}] {src.name}: {mode}, масок {n_masks}", flush=True)
        rows.append(rec)
        if qc_only:
            print(f"\nПРОТОТИП: {qc_dir / (src.stem + '_overlay.jpg')}\n"
                  f"          {qc_dir / (src.stem + '_crops.png')}\n"
                  f"Сверь рамки и кадри. Продолжить — тот же вызов с --yes.", file=sys.stderr)
            break
    return rows, paths


def assemble(nine_paths, out_png, cell):
    sheet = Image.new("RGB", (3 * cell, 3 * cell), "white")
    for k, p in enumerate(nine_paths):
        sheet.paste(Image.open(p).convert("RGB").resize((cell, cell), Image.LANCZOS),
                    ((k % 3) * cell, (k // 3) * cell))
    sheet.save(out_png)


def contact(sheet_path, out_png, width=760):
    im = Image.open(sheet_path)
    im.resize((width, width), Image.LANCZOS).save(out_png)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--cell", type=int, default=320)
    ap.add_argument("--pad", type=float, default=D.PAD)
    ap.add_argument("--min-frac", type=float, default=D.MIN_FRAC)
    ap.add_argument("--prompt", default=D.PROMPT)
    ap.add_argument("--max-intra-sim", type=float, default=0.80)
    ap.add_argument("--seed", type=int, default=43)
    ap.add_argument("--max-clusters", type=int, default=10)
    ap.add_argument("--sam-device", default="mps")
    ap.add_argument("--embed-device", default="cpu")
    ap.add_argument("--limit", type=int, default=0, help="только N первых листов (отладка)")
    ap.add_argument("--yes", action="store_true", help="прототип уже сверен, идти до конца")
    args = ap.parse_args()

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    srcs = sources(args.input)
    if args.limit:
        srcs = srcs[:args.limit]
    print(f"Аудит: {len(srcs)} файлов в {args.input}")

    predictor = D.client(args.sam_device)
    rows, crop_paths = crop_all(srcs, out, args, predictor, qc_only=not args.yes)
    if not args.yes:
        return 2
    if len(crop_paths) < 9:
        raise SystemExit(f"кропов меньше 9 ({len(crop_paths)}) — листов не собрать")

    print("Векторизация:")
    E = V.load_or_embed(out, crop_paths, device=args.embed_device)
    Sim = E @ E.T

    by_name = {p.name: i for i, p in enumerate(crop_paths)}
    emb_by_file = {rec["source"]: E[[by_name[n] for n in rec["crops"]]] for rec in rows}
    books = S.pair_books([r["source"] for r in rows], emb_by_file)
    # «тот же объект» = та же книга (одна из пары съёмок) + та же ячейка 4×3
    same_obj = [(_book_of(p.name, rows, books), p.name[-6:-4]) for p in crop_paths]

    print("Отбор:")
    pool = list(range(len(crop_paths)))
    nines, meta_rows, warns, reps = [], [], [], []
    while len(pool) >= 9:
        nine, meta = S.select_nine(E, pool, 9, args.seed, args.max_clusters)
        free = [i for i in pool if i not in set(nine)]
        nine, short = S.topup(nine, Sim, same_obj, free, 9, args.max_intra_sim)
        pre = set(nine)
        nine, w = S.fix_nine(nine, Sim, same_obj, [i for i in pool if i not in set(nine)], args.max_intra_sim)
        if short:
            w.append("добрать до 9 нечем")
        pool = [i for i in pool if i not in set(nine)]
        for out_, in_ in zip(sorted(pre - set(nine)), sorted(set(nine) - pre)):
            reps.append(f"лист {len(nines)}: `{crop_paths[out_].name}` → `{crop_paths[in_].name}`")
        nines.append(nine)
        intra = max(Sim[i, j] for a, i in enumerate(nine) for j in nine[a + 1:])
        meta_rows.append({"sheet": len(nines) - 1, "mode": meta["mode"], "target_k": meta["target_k"],
                          "lrs": round(float(meta.get("lrs", 0.0)), 4), "cells": len(nine),
                          "max_intra_sim": round(float(intra), 4), "left": len(pool)})
        warns += [f"лист {len(nines) - 1}: {x}" for x in w]
        print(f"  лист {len(nines) - 1:2d}: {meta['mode']:<13} k={meta['target_k']:<2} "
              f"LRS={meta.get('lrs', 0):.4f} max_intra={intra:.3f} осталось {len(pool)}", flush=True)

    C = S.centroids(nines, E)
    order, d_first_last = S.order_sheets(C)
    nines = [nines[i] for i in order]

    sheets_dir = out / "sheets"
    sheets_dir.mkdir(exist_ok=True)
    md5 = {}
    for old in sheets_dir.glob("*.png"):
        old.unlink()
    for s, nine in enumerate(nines):
        p = sheets_dir / f"sheet_{s:02d}.png"
        assemble([crop_paths[i] for i in nine], p, args.cell)
        contact(p, out / "qc" / p.name)
        md5[s] = hashlib.md5(p.read_bytes()).hexdigest()

    residual = [crop_paths[i].name for i in pool]
    (out / "residual").mkdir(exist_ok=True)
    for old in (out / "residual").glob("*.png"):
        old.unlink()
    for i in pool:
        (out / "residual" / crop_paths[i].name).write_bytes(crop_paths[i].read_bytes())

    report = {
        "generated": dt.date.today().isoformat(),
        "python": platform.python_version(),
        "numpy": np.__version__,
        "sam_device": args.sam_device,
        "embed_device": args.embed_device,
        "params": {k: v for k, v in vars(args).items() if k not in ("input", "out")},
        "sources": rows,
        "books": {f: int(b) for f, b in sorted(books.items(), key=lambda kv: kv[1])},
        "sheets": [{"sheet": s, "order_index": order[s], "cells": [crop_paths[i].name for i in nine],
                    "md5": md5[s],
                    "max_intra_sim": meta_rows[order[s]]["max_intra_sim"]}
                   for s, nine in enumerate(nines)],
        "selection": meta_rows,
        "first_last_centroid_distance": round(d_first_last, 4),
        "replacements": reps,
        "warnings": warns,
        "residual": residual,
    }
    (out / "detections.json").write_text(json.dumps(rows, ensure_ascii=False, indent=1))
    (out / "sheets.json").write_text(json.dumps(report, ensure_ascii=False, indent=1))
    (out / "report.md").write_text(render_report(report, args))
    print(f"\nкропов {len(crop_paths)} · листов {len(nines)} · остаток {len(residual)} · "
          f"первый<->последний {d_first_last:.3f}")
    print(f"отчёт: {out / 'report.md'}")
    return 0


def _book_of(crop_name, rows, books):
    stem = crop_name.rsplit("_", 1)[0]
    for rec in rows:
        if rec["source"].rsplit(".", 1)[0] == stem:
            return books[rec["source"]]
    raise KeyError(crop_name)


def render_report(r, args):
    modes = {}
    for rec in r["sources"]:
        modes[rec["mode"]] = modes.get(rec["mode"], 0) + 1
    L = [f"# Листы иконок из `{args.input}`", "",
         f"Сгенерировано {r['generated']}. Python {r['python']}, numpy {r['numpy']}, "
         f"SAM на `{r['sam_device']}`, CLIP на `{r['embed_device']}`.", "",
         "## Аудит входного пула", "",
         "| лист | разрешение | режим | масок | кропов | кламп |", "| --- | --- | --- | --- | --- | --- |"]
    for rec in r["sources"]:
        L.append(f"| `{rec['source'][:28]}…` | {rec['width']}×{rec['height']} | {rec['mode']} | "
                 f"{rec['masks']} | {len(rec['crops'])} | "
                 f"{', '.join(map(str, rec['clamped'])) or '—'} |")
    L += ["", f"Режимы детекции: {json.dumps(modes, ensure_ascii=False)}. "
          f"Книг (пар съёмок): {len(set(r['books'].values()))}.", "",
          "## Листы", "",
          "| лист | режим отбора | k | LRS | max intra-sim | md5 листа |",
          "| --- | --- | --- | --- | --- | --- |"]
    sel = {m["sheet"]: m for m in r["selection"]}
    for sh in r["sheets"]:
        m = sel[sh["order_index"]]
        L.append(f"| {sh['sheet']} | {m['mode']} | {m['target_k']} | {m['lrs']} | "
                 f"{m['max_intra_sim']} | `{sh['md5'][:12]}` |")
    L += ["", f"Расстояние центроидов первого и последнего листа: "
          f"**{r['first_last_centroid_distance']}** (1 = противоположности, 0 = совпадение).", ""]
    L += ["## Замены антидубля", "",
          "—" if not r["replacements"] else "\n".join(f"- {x}" for x in r["replacements"]), ""]
    if r["warnings"]:
        L += ["## Предупреждения", ""] + [f"- {w}" for w in r["warnings"]] + [""]
    L += [f"## Остаток ({len(r['residual'])})", ""] + [f"- `{n}`" for n in r["residual"]] + [""]
    L += ["## Контрольные числа", "",
          f"- кропов: {sum(len(rec['crops']) for rec in r['sources'])}",
          f"- листов 3×3: {len(r['sheets'])}",
          f"- остаток: {len(r['residual'])}", ""]
    return "\n".join(L)


if __name__ == "__main__":
    sys.exit(main())

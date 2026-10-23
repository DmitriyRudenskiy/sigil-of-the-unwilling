#!/usr/bin/env python3
"""Кромы -> CLIP -> отбор по 9 -> листы 3×3.

    python3 tools/spellbook_sheets/run.py --input <сырьё> --out reference/spellbook --yes

Без `--yes` инструмент останавливается на прототипе: детекция + кроп + QC-кадры
первого листа, чтобы человек сверил рамки до полного прогона.

`--crops` — вход уже представляет собой каталог готовых кропов `…_<01..12>.png`
(например, после ручной сортировки): SAM и детекция пропускаются, отбор и
сборка листов — те же. `--no-books` — каждый файл отдельный сюжет (одиночные
иконки, не снимки разворотов): спаривание съёмок и запрет «та же книга + та же
ячейка» пропускаются, остаётся только векторный порог.
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


def masses(paths):
    """Доля занятых пикселей в кадре — «размер» объекта на глаз."""
    out = []
    for p in paths:
        a = np.asarray(Image.open(p).convert("L").resize((96, 96), Image.LANCZOS))
        out.append(float((255 - a > 40).mean()))
    return np.array(out)


def size_bands(pool, mass, edges=(0.0, 0.30, 0.45, 0.60, 1.01)):
    """Полосы по «массе»: лист собирается внутри одной, иначе в одном листу
    рядом оказываются плоский сарай и трёхэтажный замок.

    -> (полосы с >=9 кропов, остатки) — остатки нечего листать, они в остаток.
    """
    out = [[] for _ in range(len(edges) - 1)]
    for i in pool:
        for b in range(len(edges) - 1):
            if edges[b] <= mass[i] < edges[b + 1]:
                out[b].append(i)
                break
    bands, rest = [], []
    for b in out:
        bands.append(b) if len(b) >= 9 else rest.extend(b)
    return bands, rest


def sources(input_dir):
    out = []
    for p in sorted(Path(input_dir).iterdir()):
        if p.suffix.lower() in (".png", ".jpg", ".jpeg", ".webp"):
            out.append(p)
    return out


def rows_from_crops(paths):
    """Записи «листа» по уже готовым кропам: группа = исходный файл из имени."""
    by = {}
    for p in paths:
        by.setdefault(p.stem.rsplit("_", 1)[0], []).append(p)
    rows = []
    for stem, ps in sorted(by.items()):
        w, h = Image.open(ps[0]).size
        rows.append({"source": f"{stem}.png", "width": w, "height": h, "mode": "crops",
                     "masks": len(ps), "clamped": [], "crops": sorted(q.name for q in ps)})
    return rows


def rows_from_files(paths):
    """Каждый файл — отдельный сюжет (одиночные иконки)."""
    rows = []
    for p in paths:
        w, h = Image.open(p).size
        rows.append({"source": p.name, "width": w, "height": h, "mode": "file",
                     "masks": 1, "clamped": [], "crops": [p.name]})
    return rows


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
    ap.add_argument("--input", default="")
    ap.add_argument("--out", default="")
    ap.add_argument("--crops", action="store_true",
                    help="--input — каталог готовых кропов, детекцию пропустить")
    ap.add_argument("--no-books", action="store_true",
                    help="каждый файл — отдельный сюжет, спаривание съёмок пропустить")
    ap.add_argument("--cell", type=int, default=320)
    ap.add_argument("--pad", type=float, default=D.PAD)
    ap.add_argument("--min-frac", type=float, default=D.MIN_FRAC)
    ap.add_argument("--prompt", default=D.PROMPT)
    ap.add_argument("--max-intra-sim", type=float, default=0.80)
    ap.add_argument("--unique-subjects", action="store_true",
                    help="сюжет не более одного раза во всех листах: второй экземпляр "
                         "той же книги+ячейки идёт в остаток")
    ap.add_argument("--global-max-sim", type=float, default=0.95,
                    help="сюжет не более одного раза во ВСЁМ пуле: копия ближе к уже "
                         "взятой, чем порог, идёт в остаток (0 = выключено)")
    ap.add_argument("--min-mass", type=float, default=0.12,                    help="занятая доля кадра ниже порога — это не здание, а плитка/обрезок, в остаток")
    ap.add_argument("--max-mass", type=float, default=0.85,
                    help="выше порога — квадрат сцены вместо силуэта здания, в остаток")
    ap.add_argument("--no-size-bands", action="store_true",
                    help="не группировать лист по размеру объекта")
    ap.add_argument("--seed", type=int, default=43)
    ap.add_argument("--max-clusters", type=int, default=10)
    ap.add_argument("--sam-device", default="mps")
    ap.add_argument("--embed-device", default="cpu")
    ap.add_argument("--limit", type=int, default=0, help="только N первых листов (отладка)")
    ap.add_argument("--yes", action="store_true", help="прототип уже сверен, идти до конца")
    ap.add_argument("--selftest", action="store_true", help="проверить size_bands и выйти")
    args = ap.parse_args()
    if args.selftest:
        m = np.array([0.4] * 9 + [0.8] * 8)
        bands, rest = size_bands(list(range(17)), m)
        assert [len(b) for b in bands] == [9] and sorted(rest) == list(range(9, 17)), (bands, rest)
        assert size_bands(list(range(9)), np.array([0.4] * 9))[0][0] == list(range(9))
        print("ok")
        return

    if not args.input or not args.out:
        raise SystemExit("--input и --out обязательны (--selftest — без них)")
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    srcs = sources(args.input)
    if args.limit:
        srcs = srcs[:args.limit]
    print(f"Аудит: {len(srcs)} файлов в {args.input}")

    if args.no_books:
        rows = rows_from_files(srcs)
        print(f"Отдельные сюжеты: {len(srcs)} файлов — детекция и спаривание пропущены")
        crop_paths = srcs
    elif args.crops:
        rows = rows_from_crops(srcs)
        print(f"Кроповый вход: {len(srcs)} файлов, книг {len(rows)} — SAM пропущен")
        crop_paths = srcs
    else:
        predictor = D.client(args.sam_device)
        rows, crop_paths = crop_all(srcs, out, args, predictor, qc_only=not args.yes)
        if not args.yes:
            return 2
    if len(crop_paths) < 9:
        raise SystemExit(f"кропов меньше 9 ({len(crop_paths)}) — листов не собрать")

    if args.crops or args.no_books:
        gone = [p for p in crop_paths if not p.is_file()]
        if gone:
            raise SystemExit(f"кропов не стало ({len(gone)}) — в каталоге шла сортировка "
                             f"во время прогона; перезапусти: {gone[0].name} …")

    print("Векторизация:")
    E = V.load_or_embed(out, crop_paths, device=args.embed_device)
    Sim = E @ E.T

    by_name = {p.name: i for i, p in enumerate(crop_paths)}
    if args.no_books:
        # сюжет = файл: спаривать нечего, запрещать «ту же ячейку» негде
        books = {p.name: i for i, p in enumerate(crop_paths)}
        same_obj = list(range(len(crop_paths)))
    else:
        emb_by_file = {rec["source"]: E[[by_name[n] for n in rec["crops"]]] for rec in rows}
        books = S.pair_books([r["source"] for r in rows], emb_by_file)
        # «тот же объект» = та же книга (одна из пары съёмок) + та же ячейка 4×3
        same_obj = [(_book_of(p.name, rows, books), p.name[-6:-4]) for p in crop_paths]

    print("Отбор:")
    pool = list(range(len(crop_paths)))
    twins = []
    if args.unique_subjects:
        # «тот же сюжет» = та же книга и та же ячейка 4×3 в двух съёмках разворота
        seen = set()
        keep = []
        for i, k in enumerate(same_obj):
            if k in seen:
                twins.append(i)
            else:
                seen.add(k)
                keep.append(i)
        pool = keep
        print(f"  сюжетов-близнецов отложено: {len(twins)}")
    if args.global_max_sim > 0:
        # векторный порог антидубля действует внутри листа; почти идентичные кадры,
        # разъехавшиеся по разным листам, он не видит вовсе
        already, keep = set(twins), []
        for i in range(len(crop_paths)):
            if i in already:
                continue
            if any(Sim[i, k] > args.global_max_sim for k in keep):
                twins.append(i)
            else:
                keep.append(i)
        pool = keep
        print(f"  отложено по глобальному порогу {args.global_max_sim}: {len(twins) - len(already)}")
    nines, meta_rows, warns, reps = [], [], [], []
    Mass = masses(crop_paths)
    thin = [i for i in pool if not args.min_mass <= Mass[i] <= args.max_mass]
    if thin:
        twins += thin
        pool = [i for i in pool if args.min_mass <= Mass[i] <= args.max_mass]
        print(f"  пустых/залитых кадров (масса вне [{args.min_mass}, {args.max_mass}]) "
              f"отложено: {len(thin)}")
    bands = [pool]
    if not args.no_size_bands:
        bands, rest = size_bands(pool, Mass)
        twins += rest
        print(f"  полос по размеру: {[len(b) for b in bands]} · не в полосу: {len(rest)}")
    left = []
    for band in bands:
        pool = band
        while len(pool) >= 9:
          nine, meta = S.select_nine(E, pool, 9, args.seed, args.max_clusters)
          free = [i for i in pool if i not in set(nine)]
          nine, short = S.topup(nine, Sim, same_obj, free, 9, args.max_intra_sim)
          pre = set(nine)
          nine, w = S.fix_nine(nine, Sim, same_obj, [i for i in pool if i not in set(nine)], args.max_intra_sim)
          pool = [i for i in pool if i not in set(nine)]
          if not nine:
              break  # защита от зацикливания: девятка пуста, pool не уменьшается
          if short:
              # до 9 не добрать в пределах порога — лист не печатаем, кропы в остаток
              twins += nine
              warns.append(f"лист {len(nines)}: до 9 не добрать ({len(nine)}) — в остаток")
              continue
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
        left += pool
    pool = left

    C = S.centroids(nines, E)
    order, d_first_last = S.order_sheets(C)
    nines = [nines[i] for i in order]

    sheets_dir = out / "sheets"
    sheets_dir.mkdir(exist_ok=True)
    (out / "qc").mkdir(exist_ok=True)
    md5 = {}
    for old in sheets_dir.glob("*.png"):
        old.unlink()
    for old in (out / "qc").glob("sheet_*.png"):
        old.unlink()  # иначе превью от прошлого прогона выдают 54 листа за 53
    for s, nine in enumerate(nines):
        p = sheets_dir / f"sheet_{s:02d}.png"
        assemble([crop_paths[i] for i in nine], p, args.cell)
        contact(p, out / "qc" / p.name)
        md5[s] = hashlib.md5(p.read_bytes()).hexdigest()

    # обзор: все листы одной картинкой — смотреть негодующие листы глазами
    from PIL import ImageDraw
    gcols = int(np.ceil(np.sqrt(len(nines))))
    grows = int(np.ceil(len(nines) / gcols))
    gw = 200
    ov = Image.new("RGB", (gcols * gw, grows * gw), "black")
    dr = ImageDraw.Draw(ov)
    for s, nine in enumerate(nines):
        t = Image.open(sheets_dir / f"sheet_{s:02d}.png").resize((gw, gw), Image.LANCZOS)
        x, y = (s % gcols) * gw, (s // gcols) * gw
        ov.paste(t, (x, y))
        dr.rectangle([x, y, x + gw - 1, y + gw - 1], outline=(80, 80, 80))
        dr.text((x + 4, y + 3), str(s), fill="yellow")
    ov.save(out / "qc" / "overview.png")

    residual = [crop_paths[i].name for i in pool + twins]
    (out / "residual").mkdir(exist_ok=True)
    for old in (out / "residual").glob("*.png"):
        old.unlink()
    for i in pool + twins:
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
        "duplicate_subjects": [crop_paths[i].name for i in twins],
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
    pool_kind = "отдельных сюжетов" if args.no_books else ("готовых кропов" if args.crops else "сырья")
    L = [f"# Листы иконок из `{args.input}` ({pool_kind})", "",
         f"Сгенерировано {r['generated']}. Python {r['python']}, numpy {r['numpy']}, "
         + ("SAM пропущен (вход — готовые изображения), " if args.crops or args.no_books
            else f"SAM на `{r['sam_device']}`, ")
         + f"CLIP на `{r['embed_device']}`.", "",
         "## Аудит входного пула" + (" — по готовым файлам, детекция пропущена"
                                     if args.crops or args.no_books else ""), ""]
    if args.no_books:
        w = [rec["width"] for rec in r["sources"]]
        L += [f"Файлов: {len(r['sources'])}, каждый — отдельный сюжет. "
              f"Разрешение {min(w)}…{max(w)} px, квадратные. "
              f"Спаривание съёмок пропущено, антидубль работает только векторным порогом.", ""]
    else:
        L += ["| лист | разрешение | режим | масок | кропов | кламп |",
              "| --- | --- | --- | --- | --- | --- |"]
        for rec in r["sources"]:
            L.append(f"| `{rec['source'][:28]}…` | {rec['width']}×{rec['height']} | {rec['mode']} | "
                     f"{rec['masks']} | {len(rec['crops'])} | "
                     f"{', '.join(map(str, rec['clamped'])) or '—'} |")
    L += ["", f"Режимы детекции: {json.dumps(modes, ensure_ascii=False)}. "
          f"{'Сюжетов' if args.no_books else 'Книг (пар съёмок)'}: {len(set(r['books'].values()))}.", "",
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
    if r.get("duplicate_subjects"):
        L += [f"## Отложено как повтор ({len(r['duplicate_subjects'])})", "",
              "Второй экземпляр того же сюжета (та же книга и та же ячейка в двух съёмках)",
              "или копия, стоящая ближе `--global-max-sim` к уже взятому сюжету. Векторный",
              "порог антидубля их не останавливает: он действует внутри листа, а эти",
              "копии разъезжаются по разным.", ""] + [f"- `{n}`" for n in r["duplicate_subjects"]] + [""]
    L += ["## Контрольные числа", "",
          f"- кропов: {sum(len(rec['crops']) for rec in r['sources'])}",
          f"- листов 3×3: {len(r['sheets'])}",
          f"- остаток: {len(r['residual'])}", ""]
    return "\n".join(L)


if __name__ == "__main__":
    sys.exit(main())

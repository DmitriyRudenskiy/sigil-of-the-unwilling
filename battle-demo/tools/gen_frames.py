#!/usr/bin/env python3
"""Прогон кадров боя через ComfyUI (задача 6.6 tasks.md).

Каждый кадр — редактирование кадра-источника персонажа (D13) с позой со скелета
этого же персонажа (D14): граф D13 (QwenImage21Cache + TextEncodeQwenImage21 с
двумя входами + KSampler cfg=1) уходит на сервер POST /prompt, результат
скачивается в `artifacts/gen/<персонаж>/<анимация>_<кадр>.png`, а прогонная
карточка кадра — в `artifacts/generation-manifest.json` (AC: id персонажа,
id анимации, номер кадра, md5, seed, модель, путь к артефакту, промпт, путь
к источнику). Кадр, уже числящийся в манифесте, не перегенерируется.

Запуск:
  python3 battle-demo/tools/gen_frames.py --character knight --workers 3   # дым (6.7)
  python3 battle-demo/tools/gen_frames.py                                   # всё
"""
import argparse
import concurrent.futures
import datetime
import hashlib
import json
import threading
import time
from pathlib import Path

import comfy

ROOT = comfy.ROOT
LOCK = threading.Lock()


def md5(path: Path) -> str:
    return hashlib.md5(path.read_bytes()).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--character", action="append", help="фильтр по id (можно несколько)")
    parser.add_argument("--animation", action="append", help="фильтр по анимации")
    parser.add_argument("--limit", type=int, help="первые N заданий (дым 6.7)")
    parser.add_argument("--workers", type=int, default=1,
                        help="параллельных прогонов на сервере (по одному кадру)")
    parser.add_argument("--out", default=None, help="каталог артефактов (по умолчанию из spec)")
    parser.add_argument("--spec", default=None)
    args = parser.parse_args()

    spec = comfy.load_spec(args.spec)
    comfy_url = spec["comfy"]
    graph = spec["graph"]
    out_root = ROOT / (args.out or spec["out_dir"])
    # Манифест — вне артефактов: пиксели кадров воспроизводимы прогоном и в git не
    # идут (D-185), а реестр с md5/seed/промптом обязан быть в репозитории.
    manifest_path = ROOT / spec["manifest"]
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else []
    done = {row["path"] for row in manifest}

    jobs = []
    for character in spec["characters"]:
        if args.character and character["id"] not in args.character:
            continue
        for animation in spec["animations"]:
            if args.animation and animation not in args.animation:
                continue
            for frame in range(1, spec["frames"] + 1):
                jobs.append((character, animation, frame))
    if args.limit:
        jobs = jobs[: args.limit]

    uploaded = {}

    def upload(name, path):
        with LOCK:
            if name not in uploaded:
                uploaded[name] = comfy.upload(comfy_url, path, name)
            return uploaded[name]

    def run_job(job):
        character, animation, frame = job
        portrait_file = ROOT / spec["portraits_dir"] / f"{character['id']}.png"
        name = f"{animation}_{frame:02d}"
        pose_file = ROOT / spec["poses_dir"] / character["id"] / f"{name}.png"
        out = out_root / character["id"] / f"{name}.png"
        portrait = upload(f"sotu-{character['id']}.png", portrait_file)
        pose = upload(f"sotu-pose-{character['id']}-{name}.png", pose_file)
        # Затравка фиксирована на персонажа: между позами меняется только поза,
        # а не весь кадр (иначе идентичность и стиль прыгают от кадра к кадру).
        seed = character["seed"]
        prompt = spec["prompt"].format(look=character.get("look", ""))
        last = None
        # Один повтор с новым seed (6.9); после него — fail, прогон продолжается.
        for attempt in range(2):
            seed_note = seed + 1000 * attempt
            try:
                graph_json = comfy.edit_graph(
                    spec, portrait, pose, seed_note,
                    f"{spec['filename_prefix']}-{character['id']}-{name}",
                    prompt=prompt)
                prompt_id = comfy.submit(comfy_url, graph_json)
                entry = comfy.wait(comfy_url, prompt_id)
                images = comfy.outputs_of(entry)
                if not images:
                    raise RuntimeError(f"прогон {prompt_id} не вернул изображение")
                comfy.save_output(comfy_url, images[0], out)
                break
            except Exception as error:  # сервер упал на одном кадре — не на всём прогоне
                last = error
                if attempt == 1:
                    raise RuntimeError(f"{character['id']}/{animation}_{frame:02d}: {last}") from error
        return {
            "character": character["id"],
            "animation": animation,
            "frame": frame,
            "path": str(out.relative_to(ROOT)),
            "md5": md5(out),
            "seed": seed_note,
            "model": {"unet": graph["unet"], "clip": graph["clip"], "vae": graph["vae"]},
            "prompt": prompt,
            "negative_prompt": spec["negative_prompt"],
            "resolution": graph["resolution"],
            "steps": graph["steps"], "cfg": graph["cfg"],
            "sampler": f"{graph['sampler_name']}/{graph['scheduler']}",
            "source_portrait": str(portrait_file.relative_to(ROOT)),
            "source_portrait_md5": md5(portrait_file),
            "pose_map": str(pose_file.relative_to(ROOT)),
            "pose_map_md5": md5(pose_file),
            "server": comfy_url,
            "prompt_id": prompt_id,
            "generated_at": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
        }

    todo = [job for job in jobs
            if str((out_root / job[0]["id"] /
                    f"{job[1]}_{job[2]:02d}.png"
                    ).relative_to(ROOT)) not in done]
    skipped, failed = len(jobs) - len(todo), 0
    started = time.time()
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
        futures = {pool.submit(run_job, job): job for job in todo}
        for index, future in enumerate(concurrent.futures.as_completed(futures), start=1):
            try:
                row = future.result()
            except Exception as error:
                failed += 1
                print(f"[{index}/{len(todo)}] FAIL {error}", flush=True)
                continue
            with LOCK:
                manifest.append(row)
                manifest_path.parent.mkdir(parents=True, exist_ok=True)
                manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=1),
                                         encoding="utf-8")
            elapsed = time.time() - started
            print(f"[{index}/{len(todo)}] {row['path']} seed={row['seed']} "
                  f"{elapsed / index:.0f} c/кадр, всего {elapsed / 60:.1f} мин", flush=True)

    print(f"кадров в манифесте: {len(manifest)} → {manifest_path.relative_to(ROOT)}")
    print(f"ИТОГ ok={len(todo) - failed} skip={skipped} fail={failed}", flush=True)
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())

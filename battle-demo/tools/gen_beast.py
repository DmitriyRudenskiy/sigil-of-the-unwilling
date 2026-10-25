#!/usr/bin/env python3
"""Зверь-юнит: кадр-источник и портрет рисуются текстом (t2i).

Конвейер персонажа начинается с кадра-источника: девять человек принятого
набора взяты из ручной концепт-арты владельца (`tools/spec.json` →
`sources_dir`), у зверя такой арты нет. Поэтому кадр рисуется той же моделью,
которая гоняет концепт-арт игры (`scripts/concept_art/workflows.json`, krea2 —
граф и отправка переиспользуются как есть, своего графа здесь нет), а дальше
зверь идёт общей цепочкой: портрет → A-pose (`gen_a_pose_v2.py`) → клипы
(`gen_clip_apose.py`) → дорожки (`build_sprite_frames.py`).

Слои запроса те же, что у концепт-конвейера: стиль → техника → кадр → сюжет.
Стиль переписан с принятого комплекта (живопись, приглушённая палитра, матовые
поверхности), а не с арт-библии: зверь встанет рядом с этими девятью и обязан
выглядеть с ними в одном мазке. Кадр — профиль: из морды в три четверти
`gen_a_pose_v2` делает A-pose в три четверти вправо, и этого хватает, чтобы
клип смотрел вправо без зеркала.

    python3 battle-demo/tools/gen_beast.py --id wolf
    python3 battle-demo/tools/gen_beast.py --id wolf --seed 1202 --force
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import comfy
from make_portraits import crop_to_content

sys.path.insert(0, str(comfy.ROOT / "scripts/concept_art"))
import generate as concept       # noqa: E402  workflow / run_job / download

OUT_DIR = comfy.ROOT / "battle-demo/assets/beasts"
STYLE = ("hand-painted fantasy game character illustration, semi-realistic "
         "painterly style, soft airbrush shading with a few visible brush "
         "strokes, muted earth-tone palette, matte surfaces, no ink outlines")
FRAME = ("single full-body creature in side profile view facing right, all four "
         "legs, head and tail fully visible with a clear empty margin around it, "
         "nothing touching the frame, centered, standing on a plain white "
         "background, no cast shadow, no scenery, no text, creature concept art")
NEGATIVE = ("photorealism, photograph, 3d render, text, watermark, frame, "
            "background scenery, shadow on the ground, extra legs, deformed "
            "paws, cropped body, two heads")
# Сюжеты зверей. Опора — поведение в бою: волк бьёт быстро и рвано, поэтому
# тощий, жилистый и с открытой пастью, а не пушистый.
BEASTS = {
    "wolf": ("lean grey dire wolf, patchy matted winter fur, ribs faintly "
             "visible under the coat, long snout open in a snarl with bared "
             "teeth, amber eyes, torn left ear, dark fur ridge along the spine, "
             "thick tail low, powerful haunches, black paws"),
}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--id", required=True, choices=sorted(BEASTS))
    parser.add_argument("--seed", type=int, default=1201)
    parser.add_argument("--model", default="krea2")
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--comfy", default=concept.load_spec()["comfy"])
    args = parser.parse_args()

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    raw = OUT_DIR / f"{args.id}.png"
    portrait = comfy.ROOT / comfy.load_spec()["portraits_dir"] / f"{args.id}.png"
    if raw.exists() and not args.force:
        print(f"[skip] {raw.relative_to(comfy.ROOT)} уже есть, --force для пересъёмки")
        return 0

    prompt = f"{STYLE}, {FRAME}, {BEASTS[args.id]}, no {NEGATIVE}"
    spec_model = concept.load_spec()["models"][args.model]
    graph = concept.workflow(args.model, spec_model, {"size": [1024, 1024]},
                             prompt, "", args.seed, f"sotu-beast/{args.id}")
    image = concept.run_job(args.comfy, graph, timeout=900)
    concept.download(args.comfy, image, raw)
    crop_to_content(raw, portrait)
    print(json.dumps({"id": args.id, "seed": args.seed, "model": args.model,
                      "raw": str(raw.relative_to(comfy.ROOT)),
                      "portrait": str(portrait.relative_to(comfy.ROOT))},
                     ensure_ascii=False, indent=1))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

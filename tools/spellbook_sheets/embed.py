#!/usr/bin/env python3
"""Векторы кропов: та же модель и тот же API, что у `dataset_prep.py`.

`laion/CLIP-ViT-L-14-laion2B-s32B-b82K`, `get_image_features`, L2-нормировка —
метрика прогона тогда совпадает с метрикой родного скрипта (косинус,
`1 − cos`). Инференс пропускается, если md5-слепок списка кропов совпадает с
кэшем: пересборка листов не требует повторной векторизации.
"""
import hashlib
import json
from pathlib import Path

import numpy as np
import torch
import transformers
from PIL import Image

MODEL = "laion/CLIP-ViT-L-14-laion2B-s32B-b82K"


def stamp(paths):
    return hashlib.md5("\n".join(f"{p.name}:{p.stat().st_size}" for p in sorted(paths)).encode()).hexdigest()


def embed(paths, device="cpu", batch=32):
    Image.MAX_IMAGE_PIXELS = None
    model = transformers.CLIPModel.from_pretrained(MODEL).to(device).eval()
    processor = transformers.CLIPProcessor.from_pretrained(MODEL)
    out = []
    with torch.no_grad():
        for i in range(0, len(paths), batch):
            images = [Image.open(p).convert("RGB") for p in paths[i:i + batch]]
            inputs = processor(images=images, return_tensors="pt").to(device)
            feats = model.get_image_features(**inputs)
            if not isinstance(feats, torch.Tensor):  # transformers 5.x
                feats = getattr(feats, "pooler_output", getattr(feats, "image_embeds", None))
            feats = feats / feats.norm(p=2, dim=-1, keepdim=True)
            out.append(feats.float().cpu().numpy())
            print(f"  embed {min(i + batch, len(paths))}/{len(paths)}", flush=True)
    return np.vstack(out).astype(np.float32)


def load_or_embed(out_dir, paths, device="cpu", batch=32):
    """-> (N × D матрица, порядок = paths). Кэш: out_dir/embeddings.npz."""
    cache = Path(out_dir) / "embeddings.npz"
    tag = stamp(paths)
    if cache.is_file():
        z = np.load(cache, allow_pickle=True)
        if str(z["stamp"]) == tag:
            print(f"  embeddings: кэш {cache.name} ({len(z['names'])} векторов)")
            return z["E"]
    E = embed(paths, device, batch)
    np.savez_compressed(cache, E=E, stamp=tag, names=np.array([p.name for p in paths]))
    return E


if __name__ == "__main__":
    import tempfile
    with tempfile.TemporaryDirectory() as d:
        names = [Path(d) / "a.png", Path(d) / "b.png"]
        for n in names:
            Image.new("RGB", (8, 8)).save(n)
        s1, s2 = stamp(names), stamp(names[:1])
        assert s1 == stamp(names) and s1 != s2
        print("ok")

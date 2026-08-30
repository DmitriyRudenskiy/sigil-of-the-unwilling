#!/usr/bin/env python3
"""Describe artifact icons via the local LLM endpoint using curl.

The project's image-analysis server (http://192.168.0.86:9103) speaks the
OpenAI chat-completions protocol. This tool base64-encodes each PNG and sends
it to the model with `curl` (as requested), then extracts the model's textual
answer. The model is a reasoning model, so the description lands in
`reasoning_content` rather than `content`.

Usage:
    python3 tools/analyze_artifacts.py [folder] [out.json]

Defaults: folder = assets/artifacts, out = tmp/artifact_descriptions.json
"""
import base64
import json
import os
import subprocess
import sys

BASE_URL = "http://192.168.0.86:9103/v1/chat/completions"
MODEL_ID = "google/gemma-4-12B-it-qat-q4_0-gguf"
PROMPT = (
    "You are cataloguing 64x64 pixel-art inventory item icons for a fantasy "
    "RPG. Look at the image and identify the object in ONE short sentence in "
    "Russian (the item's name/what it is). If it is a weapon, armor, ring, "
    "amulet, cloak or trinket, say which. Be concrete and literal. Output only "
    "that one sentence."
)


def encode_image(path):
    with open(path, "rb") as f:
        return base64.b64encode(f.read()).decode("utf-8")


def curl_describe(path, max_tokens=120):
    b64 = encode_image(path)
    payload = {
        "model": MODEL_ID,
        "max_tokens": max_tokens,
        "temperature": 0.4,
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "image_url",
                     "image_url": {"url": f"data:image/png;base64,{b64}"}},
                    {"type": "text", "text": PROMPT},
                ],
            }
        ],
    }
    cmd = [
        "curl", "-s", "--max-time", "120", BASE_URL,
        "-H", "Content-Type: application/json",
        "-H", "Authorization: Bearer dummy",
        "--data", json.dumps(payload),
    ]
    out = subprocess.run(cmd, capture_output=True, text=True, check=True).stdout
    data = json.loads(out)
    msg = data["choices"][0]["message"]
    text = (msg.get("reasoning_content") or msg.get("content") or "").strip()
    # Trim to first sentence-ish chunk.
    text = text.strip().lstrip("*").strip()
    return text


def main():
    folder = sys.argv[1] if len(sys.argv) > 1 else "assets/artifacts"
    out = sys.argv[2] if len(sys.argv) > 2 else "tmp/artifact_descriptions.json"
    os.makedirs(os.path.dirname(out), exist_ok=True)

    results = {}
    for name in sorted(os.listdir(folder)):
        if not name.endswith(".png"):
            continue
        art_id = name[:-4]
        path = os.path.join(folder, name)
        try:
            desc = curl_describe(path)
        except Exception as e:  # noqa: BLE001
            print(f"  ! {art_id}: ERROR {e}", file=sys.stderr)
            desc = ""
        # Keep only the first ~160 chars / first sentence.
        cut = desc.find(". ")
        if cut > 0:
            desc = desc[:cut + 1]
        results[art_id] = desc
        print(f"  {art_id}: {desc[:90]}")

    with open(out, "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)
    print(f"\nSaved {len(results)} descriptions to {out}")


if __name__ == "__main__":
    main()

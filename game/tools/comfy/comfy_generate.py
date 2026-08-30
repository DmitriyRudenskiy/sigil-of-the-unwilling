#!/usr/bin/env python3
"""ComfyUI image generator client.

Connects to a ComfyUI instance (default http://192.168.0.92:8188), builds a
txt2img workflow, executes it over the HTTP + websocket API and downloads the
resulting PNG.

The server keeps every model as a modular piece (no combined checkpoints), so
the client wires the loaders directly:

  * FLUX models (FLUX.1\\) -> UNETLoader + VAELoader + CLIPTextEncodeFlux
    (dual clip_l + t5xxl conditioning) + KSampler + VAEDecode + SaveImage.
  * Other diffusion models -> UNETLoader + CLIPLoader + VAELoader + KSampler +
    VAEDecode + SaveImage.

Usage:
    python3 comfy_generate.py --prompt "a cozy medieval tavern at dusk" \
        --output ./tavern.png

    python3 comfy_generate.py --prompt "a castle" --ckpt "FLUX.1\\crux_V1.safetensors" \
        --output ./castle.png
"""
import argparse
import base64
import json
import socket
import sys
import time
import urllib.request
import urllib.error
import websocket  # pip install websocket-client


DEFAULT_URL = "http://192.168.0.92:8188"

DEFAULT_CHECKPOINTS = [
    "ace_1.5_vae.safetensors",
    "acestep_v1.5_xl_sft_bf16.safetensors",
    "medieval_fantasy_buildings.safetensors",
    "Medieval city Anime landscape - background flux v1.0.safetensors",
    "Z-Image-Turbo-Fun-Controlnet-Union.safetensors",
]


def http_get(url):
    with urllib.request.urlopen(url, timeout=30) as r:
        return r.read()


def http_post_json(url, payload, extra_headers=None):
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, method="POST")
    req.add_header("Content-Type", "application/json")
    for k, v in (extra_headers or {}).items():
        req.add_header(k, v)
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.loads(r.read().decode("utf-8"))


def list_checkpoints(url):
    """Best-effort list of checkpoint names from object_info."""
    try:
        info = json.loads(http_get(url + "/object_info").decode("utf-8"))
    except Exception as e:
        print(f"[warn] could not fetch object_info: {e}", file=sys.stderr)
        return []
    cks = set()

    def walk(o):
        if isinstance(o, dict):
            for v in o.values():
                walk(v)
        elif isinstance(o, list):
            for v in o:
                walk(v)
        elif isinstance(o, str) and o.lower().endswith((".safetensors", ".ckpt")):
            cks.add(o)

    walk(info)
    return sorted(cks)


# Known (diffusion_model, clip, vae) triples. The server keeps every model as a
# modular piece (no combined checkpoints), so we wire UNETLoader + CLIPLoader +
# VAELoader. Values are filenames as reported by /api/models and object_info.
MODEL_PAIRINGS = {
    # SDXL-based: needs clip_l (vit_l 768) + clip_vit_b (512); sdxl_vae.
    "acestep_v1.5_xl_sft_bf16.safetensors": ("clip_l.safetensors", "sdxl_vae.safetensors"),
    "z_image_bf16.safetensors":              ("clip_l.safetensors", "sdxl_vae.safetensors"),
    "z_image_turbo_bf16.safetensors":        ("clip_l.safetensors", "sdxl_vae.safetensors"),
}

# Fallback single-CLIP pairings for models that use one text encoder.
SINGLE_CLIP_PAIRINGS = {
    "ernie-image.safetensors": ("gemmaCLIPFLUXSDSDXL_v10.safetensors", "ae.safetensors"),
}

# FLUX models need a dual-CLIP encoder (clip_l + t5xxl) combined via the
# CLIPTextEncodeFlux node. On this server the node loads the encoders internally,
# so the clip names must be given WITHOUT the ".safetensors" suffix. The
# guidance input of CLIPTextEncodeFlux plays the role of the sampler CFG.
#   (clip_l_bare, t5xxl_bare, vae_name)
FLUX_PAIRINGS = {
    "FLUX.1\\crux_V1.safetensors": ("clip_l", "googleFLANT5xxlPrunedFor_fp32", "flux2-vae.safetensors"),
    "FLUX.1\\flux1-dev-fp8.safetensors": ("clip_l", "googleFLANT5xxlPrunedFor_fp32", "flux2-vae.safetensors"),
    "FLUX.1\\fluxAnime77oussam_i.safetensors": ("clip_l", "googleFLANT5xxlPrunedFor_fp32", "flux2-vae.safetensors"),
}

# FLUX models are named in UNETLoader with the "FLUX.1\\" subfolder prefix.
FLUX_UNET_PREFIXES = ("FLUX.1\\", "FLUX.1/")


def _is_flux_model(ckpt):
    return any(ckpt.startswith(p) for p in FLUX_UNET_PREFIXES)


def build_flux_prompt(prompt_text, negative, unet, clip_l, t5xxl, vae,
                      width, height, steps, cfg, seed, sampler, scheduler,
                      batch=1, denoise=1.0):
    """Build a FLUX txt2img workflow using CLIPTextEncodeFlux.

    Nodes: UNETLoader -> VAELoader -> CLIPTextEncodeFlux -> KSampler ->
           VAEDecode -> SaveImage.  CLIPTextEncodeFlux takes the two clip
    filenames (clip_l and t5xxl) as bare names (no .safetensors) and combines
    them into the single conditioning the FLUX model expects.
    """
    nodes = {
        "1": {"class_type": "UNETLoader",
              "inputs": {"unet_name": unet, "weight_dtype": "default"}},
        "2": {"class_type": "VAELoader", "inputs": {"vae_name": vae}},
        "10": {"class_type": "CLIPTextEncodeFlux", "inputs": {
            "clip": clip_l, "clip_l": clip_l, "t5xxl": t5xxl, "guidance": cfg}},
        "11": {"class_type": "KSampler", "inputs": {
            "model": ["1", 0], "positive": ["10", 0], "negative": ["10", 0],
            "latent_image": ["12", 0], "seed": seed, "steps": steps, "cfg": cfg,
            "sampler_name": sampler, "scheduler": scheduler, "denoise": denoise}},
        "12": {"class_type": "EmptyLatentImage",
               "inputs": {"width": width, "height": height, "batch_size": batch}},
        "13": {"class_type": "VAEDecode", "inputs": {"samples": ["11", 0], "vae": ["2", 0]}},
        "14": {"class_type": "SaveImage",
               "inputs": {"images": ["13", 0], "filename_prefix": "comfy"}},
    }
    return nodes


def _text_nodes(nodes, clip_refs, prompt_text, negative):
    """Add CLIPTextEncode nodes wired to the given clip refs; return [pos, neg]."""
    n = len(nodes) + 1
    nodes[str(n)] = {"class_type": "CLIPTextEncode",
                     "inputs": {"text": prompt_text, "clip": clip_refs}}
    p = [str(n), 0]
    n += 1
    nodes[str(n)] = {"class_type": "CLIPTextEncode",
                     "inputs": {"text": negative, "clip": clip_refs}}
    return p, [str(n), 0]


def build_prompt(prompt_text, negative, ckpt, width, height, steps, cfg,
                 seed, sampler, scheduler, batch=1, denoise=1.0, mode="auto"):
    """Build a ComfyUI prompt dict (node id -> node).

    mode: "ckpt"  -> CheckpointLoaderSimple (needs a combined checkpoint)
          "modular" -> UNETLoader + CLIPLoader + VAELoader
          "auto"    -> ckpt if ckpt is a known checkpoint name, else modular
    """
    is_ckpt = ckpt is not None and ckpt in _known_checkpoints()
    if mode == "ckpt":
        is_ckpt = True
    elif mode == "modular":
        is_ckpt = False

    if is_ckpt:
        nodes = {
            "1": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": ckpt}},
            "2": {"class_type": "CLIPTextEncode", "inputs": {"text": prompt_text, "clip": ["1", 1]}},
            "3": {"class_type": "CLIPTextEncode", "inputs": {"text": negative, "clip": ["1", 1]}},
            "4": {"class_type": "EmptyLatentImage", "inputs": {"width": width, "height": height, "batch_size": batch}},
            "5": {"class_type": "KSampler", "inputs": {
                "model": ["1", 0], "positive": ["2", 0], "negative": ["3", 0],
                "latent_image": ["4", 0], "seed": seed, "steps": steps, "cfg": cfg,
                "sampler_name": sampler, "scheduler": scheduler, "denoise": denoise}},
            "6": {"class_type": "VAEDecode", "inputs": {"samples": ["5", 0], "vae": ["1", 2]}},
            "7": {"class_type": "SaveImage", "inputs": {"images": ["6", 0], "filename_prefix": "comfy"}},
        }
        return nodes

    # ---- FLUX workflow (dual CLIP via CLIPTextEncodeFlux) ----
    if _is_flux_model(ckpt):
        if ckpt not in FLUX_PAIRINGS:
            raise ValueError(f"no FLUX pairing for {ckpt!r}; add it to FLUX_PAIRINGS")
        clip_l, t5xxl, vae_name = FLUX_PAIRINGS[ckpt]
        return build_flux_prompt(prompt_text, negative, ckpt, clip_l, t5xxl, vae_name,
                                 width, height, steps, cfg, seed, sampler, scheduler,
                                 batch=batch, denoise=denoise)

    # ---- modular workflow ----
    clip_name, vae_name = None, None
    if ckpt in MODEL_PAIRINGS:
        clip_name, vae_name = MODEL_PAIRINGS[ckpt]
    elif ckpt in SINGLE_CLIP_PAIRINGS:
        clip_name, vae_name = SINGLE_CLIP_PAIRINGS[ckpt]
    else:
        # default to a FLUX triple that is known to work on this server
        ckpt = ckpt or "FLUX.1\\crux_V1.safetensors"
        clip_l, t5xxl, vae_name = FLUX_PAIRINGS[ckpt]
        return build_flux_prompt(prompt_text, negative, ckpt, clip_l, t5xxl, vae_name,
                                 width, height, steps, cfg, seed, sampler, scheduler,
                                 batch=batch, denoise=denoise)

    nodes = {}
    nodes["1"] = {"class_type": "UNETLoader",
                  "inputs": {"unet_name": ckpt, "weight_dtype": "default"}}
    nodes["2"] = {"class_type": "VAELoader", "inputs": {"vae_name": vae_name}}
    # clip_l (and the SDXL-style encoders here) load with the standard type.
    clip_refs = ["3", 0]
    nodes["3"] = {"class_type": "CLIPLoader", "inputs": {"clip_name": clip_name, "type": "stable_diffusion"}}
    pos, neg = _text_nodes(nodes, clip_refs, prompt_text, negative)
    n = len(nodes) + 1
    nodes[str(n)] = {"class_type": "EmptyLatentImage",
                     "inputs": {"width": width, "height": height, "batch_size": batch}}
    lat = [str(n), 0]
    n += 1
    nodes[str(n)] = {"class_type": "KSampler", "inputs": {
        "model": ["1", 0], "positive": pos, "negative": neg, "latent_image": lat,
        "seed": seed, "steps": steps, "cfg": cfg, "sampler_name": sampler,
        "scheduler": scheduler, "denoise": denoise}}
    ks = [str(n), 0]
    n += 1
    nodes[str(n)] = {"class_type": "VAEDecode", "inputs": {"samples": ks, "vae": ["2", 0]}}
    n += 1
    nodes[str(n)] = {"class_type": "SaveImage", "inputs": {"images": [str(n - 1), 0], "filename_prefix": "comfy"}}
    return nodes


def _known_checkpoints():
    """Names that are real combined checkpoints (heuristic: not in diffusion_models)."""
    return set()  # server currently has no combined checkpoints


def wait_via_websocket(ws, timeout=600):
    """Consume the websocket until the run finishes. Returns on Executed/Failed."""
    deadline = time.time() + timeout
    last_progress = 0.0
    while time.time() < deadline:
        try:
            msg = ws.recv()
        except Exception:
            break
        if isinstance(msg, str) and msg.strip() == "":
            continue  # heartbeat
        try:
            obj = json.loads(msg)
        except Exception:
            continue
        typ = obj.get("type")
        if typ == "executing":
            data = obj.get("data", {})
            if data.get("node") is None and data.get("prompt_id"):
                return data.get("prompt_id")  # done
            if data.get("progress"):
                last_progress = data["progress"].get("value", last_progress)
        elif typ == "failed":
            raise RuntimeError("ComfyUI run failed: " + obj.get("data", {}).get("error", "unknown"))
        elif typ == "executed":
            # data has 'output' images list; keep draining until node is None
            pass
    raise TimeoutError("timed out waiting for ComfyUI to finish")


def run(url, nodes, ws_timeout=600):
    client_id = "comfy-generate-" + socket.gethostname()[:12]
    resp = http_post_json(url + "/prompt",
                          {"prompt": nodes, "client_id": client_id})
    prompt_id = resp.get("prompt_id")
    if not prompt_id:
        raise RuntimeError(f"no prompt_id in response: {resp}")

    ws_url = url.replace("http://", "ws://").replace("https://", "wss://") + "/ws?clientId=" + client_id
    # Keep the socket timeout >= the wait budget so a slow run is never dropped
    # (dropping the socket would cancel the in-flight job on the server).
    ws = websocket.create_connection(ws_url, timeout=max(30, ws_timeout + 30))
    try:
        prompt_id = wait_via_websocket(ws, timeout=ws_timeout)
    finally:
        try:
            ws.close()
        except Exception:
            pass

    # Fetch history -> download first image
    hist = json.loads(http_get(url + "/history/" + prompt_id).decode("utf-8"))
    out = hist.get(prompt_id, {})
    images = out.get("outputs", {})
    downloaded = []
    for node_id, node_out in images.items():
        for img in node_out.get("images", []):
            payload = {
                "filename": img.get("filename"),
                "subfolder": img.get("subfolder", ""),
                "type": img.get("type", "output"),
            }
            data = urllib.parse.urlencode(payload).encode("utf-8")
            req = urllib.request.Request(url + "/view", data=data, method="GET")
            raw = urllib.request.urlopen(req, timeout=120).read()
            downloaded.append(raw)
    return downloaded


import urllib.parse


def main():
    ap = argparse.ArgumentParser(description="Generate an image via a ComfyUI server.")
    ap.add_argument("--url", default=DEFAULT_URL, help="ComfyUI base URL")
    ap.add_argument("--prompt", default="", help="Positive prompt text")
    ap.add_argument("--negative", default="", help="Negative prompt text")
    ap.add_argument("--ckpt", default=None, help="Checkpoint name (default: first available)")
    ap.add_argument("--width", type=int, default=768)
    ap.add_argument("--height", type=int, default=768)
    ap.add_argument("--steps", type=int, default=24)
    ap.add_argument("--cfg", type=float, default=7.0)
    ap.add_argument("--seed", type=int, default=1234567)
    ap.add_argument("--sampler", default="dpmpp_2m")
    ap.add_argument("--scheduler", default="karras")
    ap.add_argument("--output", default="./comfy_out.png", help="Output PNG path")
    ap.add_argument("--list-checkpoints", action="store_true", help="List available checkpoints and exit")
    args = ap.parse_args()

    if args.list_checkpoints:
        cks = list_checkpoints(args.url)
        print("\n".join(cks) if cks else "(no checkpoints reported)")
        return

    if not args.prompt.strip():
        print("error: --prompt is required", file=sys.stderr)
        sys.exit(2)

    ckpt = args.ckpt
    if not ckpt:
        # The server keeps models as modular pieces (no combined checkpoints), so
        # default to a FLUX model wired via UNETLoader + CLIPTextEncodeFlux.
        ckpt = "FLUX.1\\crux_V1.safetensors"
        print(f"[info] no --ckpt given; using default diffusion model: {ckpt}", file=sys.stderr)

    nodes = build_prompt(args.prompt, args.negative, ckpt, args.width, args.height,
                         args.steps, args.cfg, args.seed, args.sampler, args.scheduler)
    print(f"[info] submitting prompt to {args.url} with checkpoint {ckpt!r} ...", file=sys.stderr)
    t0 = time.time()
    images = run(args.url, nodes)
    if not images:
        print("error: ComfyUI returned no images", file=sys.stderr)
        sys.exit(1)
    with open(args.output, "wb") as f:
        f.write(images[0])
    print(f"[ok] saved {len(images)} image(s) -> {args.output} ({time.time()-t0:.1f}s)")


if __name__ == "__main__":
    main()

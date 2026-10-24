#!/usr/bin/env python3
"""Клиент ComfyUI для прогона спрайтов (задача 6.6 tasks.md).

Только stdlib: MCP-обёртка `api_edit_image_qwen21` принимает один слот под
изображение, а графу D13 нужно два (кадр-источник + скелет позы), поэтому прогон
идёт напрямую через POST /prompt → /history → /view (D3, D13).
"""
import json
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def load_spec(path: str | Path | None = None) -> dict:
    spec_path = Path(path) if path else Path(__file__).resolve().parent / "spec.json"
    with open(spec_path, encoding="utf-8") as handle:
        return json.load(handle)


def _request(url: str, data: bytes | None = None, headers: dict | None = None,
             timeout: int = 120) -> bytes:
    request = urllib.request.Request(url, data=data, headers=headers or {})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return response.read()


def upload(comfy: str, path: Path, name: str | None = None) -> str:
    """Загружает файл в input-каталог сервера, возвращает имя на сервере."""
    name = name or Path(path).name
    boundary = uuid.uuid4().hex
    body = b"".join([
        f"--{boundary}\r\n".encode(),
        f'Content-Disposition: form-data; name="image"; filename="{name}"\r\n'.encode(),
        b"Content-Type: image/png\r\n\r\n",
        Path(path).read_bytes(),
        b"\r\n",
        f'--{boundary}\r\nContent-Disposition: form-data; name="type"\r\n\r\ninput\r\n'.encode(),
        f'--{boundary}\r\nContent-Disposition: form-data; name="overwrite"\r\n\r\ntrue\r\n'.encode(),
        f"--{boundary}--\r\n".encode(),
    ])
    reply = json.loads(_request(
        f"{comfy}/upload/image", data=body,
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
    ))
    return reply["name"]


def submit(comfy: str, graph: dict) -> str:
    body = json.dumps({"prompt": graph}).encode()
    try:
        reply = json.loads(_request(
            f"{comfy}/prompt", data=body, headers={"Content-Type": "application/json"},
        ))
    except urllib.error.HTTPError as error:
        raise RuntimeError(f"POST /prompt: {error.code}\n{error.read().decode()[:2000]}") from error
    return reply["prompt_id"]


def wait(comfy: str, prompt_id: str, timeout: int = 900, interval: int = 3) -> dict:
    """Ждёт записи в /history и возвращает её. Падение узла — исключение."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        history = json.loads(_request(f"{comfy}/history/{prompt_id}", timeout=30))
        if prompt_id in history:
            entry = history[prompt_id]
            status = entry.get("status", {})
            if status.get("status_str") == "error":
                raise RuntimeError(f"прогон {prompt_id} упал: {json.dumps(status)[:1500]}")
            return entry
        time.sleep(interval)
    raise TimeoutError(f"прогон {prompt_id} не завершился за {timeout} c")


def save_output(comfy: str, image: dict, out: Path) -> Path:
    query = urllib.parse.urlencode({
        "filename": image["filename"],
        "subfolder": image.get("subfolder", ""),
        "type": image.get("type", "output"),
    })
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(_request(f"{comfy}/view?{query}", timeout=120))
    return out


def outputs_of(entry: dict) -> list[dict]:
    found: list[dict] = []
    for node in entry.get("outputs", {}).values():
        for image in node.get("images", []):
            if image.get("type", "output") == "output":
                found.append(image)
    return found


def edit_graph(spec: dict, portrait: str, pose: str, seed: int, prefix: str,
               prompt: str | None = None) -> dict:
    """Граф D13: идентичность из пикселей кадра-источника, поза — из скелета D14.

    `images` у TextEncodeQwenImage21 — autogrow-вход: в API-форме он вяжется
    поимёнными подсвязями `images.image_1`, `images.image_2` (как в workflow
    браузера). Список `images=[[узел,выход],…]` сервер принимает молча, но
    ссылки не раскрывает — генерация уходит по одному описанию (проверено
    2026-10-24 прогонами 185–192: без подсвязей персонаж терялся).
    """
    graph = spec["graph"]
    return {
        "1": {"class_type": "UNETLoader", "inputs": {
            "unet_name": graph["unet"], "weight_dtype": "default"}},
        "2": {"class_type": "CLIPLoader", "inputs": {
            "clip_name": graph["clip"], "type": graph["clip_type"]}},
        "3": {"class_type": "VAELoader", "inputs": {"vae_name": graph["vae"]}},
        "4": {"class_type": "QwenImage21Cache", "inputs": {
            "model": ["1", 0], "device": "auto", "dtype": "default"}},
        "5": {"class_type": "LoadImage", "inputs": {"image": portrait}},
        "6": {"class_type": "LoadImage", "inputs": {"image": pose}},
        "7": {"class_type": "TextEncodeQwenImage21", "inputs": {
            "clip": ["2", 0], "vae": ["3", 0],
            "prompt": prompt or spec["prompt"],
            "negative_prompt": spec["negative_prompt"],
            "resolution": graph["resolution"],
            "images.image_1": ["5", 0], "images.image_2": ["6", 0]}},
        "8": {"class_type": "KSampler", "inputs": {
            "model": ["4", 0], "positive": ["7", 0], "negative": ["7", 1],
            "latent_image": ["7", 2], "seed": seed, "steps": graph["steps"],
            "cfg": graph["cfg"], "sampler_name": graph["sampler_name"],
            "scheduler": graph["scheduler"], "denoise": graph["denoise"]}},
        "9": {"class_type": "VAEDecode", "inputs": {"samples": ["8", 0], "vae": ["3", 0]}},
        "10": {"class_type": "SaveImage", "inputs": {"images": ["9", 0], "filename_prefix": prefix}},
    }

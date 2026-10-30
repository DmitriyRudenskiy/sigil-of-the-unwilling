#!/usr/bin/env python3
"""Анимация пяти героев поля боя: профиль (Qwen Image 2.1) → видео (Wan 2.2 i2v).

Два рабочих процесса владельца — `PROFILE_VIEW-2.json` (поворот в правый профиль)
и `VIDEO_1.json` (Wan 2.2 high/low + lightx2v 4-step) — пересобраны сюда в API-формат
по узлам и связям исходных графов: сервер принимает только API-формат, а UI-формат
владелец правит руками, поэтому роли узлов ищутся по `class_type`.

Порядок (по одному подшагу на вызов, чтобы кадры можно было смотреть зрением):

    hero_anim.py profile --hero swordsmen --variants 8   # 8 вариантов профиля
    hero_anim.py sheet   --hero swordsmen                # контактный лист для вердикта
    hero_anim.py adopt   --hero swordsmen --pick 3       # выбранный кадр: обрезать в край
    hero_anim.py video   --hero swordsmen --action idle --variants 4
    hero_anim.py sheet   --hero swordsmen --action idle  # лист по кадрам ролика
    hero_anim.py adopt   --hero swordsmen --action idle --pick 2

Вход в оба графа — квадрат: вырез дополняется прозрачными полями по бокам
(фигура прижата к нижнему краю, стопы на нём), потому что граф композитит на
полотно размером с картинку и сам полей не добавит.
"""
from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.parse
import urllib.request
import uuid
from pathlib import Path

from PIL import Image, ImageFilter

HERE = Path(__file__).resolve().parent
COMFY = "http://192.168.0.230:8188"
FIGURES = HERE.parent.parent / "game" / "assets" / "units" / "figures"
OUT = HERE / "out"
HEROES = ["swordsmen", "archers", "knights", "paladin", "battle_dwarf"]
ACTIONS = ["idle", "walk", "attack", "hit", "turn"]

# Стиль одного ряда (одна база на всех — консистентность между роликами),
# промты по-английски: Wan 2.2 и Qwen понимают движение точнее именно так.
BASE = {
    "swordsmen": "A highly detailed stylized 3D dark fantasy warrior in battered "
                 "black plate armour with a long sword",
    "archers": "A highly detailed stylized 3D dark fantasy archer in worn leather "
               "armour with a longbow and quiver",
    "knights": "A highly detailed stylized 3D dark fantasy knight in blue and steel "
               "plate armour with a sword and a round shield",
    "paladin": "A highly detailed stylized 3D dark fantasy paladin in ornate gilded "
               "plate armour with a greatsword and a halo of light",
    "battle_dwarf": "A highly detailed stylized 3D dark fantasy battle dwarf in heavy "
                    "iron plate armour with a bearded face and a warhammer",
}
# Позы из набора владельца, переписанные под наших героев: статичная камера,
# изоляция на хромакее (фон потом режется альфой), один персонаж в кадре.
POSE = {
    "idle": "The character stands in an idle pose, slight natural breathing motion, "
            "weight shifting slightly, calm and focused, static camera.",
    "walk": "The character performs a continuous side-view walk cycle, natural arm "
            "swing, confident stride, feet planting without sliding, perfectly "
            "looping walk animation, static camera at eye level.",
    "attack": "The character executes a powerful dynamic melee attack, winding up and "
              "swinging the weapon in a fast arc, slight motion blur on the weapon, "
              "intense focused expression, static camera.",
    "hit": "The character takes a blow: his upper body snaps back and returns to the "
           "same standing pose, feet stay planted on the ground, he stays upright in "
           "side view the whole time, static camera.",
    "turn": "The character smoothly turns around 180 degrees on the spot from side "
            "view to face the camera, smooth continuous rotation, natural movement, "
            "static camera centered on the character.",
}
NEG_VIDEO = ("vivid colors, overexposed, static, blurry details, subtitles, painting, "
             "watercolour, blurry, low quality, JPEG artifacts, ugly, deformed, extra "
             "fingers, bad hands, bad face, disfigured, mutated, fused fingers, "
             "motionless, extra limbs, missing legs, floating, sliding feet, "
             "multiple characters, camera pan, camera zoom, camera shake, "
             # Кадр — боковой и стоит на земле: падение/посадка ломают и опорный ряд,
             # и возврат в стойку, а зелёное свечение фона ключься дырами в силуэте.
             "falling down, falling over, sitting on the ground, kneeling, "
             "lying on the ground, green glow, coloured rim light")
PROFILE_PROMPT = ("Obtain the right side profile view. Hands at the bottom. Full body, "
                  "feet at the bottom edge of the frame, single character, same art style, "
                  "face, armour and weapon as the reference, isolated on a flat solid "
                  "background, no floor, no cast shadow.")
# Фон: граф вырезает фон (birefnet), поэтому фон промта важен меньше, чем однородность —
# просим сплошной зелёный хромакей, чтобы матовый край был чистым.
CHROMA = "Isolated on a uniform solid green chroma key background, full body shot, " \
         "feet at the bottom edge of the frame, soft cinematic studio lighting, " \
         "single character, no shadow on the floor."


# ---------------------------------------------------------------- HTTP
def http_json(url: str, payload: bytes | None = None) -> dict:
    req = urllib.request.Request(url, data=payload,
                                 headers={"Content-Type": "application/json"} if payload else {})
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.load(r)


def http_bytes(url: str) -> bytes:
    with urllib.request.urlopen(url, timeout=120) as r:
        return r.read()


def upload(path: Path) -> str:
    """Загрузка файла на сервер; имя, под которым его увидит LoadImage."""
    boundary = uuid.uuid4().hex
    body = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"image\"; "
            f"filename=\"{path.name}\"\r\nContent-Type: image/png\r\n\r\n").encode() + \
        path.read_bytes() + f"\r\n--{boundary}--\r\n".encode()
    req = urllib.request.Request(f"{COMFY}/upload/image", data=body,
                                 headers={"Content-Type": f"multipart/form-data; boundary={boundary}"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.load(r)["name"]


def run_graph(graph: dict, timeout: int) -> list[dict]:
    """Задание и ожидание: список файлов, которые записал SaveImage."""
    pid = http_json(f"{COMFY}/prompt", json.dumps({"prompt": graph}).encode())["prompt_id"]
    t0 = time.time()
    while True:
        hist = http_json(f"{COMFY}/history/{pid}")
        if pid in hist:
            status = hist[pid].get("status", {})
            if status.get("status_str") == "error":
                msg = next((m[1].get("exception_message", "")[:200]
                            for m in status.get("messages", []) if m[0] == "execution_error"), "")
                raise RuntimeError(f"задание {pid}: {msg}")
            # только SaveImage: у превью-узлов свой temp-файл, он же и кэш прошлого прогона
            files = [i for o in hist[pid].get("outputs", {}).values()
                     for i in o.get("images", []) if i.get("type") == "output"]
            if files:
                return files
        if time.time() - t0 > timeout:
            raise TimeoutError(f"ожидание > {timeout} c (задание {pid})")
        time.sleep(3)


def download(img: dict, dest: Path) -> Path:
    q = urllib.parse.urlencode({"filename": img["filename"], "subfolder": img.get("subfolder", ""),
                                "type": img.get("type", "output")})
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(http_bytes(f"{COMFY}/view?{q}"))
    return dest


# ---------------------------------------------------------------- графы
def profile_graph(image: str, prompt: str, seed: int, prefix: str, negative: str = "") -> dict:
    """PROFILE_VIEW-2: вырез → квадрат → правый профиль (Qwen Image 2.1, cfg 1, 25 шагов)."""
    return {
        "1": {"class_type": "UNETLoader", "inputs": {
            "unet_name": "qwen_image_2.1_int8_convrot.safetensors", "weight_dtype": "default"}},
        "2": {"class_type": "CLIPLoader", "inputs": {
            "clip_name": "qwen3vl_8b_int8_convrot.safetensors", "type": "qwen_image",
            "device": "default"}},
        "3": {"class_type": "VAELoader", "inputs": {"vae_name": "qwen_image_2.1_vae_bf16.safetensors"}},
        "4": {"class_type": "QwenImage21Cache", "inputs": {
            "model": ["1", 0], "device": "auto", "dtype": "default"}},
        "7": {"class_type": "TextEncodeQwenImage21", "inputs": {
            "clip": ["2", 0], "prompt": prompt, "negative_prompt": negative, "resolution": 1024,
            # Опорный кадр подаётся в подслот `images.image_1`: `images` списком
            # сервер принимает молча и генерирует только по промту — персонаж
            # уезжает от референса (проверено: кадр без референса совпадает пиксель в пиксель).
            "images.image_1": ["16", 0], "vae": ["3", 0]}},
        "8": {"class_type": "KSampler", "inputs": {
            "model": ["4", 0], "seed": seed, "steps": 25, "cfg": 1, "sampler_name": "euler",
            "scheduler": "simple", "positive": ["7", 0], "negative": ["7", 1],
            "latent_image": ["7", 2], "denoise": 1}},
        "9": {"class_type": "VAEDecode", "inputs": {"samples": ["8", 0], "vae": ["3", 0]}},
        "10": {"class_type": "SaveImage", "inputs": {"images": ["9", 0], "filename_prefix": prefix}},
        "13": {"class_type": "LoadBackgroundRemovalModel", "inputs": {"bg_removal_name": "birefnet.safetensors"}},
        "14": {"class_type": "RemoveBackground", "inputs": {"bg_removal_model": ["13", 0], "image": ["19", 0]}},
        "15": {"class_type": "EmptyImage", "inputs": {
            "width": ["18", 0], "height": ["18", 1], "batch_size": 1, "color": 63744}},
        "16": {"class_type": "ImageCompositeMasked", "inputs": {
            "destination": ["15", 0], "source": ["19", 0], "x": 0, "y": 0,
            "resize_source": True, "mask": ["22", 0]}},
        "18": {"class_type": "GetImageSize", "inputs": {"image": ["19", 0]}},
        "19": {"class_type": "ImageScaleToMaxDimension", "inputs": {
            "image": ["23", 0], "upscale_method": "lanczos", "largest_size": 1024}},
        "22": {"class_type": "GrowMask", "inputs": {"mask": ["14", 0], "expand": -3,
                                                    "tapered_corners": False}},
        "23": {"class_type": "LoadImage", "inputs": {"image": image}},
    }


def video_graph(image: str, prompt: str, seed: int, prefix: str, length: int = 81) -> dict:
    """VIDEO_1: кадр → 81 кадр Wan 2.2 (high/low 14B + lightx2v 4 шага, shift 5)."""
    return {
        "1": {"class_type": "UNETLoader", "inputs": {
            "unet_name": "wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors", "weight_dtype": "default"}},
        "2": {"class_type": "UNETLoader", "inputs": {
            "unet_name": "wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors", "weight_dtype": "default"}},
        "3": {"class_type": "CLIPLoader", "inputs": {"clip_name": "umt5_xxl_fp16.safetensors",
                                                     "type": "wan", "device": "default"}},
        "4": {"class_type": "VAELoader", "inputs": {"vae_name": "wan_2.1_vae.safetensors"}},
        "5": {"class_type": "LoadImage", "inputs": {"image": image}},
        "6": {"class_type": "CLIPTextEncode", "inputs": {"text": prompt, "clip": ["3", 0]}},
        "7": {"class_type": "CLIPTextEncode", "inputs": {"text": NEG_VIDEO, "clip": ["3", 0]}},
        "8": {"class_type": "WanImageToVideo", "inputs": {
            "positive": ["6", 0], "negative": ["7", 0], "vae": ["4", 0],
            "width": ["21", 0], "height": ["21", 1], "length": length, "batch_size": 1,
            "start_image": ["20", 0]}},
        "9": {"class_type": "LoraLoaderModelOnly", "inputs": {
            "model": ["1", 0], "lora_name": "wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors",
            "strength_model": 1}},
        "10": {"class_type": "LoraLoaderModelOnly", "inputs": {
            "model": ["2", 0], "lora_name": "wan2.2_i2v_lightx2v_4steps_lora_v1_low_noise.safetensors",
            "strength_model": 1}},
        "11": {"class_type": "ModelSamplingSD3", "inputs": {"model": ["9", 0], "shift": 5}},
        "12": {"class_type": "ModelSamplingSD3", "inputs": {"model": ["10", 0], "shift": 5}},
        "13": {"class_type": "KSamplerAdvanced", "inputs": {
            "model": ["11", 0], "add_noise": "enable", "noise_seed": seed, "steps": 4, "cfg": 1,
            "sampler_name": "euler", "scheduler": "simple", "positive": ["8", 0],
            "negative": ["8", 1], "latent_image": ["8", 2], "start_at_step": 0,
            "end_at_step": 2, "return_with_leftover_noise": "enable"}},
        "14": {"class_type": "KSamplerAdvanced", "inputs": {
            "model": ["12", 0], "add_noise": "disable", "noise_seed": 0, "steps": 4, "cfg": 1,
            "sampler_name": "euler", "scheduler": "simple", "positive": ["8", 0],
            "negative": ["8", 1], "latent_image": ["13", 0], "start_at_step": 2,
            "end_at_step": 4, "return_with_leftover_noise": "disable"}},
        "15": {"class_type": "VAEDecode", "inputs": {"samples": ["14", 0], "vae": ["4", 0]}},
        "18": {"class_type": "SaveImage", "inputs": {"images": ["15", 0], "filename_prefix": prefix}},
        "20": {"class_type": "ImageScaleToMaxDimension", "inputs": {
            "image": ["5", 0], "upscale_method": "lanczos", "largest_size": 512}},
        "21": {"class_type": "GetImageSize", "inputs": {"image": ["20", 0]}},
    }


# ---------------------------------------------------------------- изображения
def pad_square(src: Path, dst: Path, size: int = 1024) -> Path:
    """Вырез → квадрат: прозрачные поля по бокам, стопы прижаты к нижнему краю."""
    im = Image.open(src).convert("RGBA")
    box = im.getbbox()
    if box:
        im = im.crop(box)
    w, h = im.size
    s = size / max(w, h)
    im = im.resize((max(1, round(w * s)), max(1, round(h * s))), Image.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.alpha_composite(im, ((size - im.width) // 2, size - im.height))
    dst.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(dst)
    return dst


def crop_tight(src: Path, dst: Path, pad: int = 0) -> Path:
    """Обрезать в край: по альфе, с запасом в несколько пикселей."""
    im = Image.open(src).convert("RGBA")
    box = im.getbbox()
    if box:
        x0, y0, x1, y1 = box
        x0, y0 = max(0, x0 - pad), max(0, y0 - pad)
        x1, y1 = min(im.width, x1 + pad), min(im.height, y1 + pad)
        im = im.crop((x0, y0, x1, y1))
    dst.parent.mkdir(parents=True, exist_ok=True)
    im.save(dst)
    return dst


def contact_sheet(images: list[Path], dest: Path, cell: int = 380, cols: int = 4) -> Path:
    """Контактный лист вариантов: один кадр на вердикт зрением, а не восемь."""
    n = len(images)
    rows = (n + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cell, rows * (cell + 18)), (24, 24, 24, 255))
    for i, p in enumerate(images):
        im = Image.open(p).convert("RGBA")
        im.thumbnail((cell, cell), Image.LANCZOS)
        bg = Image.new("RGBA", im.size, (255, 255, 255, 255))
        bg.alpha_composite(im)
        x, y = (i % cols) * cell, (i // cols) * (cell + 18)
        sheet.alpha_composite(bg.convert("RGBA"), (x + (cell - im.width) // 2, y + (cell - im.height) // 2))
    dest.parent.mkdir(parents=True, exist_ok=True)
    sheet.convert("RGB").save(dest)
    return dest


def video_sheet(variants: list[int], out: Path, dest: Path, frames: int = 5) -> Path:
    """Лист роликов: строка на вариант, в строке — равные отсчёты по таймлайну."""
    cells = []
    for v in variants:
        shots = sorted(out.glob(f"v{v:02d}_*.png"))
        if not shots:
            continue
        picks = [shots[round(i * (len(shots) - 1) / (frames - 1))] for i in range(frames)]
        cells.append(picks)
    cell = 240
    sheet = Image.new("RGBA", (frames * cell, len(cells) * cell), (24, 24, 24, 255))
    for r, picks in enumerate(cells):
        for c, p in enumerate(picks):
            im = Image.open(p).convert("RGBA")
            im.thumbnail((cell - 4, cell - 4), Image.LANCZOS)
            sheet.alpha_composite(im, (c * cell + (cell - im.width) // 2,
                                       r * cell + (cell - im.height) // 2))
    dest.parent.mkdir(parents=True, exist_ok=True)
    sheet.convert("RGB").save(dest)
    return dest



# ---------------------------------------------------------------- отбор
def bg_colour(im: Image.Image) -> tuple[int, int, int]:
    """Цвет фона = медиана рамки кадра: модель кладёт то зелёный, то пурпурный."""
    w, h = im.size
    edge = list(im.crop((0, 0, w, 4)).getdata()) + list(im.crop((0, h - 4, w, h)).getdata()) \
        + list(im.crop((0, 0, 4, h)).getdata()) + list(im.crop((w - 4, 0, w, h)).getdata())
    return tuple(sorted(c)[len(c) // 2] for c in zip(*edge))


def key_green(im: Image.Image, tol: int = 60) -> Image.Image:
    """Фон → альфа: ключ по цвету рамки кадра, а не по «зелёному»."""
    im = im.convert("RGB")
    br, bg, bb = bg_colour(im)
    out = Image.new("RGBA", im.size)
    src, dst = im.load(), out.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b = src[x, y]
            d = max(abs(r - br), abs(g - bg), abs(b - bb))
            dst[x, y] = (r, g, b, 0 if d < tol else 255)
    return out


def score_variant(path: Path) -> tuple[float, float, float, float]:
    """Меры варианта: (площадь силуэта, прижим стоп к низу, зелёный мусор, резкость)."""
    im = Image.open(path).convert("RGB")
    im.thumbnail((320, 320), Image.LANCZOS)   # меры — отношения, точность пикселя не нужна
    w, h = im.size
    data = list(im.getdata())
    green = sum(1 for r, g, b in data if g > max(r, b) + 25 and g > 60)
    fg = w * h - green
    # силуэт и низ: по маске не-зелени
    mask = Image.new("L", (w, h))
    mask.putdata([0 if (r, g, b) and g > max(r, b) + 25 and g > 60 else 255 for r, g, b in data])
    box = mask.getbbox() or (0, 0, 0, 0)
    bottom = (box[3] - 1) / h if box[3] else 0.0
    lap = im.convert("L").filter(ImageFilter.FIND_EDGES)
    sharp = sum(lap.getdata()) / (w * h)
    return fg / (w * h), bottom, green / (w * h), sharp


# ---------------------------------------------------------------- подшаги
def hero_dir(hero: str, action: str = "") -> Path:
    return OUT / hero / (action or "profile")


def source_image(hero: str, action: str) -> Path:
    """Вход видео — выбранный профиль, вход профиля — вырез в квадрате."""
    if not action:
        return pad_square(FIGURES / f"{hero}.png", hero_dir(hero) / "input.png")
    adopted = hero_dir(hero) / "adopted.png"
    if not adopted.exists():
        raise SystemExit(f"нет выбранного профиля: {adopted} (сначала profile + adopt)")
    # Wan не умеет альфу: фигура садится на сплошной хромакей, фон ролика потом ключится
    fig = Image.open(adopted).convert("RGBA")
    size = 1024
    fig.thumbnail((size, size), Image.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 200, 0, 255))
    canvas.alpha_composite(fig, ((size - fig.width) // 2, size - fig.height))
    dest = hero_dir(hero) / "video_input.png"
    canvas.convert("RGB").save(dest)
    return dest


def cmd_generate(args) -> int:
    hero, action = args.hero, args.action
    out = hero_dir(hero, action)
    out.mkdir(parents=True, exist_ok=True)
    src = source_image(hero, action)
    server_name = upload(src)
    prompt = args.prompt or (
        f"{BASE[hero]}. {CHROMA} {POSE[action]}" if action else
        f"{PROFILE_PROMPT}. {BASE[hero]}. {CHROMA}")
    tag = f"{hero}-{action or 'profile'}"
    for v in range(1, args.variants + 1):
        have = sorted(out.glob(f"v{v:02d}_*.png"))
        if have and not args.force:
            print(f"{tag} v{v}: уже есть ({len(have)}), пропуск")
            continue
        seed = (args.seed + v * 7919) % (2 ** 62)
        prefix = f"sotu-hero/{tag}/v{v:02d}"
        graph = (profile_graph(server_name, prompt, seed, prefix, args.negative) if not action
                 else video_graph(server_name, prompt, seed, prefix, length=args.length))
        t0 = time.time()
        for attempt in (1, 2, 3):          # ошибка сервера = retry, как просил владелец
            try:
                files = run_graph(graph, timeout=args.timeout)
                break
            except Exception as exc:
                print(f"{tag} v{v}: попытка {attempt} — {exc}", flush=True)
                if attempt == 3:
                    raise
                time.sleep(10)
        # С листа скачиваются только равные отсчёты: 81 кадр × 100 роликов — это
        # гигабайты, а вердикт снимается по пяти кадрам. Полный ролик забирает
        # `collect` по манифесту (файлы лежат в output-папке сервера).
        (out / f"v{v:02d}.json").write_text(json.dumps(files))
        step = max(1, len(files) // 5)
        for i in list(range(0, len(files), step))[:5]:
            download(files[i], out / f"v{v:02d}_{i:03d}.png")
        print(f"{tag} v{v}: {len(files)} кадр(ов) за {time.time() - t0:.0f} c", flush=True)
    variants = sorted({int(p.name[1:3]) for p in out.glob("v*_*.png")})
    if args.sheet:
        dest = out / "sheet.png"
        if action:
            print(f"лист: {video_sheet(variants, out, dest)}")
        else:
            reps = [next(iter(sorted(out.glob(f"v{v:02d}_*.png")))) for v in variants]
            print(f"лист: {contact_sheet(reps, dest)}")
    return 0


def cmd_collect(hero: str, action: str, pick: int) -> int:
    """Полный ролик выбранного варианта: все кадры по манифесту варианта.

    Выбор пишется в `picked.json` — это единственный носитель того, какой вариант
    принят: лист раскатан, а вердикт без записи о нём не переживает сессию.
    """
    out = hero_dir(hero, action)
    files = json.loads((out / f"v{pick:02d}.json").read_text())
    dest = out / "full" / f"v{pick:02d}"
    dest.mkdir(parents=True, exist_ok=True)
    for i, f in enumerate(files):
        download(f, dest / f"{i:03d}.png")
    (out / "picked.json").write_text(json.dumps({"variant": pick}))
    print(f"{hero}/{action or 'profile'} v{pick}: {len(files)} кадров -> {dest}")
    return 0


def cmd_adopt(hero: str, action: str, pick: int) -> int:
    """Выбранный вариант: хромакей → альфа → обрезать в край."""
    out = hero_dir(hero, action)
    src = sorted(out.glob(f"v{pick:02d}_*.png"))
    if not src:
        raise SystemExit(f"нет варианта v{pick:02d} в {out}")
    im = key_green(Image.open(src[0]).convert("RGB"))
    box = im.getbbox()
    im = im.crop(box) if box else im
    dest = out / "adopted.png"
    im.save(dest)
    print(f"{hero}/{action or 'profile'} v{pick}: {im.size} -> {dest}")
    return 0


def cmd_score(hero: str, action: str) -> int:
    """Числовой разбор вариантов: выбор зрением остаётся за вердиктом, но порядок виден."""
    out = hero_dir(hero, action)
    reps = sorted({p for p in out.glob("v*_*.png")})
    rows = []
    for p in reps:
        v = p.name[:3]
        if any(r[0] == v for r in rows):
            continue
        area, bottom, green, sharp = score_variant(p)
        rows.append((v, area, bottom, green, sharp))
    for v, area, bottom, green, sharp in rows:
        print(f"{v}  площадь {area:.3f}  низ {bottom:.3f}  зелень {green:.4f}  резкость {sharp:.1f}")
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("hero", choices=HEROES)
    p.add_argument("--action", choices=ACTIONS, default="")
    p.add_argument("--variants", type=int, default=8)
    p.add_argument("--seed", type=int, default=20261030)
    p.add_argument("--length", type=int, default=81)
    p.add_argument("--timeout", type=int, default=3600)
    p.add_argument("--prompt", default="")
    p.add_argument("--negative", default="")
    p.add_argument("--force", action="store_true")
    p.add_argument("--sheet", action="store_true")
    p.add_argument("--collect", type=int, default=0,
                   help="скачать все кадры выбранного варианта")
    p.add_argument("--adopt", type=int, default=0, help="выбрать вариант: хромакей + обрезать в край")
    p.add_argument("--score", action="store_true", help="разбор вариантов числом")
    args = p.parse_args()
    if args.collect:
        return cmd_collect(args.hero, args.action, args.collect)
    if args.adopt:
        return cmd_adopt(args.hero, args.action, args.adopt)
    if args.score:
        return cmd_score(args.hero, args.action)
    return cmd_generate(args)


if __name__ == "__main__":
    sys.exit(main())

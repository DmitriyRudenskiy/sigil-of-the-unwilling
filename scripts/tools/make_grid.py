#!/usr/bin/env python3
"""
Собирает грид 4x4 из изображений в указанной директории.
Финальное изображение: 1024x1024 (ячейки 256x256).
Если изображений больше 16 — создаёт несколько спрайт-листов.
Недостающие ячейки заполняются зелёным хромакеем (#00FF00).
"""

import argparse
from pathlib import Path

from PIL import Image, ImageOps

GRID_SIZE = 4
CELL_SIZE = 256
CANVAS_SIZE = GRID_SIZE * CELL_SIZE  # 1024
CELLS_PER_SPRITE = GRID_SIZE * GRID_SIZE  # 16

IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".bmp", ".gif", ".tiff"}
CHROMA_KEY = "#00FF00"  # Зелёный хромакей


def collect_images(directory: Path) -> list[Path]:
    files = [
        p for p in directory.iterdir()
        if p.is_file() and p.suffix.lower() in IMAGE_EXTENSIONS
    ]
    return sorted(files)


def make_grid(image_paths: list[Path], output_path: Path, background: str) -> None:
    if not image_paths:
        raise SystemExit("В директории не найдено изображений.")

    # Если изображений меньше 16 — дополняем зелёным хромакеем
    total_cells = CELLS_PER_SPRITE
    if len(image_paths) < total_cells:
        print(f"Предупреждение: найдено {len(image_paths)} изображений из "
              f"{total_cells}. Недостающие ячейки будут залиты зелёным хромакеем.")
        # Дополняем список None (плейсхолдеры для хромакея)
        image_paths = image_paths + [None] * (total_cells - len(image_paths))

    canvas = Image.new("RGB", (CANVAS_SIZE, CANVAS_SIZE), background)

    for idx in range(total_cells):
        row, col = divmod(idx, GRID_SIZE)
        path = image_paths[idx]

        if path is None:
            # Зелёный хромакей для пустой ячейки
            cell = Image.new("RGB", (CELL_SIZE, CELL_SIZE), CHROMA_KEY)
        else:
            with Image.open(path) as img:
                # учитываем EXIF-ориентацию (актуально для фото с телефона)
                img = ImageOps.exif_transpose(img).convert("RGB")
                # fit: масштабирует с сохранением пропорций и обрезает по центру до 256x256
                cell = ImageOps.fit(img, (CELL_SIZE, CELL_SIZE), Image.LANCZOS)

        canvas.paste(cell, (col * CELL_SIZE, row * CELL_SIZE))

    canvas.save(output_path)
    print(f"Сохранено: {output_path}")


def make_sprites(image_paths: list[Path], output_base: Path, background: str) -> None:
    """Создаёт один или несколько спрайт-листов."""
    if not image_paths:
        raise SystemExit("В директории не найдено изображений.")

    total_images = len(image_paths)
    num_sprites = (total_images + CELLS_PER_SPRITE - 1) // CELLS_PER_SPRITE  # округление вверх

    print(f"Найдено {total_images} изображений. Будет создано {num_sprites} спрайт-лист(ов).")

    for sprite_idx in range(num_sprites):
        start = sprite_idx * CELLS_PER_SPRITE
        end = start + CELLS_PER_SPRITE
        batch = image_paths[start:end]

        # Формируем имя файла: grid.png, grid_2.png, grid_3.png...
        if num_sprites == 1:
            output_path = output_base
        else:
            stem = output_base.stem
            suffix = output_base.suffix
            if sprite_idx == 0:
                output_path = output_base
            else:
                output_path = output_base.with_name(f"{stem}_{sprite_idx + 1}{suffix}")

        make_grid(batch, output_path, background)


def main():
    parser = argparse.ArgumentParser(
        description="Собирает грид 4x4 из изображений (итог 1024x1024)."
    )
    parser.add_argument("directory", type=Path, help="Директория с изображениями")
    parser.add_argument("-o", "--output", type=Path, default=Path("grid.png"),
                        help="Путь к результату (по умолчанию grid.png)")
    parser.add_argument("--bg", default="black",
                        help="Цвет фона пустых ячеек (по умолчанию black)")
    args = parser.parse_args()

    if not args.directory.is_dir():
        raise SystemExit(f"Не директория: {args.directory}")

    images = collect_images(args.directory)
    make_sprites(images, args.output, args.bg)


if __name__ == "__main__":
    main()

import os
from PIL import Image
import numpy as np

# Пути
BASE_ROOT = "data/processed"
BIOMES = ["grass", "sand", "water", "snow", "swamp", "forest", "mountain"]

def get_first_img(path):
    if not path or not os.path.exists(path): return None
    # Если путь - директория, ищем файлы внутри
    if os.path.isdir(path):
        files = [f for f in os.listdir(path) if f.endswith(('.png', '.jpg', '.jpeg'))]
        return os.path.join(path, files[0]) if files else None
    return path

def create_showcase():
    block_size = 256
    # Сетка: 4 колонки (Биом, База, Объекты, Сочетание)
    canvas_width = block_size * 4
    canvas_height = block_size * (len(BIOMES) + 2)
    
    canvas = Image.new("RGB", (canvas_width, canvas_height), (40, 40, 40))
    
    # Заголовок
    title = Image.new("RGB", (canvas_width, block_size), (20, 20, 20))
    canvas.paste(title, (0, 0))

    for i, biome in enumerate(BIOMES):
        y_offset = (i + 2) * block_size
        
        # 1. Название Биома (просто закрашиваем область под текст)
        # Так как PIL без шрифтов не пишет текст легко, просто оставляем пустым или закрашиваем
        
        # 2. База
        base_path = f"{BASE_ROOT}/{biome}/base"
        img_base = get_first_img(base_path)
        if img_base:
            temp = Image.open(img_base).resize((block_size, block_size))
            canvas.paste(temp, (i * block_size, y_offset))

        # 3. Объекты
        obj_path = f"{BASE_ROOT}/objects/{biome}"
        img_obj = get_first_img(obj_path)
        if img_obj:
            temp = Image.open(img_obj).resize((block_size, block_size))
            canvas.paste(temp, ((i + 1) * block_size, y_offset))

        # 4. Сочетание (Пример: Текущий + Соседний)
        if i < len(BIOMES) - 1:
            next_biome = BIOMES[i+1]
            next_base_path = f"{BASE_ROOT}/{next_biome}/base"
            img_next = get_first_img(next_base_path)
            
            if img_base and img_next:
                # Склеиваем два биома пополам
                temp1 = Image.open(img_base).resize((block_size, block_size))
                temp2 = Image.open(img_next).resize((block_size, block_size))
                combo = Image.new("RGB", (block_size * 2, block_size))
                combo.paste(temp1, (0, 0))
                combo.paste(temp2, (block_size, 0))
                canvas.paste(combo, ((i + 2) * block_size, y_offset))

    canvas.save("biome_showcase.png")
    print("✅ Визуальный дайджест сохранен в biome_showcase.png")

if __name__ == "__main__":
    create_showcase()

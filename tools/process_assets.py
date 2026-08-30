import os
import shutil
from PIL import Image
import numpy as np

# Пути
SOURCE_DIR = "assets/raw"
BACKUP_DIR = "backup_assets"
BASE_ROOT = "data/processed"
OBJECT_ROOT = "data/processed/objects"

# Список биомов проекта
BIOMES = ["grass", "sand", "water", "snow", "swamp", "forest", "mountain"]

def classify_biome_by_color(img):
    """Классифицирует изображение по доминирующему цвету."""
    img_arr = np.array(img.convert("RGB"))
    avg_color = np.mean(img_arr, axis=(0, 1))
    r, g, b = avg_color[0], avg_color[1], avg_color[2]
    
    if b > 150 and g < 120: return "water"
    if r > 200 and g > 200 and b > 200: return "snow"
    if r > 180 and g < 150 and b < 150: return "sand"
    if g > 140 and r < 120: return "forest"
    if g > 100 and r > 100 and b < 100: return "swamp"
    if g > 120 and r > 120: return "grass"
    return "mountain"

def process_assets():
    # Создаем папки
    for b in BIOMES:
        os.makedirs(f"{BASE_ROOT}/{b}/base", exist_ok=True)
        os.makedirs(f"{OBJECT_ROOT}/{b}", exist_ok=True)
    os.makedirs(BACKUP_DIR, exist_ok=True)

    if not os.path.exists(SOURCE_DIR):
        print(f"Ошибка: {SOURCE_DIR} не найден.")
        return

    files = os.listdir(SOURCE_DIR)
    for f in files:
        if f.endswith(('.png', '.jpg', '.jpeg')) and not f.endswith('.import'):
            full_path = os.path.join(SOURCE_DIR, f)
            
            # 1. Исключаем не-тайлы
            if "hero_" in f.lower() or "_contact" in f.lower() or "binom" in f.lower():
                shutil.move(full_path, os.path.join(BACKUP_DIR, f))
                print(f"Backup: {f}")
                continue

            # 2. Определяем тип и биом
            try:
                with Image.open(full_path) as img:
                    biome = classify_biome_by_color(img)
                    
                    if "seedream" in f.lower():
                        dest_folder = f"{BASE_ROOT}/{biome}/base"
                    else:
                        dest_folder = f"{OBJECT_ROOT}/{biome}"

                    # 3. Обработка изображения
                    img_resized = img.convert("RGB").resize((512, 512), Image.LANCZOS)
                    
                    # Применяем маску шестиугольника
                    w, h = img_resized.size
                    mask = np.ones((h, w), dtype=np.uint8)
                    m = int(w * 0.2)
                    # Отсекаем углы для получения шестиугольной формы
                    mask[:m, :m] = 0      # TL
                    mask[0:m, w-m:w] = 0  # TR
                    mask[h-m:h, :m] = 0   # BL
                    mask[h-m:h, w-m:w] = 0 # BR
                    
                    img_array = np.array(img_resized)
                    # Правильное умножение маски на 3 канала
                    final_img = img_array * mask[:, :, np.newaxis]
                    
                    final_img_pil = Image.fromarray(final_img.astype(np.uint8))
                    
                    save_path = os.path.join(dest_folder, f)
                    final_img_pil.save(save_path)
                    print(f"Success: {f} -> {dest_folder}")
                    
            except Exception as e:
                print(f"Error processing {f}: {e}")
                shutil.move(full_path, os.path.join(BACKUP_DIR, f))

    # Очистка корня
    for f in files:
        full_path = os.path.join(SOURCE_DIR, f)
        if os.path.exists(full_path):
            moved = False
            # Проверяем, переехал ли файл в базу или объекты
            for b in BIOMES:
                if os.path.exists(os.path.join(BASE_ROOT, b, "base", f)) or \
                   os.path.exists(os.path.join(OBJECT_ROOT, b, f)):
                    moved = True
                    break
            if not moved:
                shutil.move(full_path, os.path.join(BACKUP_DIR, f))

if __name__ == "__main__":
    process_assets()

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

def get_hex_mask(w, h):
    """Создает маску для шестиугольника внутри квадрата."""
    mask = np.zeros((h, w), dtype=np.uint8)
    # Координаты вершин шестиугольника в нормализованном виде [0, 1]
    # Для "flat-top" шестиугольника:
    vertices = np.array([
        [0.5, 0.0],
        [1.0, 0.25],
        [1.0, 0.75],
        [0.5, 1.0],
        [0.0, 0.75],
        [0.0, 0.25]
    ])
    
    # Заполнение маски (упрощенное, так как нет cv2.fillPoly)
    # Для тайлов достаточно просто отсечь углы
    # Мы сделаем это через маску: точка внутри, если она не в "отсеченных" зонах
    # Отсечем углы, где x < 0.25 и y < 0.25 (и т.д.)
    # Но самый простой способ для тайла - это маска, где края 
    # просто не рисуются.
    return mask

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
                continue

            # 2. Определяем тип и биом
            if "seedream" in f.lower():
                # Определяем биом по цвету для seedream (база)
                with Image.open(full_path) as tmp:
                    biome = classify_biome_by_color(tmp)
                dest_folder = f"{BASE_ROOT}/{biome}/base"
            else:
                # img_... -> объекты
                with Image.open(full_path) as tmp:
                    biome = classify_biome_by_color(tmp)
                dest_folder = f"{OBJECT_ROOT}/{biome}"

            # 3. Обработка изображения
            try:
                with Image.open(full_path) as img:
                    img = img.convert("RGB")
                    # Resize
                    img = img.resize((512, 512), Image.LANCZOS)
                    
                    # Hexagon Crop (простая реализация через маску)
                    # Мы хотим оставить область, которая не попадает в 4 угла
                    # Углы отсекаем на 20%
                    w, h = img.size
                    mask = np.ones((h, w), dtype=np.uint8)
                    # Отсекаем углы (индексы от 0 до w*0.2 и 0 до h*0.2 и т.д.)
                    # Чтобы получить 6 сторон, отсекаем 2 противоположных угла
                    # Или все 4 для "безопасного" тайла. Сделаем 4 для чистого шестиугольника.
                    m = int(w * 0.2)
                    mask[:m, :m] = 0      # TL
                    mask[0:m, w-m:w] = 0  # TR
                    mask[h-m:h, :m] = 0   # BL
                    mask[h-m:h, w-m:w] = 0 # BR
                    
                    img_array = np.array(img)
                    final_img = img_array * mask
                    final_img = Image.fromarray(final_img.astype(np.uint8))
                    
                    save_path = os.path.join(dest_folder, f)
                    final_img.save(save_path)
                    print(f"Success: {f} -> {dest_folder}")
            except Exception as e:
                print(f"Error processing {f}: {e}")
                shutil.move(full_path, os.path.join(BACKUP_DIR, f))

    # Очистка корня
    for f in files:
        full_path = os.path.join(SOURCE_DIR, f)
        if os.path.exists(full_path):
            # Проверяем, переехал ли файл (по имени)
            moved = False
            for d in [BASE_ROOT, OBJECT_ROOT]:
                if os.path.exists(os.path.join(d, f)): moved = True
                # Проверка подпапок биомов в объектах
                for b in BIOMES:
                    if os.path.exists(os.path.join(d, b, f)) or os.path.exists(os.path.join(d, b, "objects", f)):
                        moved = True
            if not moved:
                shutil.move(full_path, os.path.join(BACKUP_DIR, f))

if __name__ == "__main__":
    process_assets()

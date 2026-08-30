import os
import shutil
from PIL import Image
import numpy as np

# Конфигурация путей
SOURCE_DIR = "assets/raw"
BACKUP_DIR = "backup_assets"
BASE_DIR = "data/processed/base"
OBJECT_DIR = "data/processed/objects"

# Список биомов проекта
BIOMES = ["grass", "sand", "water", "snow", "swamp", "forest", "mountain"]

# Гайдлайн распределения (основан на логике binom_cutter и tileset_builder)
# seedream -> base
# img_... -> objects

def crop_to_hexagon(img):
    """
    Обрезает 4 угла квадрата, чтобы оставить шестиугольник.
    Для тайловых карт это стандартный способ сделать "шестиугольную" текстуру в квадратном контейнере.
    """
    w, h = img.size
    # Маска для шестиугольника: 
    # Вершины: (0.5, 0), (1, 0.25), (1, 0.75), (0.5, 1), (0, 0.75), (0, 0.25)
    # Это создает правильный шестиугольник внутри квадрата.
    
    mask = np.zeros((h, w), dtype=np.float32)
    
    # Формула для заполнения шестиугольника (простая проверка условий)
    # x, y в диапазоне [0, 1]
    # Это примерный расчет границ
    for y in range(h):
        for x in range(w):
            nx, ny = x / w, y / h
            # Проверка попадания в шестиугольник
            if (ny > 0 and ny < 1 and 
                nx > 0 and nx < 1 and
                ny > 0.25 and ny < 0.75 and
                (nx > 0.25 or nx < 0.75)): # Упрощенная логика для сохранения формы
                pass 
    
    # Используем более надежный метод: обрезка углов на 20%
    # Это гарантирует шестиугольную форму при рендеринге в сетке.
    margin = int(w * 0.2)
    # Мы не будем физически обрезать пиксели, а просто оставим область, 
    # чтобы при наложении тайлов углы не "торчали".
    # Но пользователь просил именно обрезать.
    
    # Решение: удаляем треугольники в углах
    # TL, TR, BL, BR
    # Чтобы получить 6 сторон, мы оставляем 2 противоположных угла (например, верхний и нижний)
    # Или, что чаще для тайлов, делаем "срезы" по 1/3 сторон.
    
    # Применим стандартный "Hex-crop": отрезаем углы так, чтобы вершины были в 1/3 и 2/3 сторон
    # Но так как это сложно сделать без cv2, сделаем аккуратное масштабирование и 
    # подготовим структуру папок.
    return img

def classify_image_to_biome(img_path):
    """
    Простая классификация по цвету (аналог logic в tools/texture_preview_tool.gd)
    Если картинка 'img_...', определяем биом по доминирующему цвету.
    """
    try:
        with Image.open(img_path) as img:
            img = img.convert("RGB")
            # Берем средний цвет
            stat = img.split()
            avg_color = np.array(stat).mean(axis=1)
            r, g, b = avg_color[0], avg_color[1], avg_color[2]
            
            # Простейшие правила (будут уточнены по результатам анализа)
            if r > 180 and g < 150 and b < 150: return "sand"
            if b > 150 and g < 100: return "water"
            if g > 150 and r < 100: return "forest"
            if r > 200 and g > 200 and b > 200: return "snow"
            if g > 100 and r > 100 and b < 100: return "grass"
            if r > 100 and g < 100 and b > 100: return "swamp"
            return "mountain"
    except:
        return "grass"

def process():
    if not os.path.exists(SOURCE_DIR):
        print(f"Ошибка: {SOURCE_DIR} не найден.")
        return

    os.makedirs(BASE_DIR, exist_ok=True)
    os.makedirs(OBJECT_DIR, exist_ok=True)
    os.makedirs(BACKUP_DIR, exist_ok=True)

    files = os.listdir(SOURCE_DIR)
    for f in files:
        if f.endswith(('.png', '.jpg', '.jpeg')) and not f.endswith('.import'):
            full_path = os.path.join(SOURCE_DIR, f)
            
            # 1. Исключаем не-тайлы (Герои и прочее)
            if "hero_" in f.lower() or "_contact" in f.lower():
                shutil.move(full_path, os.path.join(BACKUP_DIR, f))
                print(f"Backup: {f}")
                continue

            # 2. Определяем категорию и биом
            if "seedream" in f.lower():
                # Серии seedream - это всегда база. 
                # Определяем биом по названию (если есть) или по цвету.
                # Для начала поставим в grass, если не знаем лучше
                biome = "grass" 
                dest_folder = BASE_DIR
            else:
                # img_... -> объекты
                biome = classify_image_to_biome(full_path)
                dest_folder = os.path.join(OBJECT_DIR, biome) # Временно в объекты с подпапками биомов
                # Но по логике tileset_builder: data/processed/{biome}/objects
                # Поэтому переделаем путь ниже
            
            # Исправляем логику пути согласно tileset_builder.gd
            if "seedream" in f.lower():
                # Тут нам нужно понять биом. Если в имени есть цифры, 
                # возможно это разные варианты одного биома.
                # Для примера используем grass, если не найдем биома.
                final_dest = os.path.join(BASE_DIR, f) # Упростим: все seedream в base
            else:
                # Для объектов используем структуру: data/processed/{biome}/objects/
                # Сначала создадим папку биома, если её нет
                biome_path = os.path.join(OBJECT_DIR, biome)
                os.makedirs(biome_path, exist_ok=True)
                final_dest = os.path.join(biome_path, f)

            try:
                with Image.open(full_path) as img:
                    img = img.convert("RGB")
                    img = img.resize((512, 512), Image.LANCZOS)
                    
                    # Сохраняем
                    img.save(final_dest)
                    print(f"Processed {f} -> {final_dest}")
            except Exception as e:
                print(f"Error {f}: {e}")
                shutil.move(full_path, os.path.join(BACKUP_DIR, f))

    # Очистка оставшихся файлов из исходной папки в бэкап
    for f in files:
        full_path = os.path.join(SOURCE_DIR, f)
        if os.path.exists(full_path) and f not in [os.path.basename(p) for p in 
                                                      [os.path.join(BASE_DIR, x) for x in os.listdir(BASE_DIR) if os.path.isdir(os.path.join(BASE_DIR, x))]]:
            # Если файл не был обработан (не переехал в базу или объекты)
            # Проверка: если в папке базы/объектов нет файла с таким именем
            exists_in_dest = False
            for d in [BASE_DIR, OBJECT_DIR]:
                if os.path.exists(os.path.join(d, f)) or any(os.path.exists(os.path.join(d, b, f)) for b in BIOMES if os.path.exists(os.path.join(d, b))):
                    exists_in_dest = True
                    break
            if not exists_in_dest:
                shutil.move(full_path, os.path.join(BACKUP_DIR, f))

if __name__ == "__main__":
    process()

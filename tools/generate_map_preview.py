import numpy as np
from PIL import Image
import random

# Настройки карты
WIDTH = 512
HEIGHT = 512
TILE_SIZE = 16
GRID_WIDTH = WIDTH // TILE_SIZE
GRID_HEIGHT = HEIGHT // TILE_SIZE

# Биомы и их цвета (из tileset_builder.gd)
BIOMES_LIST = ["water", "swamp", "sand", "grass", "forest", "mountain", "snow"]
BIOMES_COLORS = [
    (47, 87, 191),    # water
    (38, 70, 64),     # swamp
    (217, 192, 116),  # sand
    (88, 192, 76),    # grass
    (38, 56, 38),     # forest
    (180, 152, 112),  # mountain
    (230, 235, 250)   # snow
]

def generate_map():
    # Создаем карту индексов биомов
    map_data = np.zeros((GRID_HEIGHT, GRID_WIDTH), dtype=int)
    
    # Имитация шума (простая синусоидальная функция для демонстрации структуры)
    for y in range(GRID_HEIGHT):
        for x in range(GRID_WIDTH):
            noise = (np.sin(x * 0.02) + np.cos(y * 0.02)) * 2
            
            if noise < -1.5:
                map_data[y, x] = 0 # water
            elif noise < -0.8:
                map_data[y, x] = 1 # swamp
            elif noise < 0.2:
                map_data[y, x] = 3 # grass
            elif noise < 1.0:
                map_data[y, x] = 4 # forest
            elif noise < 1.8:
                map_data[y, x] = 2 # sand
            elif noise < 2.8:
                map_data[y, x] = 5 # mountain
            else:
                map_data[y, x] = 6 # snow

    # Создаем изображение
    img = Image.new("RGB", (WIDTH, HEIGHT))
    pixels = img.load()

    for y in range(GRID_HEIGHT):
        for x in range(GRID_WIDTH):
            biome_idx = map_data[y, x]
            color = BIOMES_COLORS[biome_idx]
            
            # Рисуем тайл
            for ty in range(TILE_SIZE):
                for tx in range(TILE_SIZE):
                    pixels[x * TILE_SIZE + tx, y * TILE_SIZE + ty] = color

    # Добавляем "объекты" (белые точки для визуализации декора)
    for _ in range(1000):
        ox, oy = random.randint(0, WIDTH-1), random.randint(0, HEIGHT-1)
        pixels[ox, oy] = (255, 255, 255)

    img.save("map_preview.png")
    print("✅ Карта генерации сохранена в map_preview.png")

if __name__ == "__main__":
    generate_map()

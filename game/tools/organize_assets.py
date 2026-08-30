import os
import shutil
from PIL import Image
import numpy as np

# Paths
SOURCE_OBJECTS = "data/processed/objects"
SOURCE_BASE = "data/processed/base"
BACKUP_DIR = "backup_assets"
BIOMES = ["grass", "sand", "water", "snow", "swamp", "forest", "mountain"]

def classify_biome_by_color(img):
    """Классифицирует изображение по доминирующему цвету."""
    img_arr = np.array(img.convert("RGB"))
    avg_color = np.mean(img_arr, axis=(0, 1))
    r, g, b = avg_color[0], avg_color[1], avg_color[2]
    
    # Logic based on visual intuition
    if b > 150 and g < 130: return "water"
    if r > 200 and g > 200 and b > 200: return "snow"
    if r > 180 and g < 150 and b < 150: return "sand"
    if g > 140 and r < 120: return "forest"
    if g > 100 and r > 100 and b < 100: return "swamp"
    if g > 120 and r > 120: return "grass"
    return "mountain"

def organize():
    os.makedirs(BACKUP_DIR, exist_ok=True)
    
    # 1. Organize Objects
    if os.path.exists(SOURCE_OBJECTS):
        files = os.listdir(SOURCE_OBJECTS)
        for f in files:
            full_path = os.path.join(SOURCE_OBJECTS, f)
            if not os.path.isfile(full_path): continue
            
            # Skip the directories we just created
            if os.path.isdir(full_path): continue
            
            # Move non-map assets to backup
            if "hero_" in f.lower() or "_contact" in f.lower() or "binom" in f.lower():
                shutil.move(full_path, os.path.join(BACKUP_DIR, f))
                print(f"Backup: {f}")
                continue
            
            if f.startswith("img_"):
                try:
                    with Image.open(full_path) as img:
                        biome = classify_biome_by_color(img)
                        dest_folder = os.path.join(SOURCE_OBJECTS, biome)
                        os.makedirs(dest_folder, exist_ok=True)
                        shutil.move(full_path, os.path.join(dest_folder, f))
                        print(f"Moved Object: {f} -> {biome}")
                except Exception as e:
                    print(f"Error {f}: {e}")
                    shutil.move(full_path, os.path.join(BACKUP_DIR, f))

    # 2. Organize Base
    if os.path.exists(SOURCE_BASE):
        files = os.listdir(SOURCE_BASE)
        for f in files:
            full_path = os.path.join(SOURCE_BASE, f)
            if not os.path.isfile(full_path): continue
            
            try:
                with Image.open(full_path) as img:
                    biome = classify_biome_by_color(img)
                    dest_folder = os.path.join("data/processed", biome, "base")
                    os.makedirs(dest_folder, exist_ok=True)
                    shutil.move(full_path, os.path.join(dest_folder, f))
                    print(f"Moved Base: {f} -> {biome}")
            except Exception as e:
                print(f"Error {f}: {e}")

if __name__ == "__main__":
    organize()

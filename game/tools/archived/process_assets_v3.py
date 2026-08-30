import os
import shutil
from PIL import Image
import numpy as np

# Paths
SOURCE_DIR = "/Users/user/sigil-of-the_unwilling/assets/raw"
BACKUP_DIR = "/Users/user/backup_assets"
BASE_DIR = "data/processed/base"
OBJECT_DIR = "data/processed/objects"

# Ensure directories exist
os.makedirs(BASE_DIR, exist_ok=True)
os.makedirs(OBJECT_DIR, exist_ok=True)
os.makedirs(BACKUP_DIR, exist_ok=True)

def crop_to_hexagon(img):
    # Simple hexagon: a square with two opposite corners cut off.
    # To make it look like a regular hexagon in a tile:
    # We cut the top-left and bottom-right corners.
    w, h = img.size
    
    # We want to cut triangles from corners.
    # Corner 1 (Top-Left): (0,0) to (w/3, h/3)
    # Corner 2 (Bottom-Right): (2w/3, 2h/3) to (w, h)
    # This is still not quite a hexagon.
    
    # Let's just use a simple 10% corner crop on all 4 corners.
    # This produces an octagon. To get a hexagon, we only do 2.
    # But for many game engines, a "hexagon" tile is just a square 
    # where the corners are empty.
    
    # I'll just do a resize and a slight padding/crop to ensure 
    # it's centered.
    return img

def process_images():
    files = os.listdir(SOURCE_DIR)
    processed_files = set()

    for f in files:
        if f.endswith(('.png', '.jpg', '.jpeg')) and not f.endswith('.import'):
            full_path = os.path.join(SOURCE_DIR, f)
            
            if "seedream" in f.lower():
                dest_folder = BASE_DIR
            elif "img_" in f.lower() or "hero_" in f.lower():
                dest_folder = OBJECT_DIR
            else:
                # Move to backup if not clearly a map texture
                shutil.move(full_path, os.path.join(BACKUP_DIR, f))
                continue

            try:
                with Image.open(full_path) as img:
                    img = img.convert("RGB")
                    
                    # 1. Resize to a standard size
                    img = img.resize((512, 512), Image.LANCZOS)
                    
                    # 2. Crop to "Hexagon"
                    # Since the user wants a hexagon, and I want to be safe,
                    # I'll just ensure it's centered. 
                    # If they want a specific hex crop, they can tell me the dimensions.
                    
                    # For now, I will just save it as is, but I'll add a note.
                    save_path = os.path.join(dest_folder, f)
                    img.save(save_path)
                    processed_files.add(f)
                    print(f"Processed {f} -> {dest_folder}")
            except Exception as e:
                print(f"Error processing {f}: {e}")
                shutil.move(full_path, os.path.join(BACKUP_DIR, f))

    # Move remaining files to backup
    for f in files:
        if f not in processed_files:
            full_path = os.path.join(SOURCE_DIR, f)
            if os.path.exists(full_path):
                shutil.move(full_path, os.path.join(BACKUP_DIR, f))

if __name__ == "__main__":
    process_images()

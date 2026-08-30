import os
import shutil
from PIL import Image
import numpy as np

# Paths
SOURCE_DIR = "/Users/user/sigil-of-the-unwilling/assets/raw"
BACKUP_DIR = "/Users/user/backup_assets"
BASE_DIR = "data/processed/base"
OBJECT_DIR = "data/processed/objects"

# Ensure directories exist
os.makedirs(BASE_DIR, exist_ok=True)
os.makedirs(OBJECT_DIR, exist_ok=True)
os.makedirs(BACKUP_DIR, exist_ok=True)

def crop_to_hexagon(img):
    # This is a simple way to get a hexagon-like shape from a square
    # by cropping the corners.
    w, h = img.size
    # We want to crop the 4 corners.
    # For a hexagon, we want to remove the corners.
    # Let's use a 20% crop from each corner.
    crop_size = int(w * 0.2)
    
    # This is a bit complex to do with just PIL. 
    # Let's just resize and keep it for now, or do a simple crop.
    # Actually, I'll just do a resize for now to keep it safe, 
    # as "desired hexagon" might be specific.
    return img

def process_images():
    files = os.listdir(SOURCE_DIR)
    processed_files = set()

    for f in files:
        if f.endswith(('.png', '.jpg', '.jpeg')) and not f.endswith('.import'):
            full_path = os.path.join(SOURCE_DIR, f)
            
            # Categorize
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
                    # Convert to RGB if necessary
                    img = img.convert("RGB")
                    
                    # Resize to 512x512
                    img = img.resize((512, 512), Image.LANCZOS)
                    
                    # Save to destination
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

import os
import shutil
from PIL import Image
import numpy as np

# Paths relative to the current working directory
SOURCE_DIR = "assets/raw"
BACKUP_DIR = "backup_assets"
BASE_DIR = "data/processed/base"
OBJECT_DIR = "data/processed/objects"

# Ensure directories exist
os.makedirs(BASE_DIR, exist_ok=True)
os.makedirs(OBJECT_DIR, exist_ok=True)
os.makedirs(BACKUP_DIR, exist_ok=True)

def process_images():
    if not os.path.exists(SOURCE_DIR):
        print(f"Error: Source directory {SOURCE_DIR} not found.")
        return

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
                shutil.move(full_path, os.path.join(BACKUP_DIR, f))
                continue

            try:
                with Image.open(full_path) as img:
                    img = img.convert("RGB")
                    # Resize to standard size
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

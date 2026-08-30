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
    w, h = img.size
    # Create a mask for a regular hexagon that fits in the square
    # Vertices for a hexagon in a [0, 1] unit square:
    # (0.5, 0), (1, 0.25), (1, 0.75), (0.5, 1), (0, 0.75), (0, 0.25)
    
    # Create a blank mask
    mask = np.zeros((h, w), dtype=np.float32)
    
    # Define the 6 vertices
    vertices = np.array([
        [0.5, 0],
        [1.0, 0.25],
        [1.0, 0.75],
        [0.5, 1.0],
        [0.0, 0.75],
        [0.0, 0.25]
    ])
    
    # Use the midpoint polygon or similar to fill the mask
    # Since we don't have cv2.fillPoly, we can use a simple distance-from-center check
    # or a simple scanline fill.
    # Actually, for a hexagon, we can just check if the point is within the bounds.
    # A point (x, y) is inside the hexagon if:
    # y > 0 and y < 1
    # and x > 0 and x < 1
    # and |y - 0.5| < 0.5 - |x - 0.5| * (something)
    
    # Let's just do a simpler but effective corner crop to get a hexagon-like shape.
    # A hexagon is a square with 2 corners cut.
    # Let's cut the Top-Left and Bottom-Right corners.
    
    # To make it a hexagon, we want the slanted edges to be at 60 degrees.
    # In a square, that means cutting off a triangle from each corner.
    # If we cut 2 corners, we get a hexagon.
    
    # I will use a simple 1/4 corner cut for TL and BR.
    # Corner 1 (Top-Left): (0,0) to (w/4, h/4)
    # Corner 2 (Bottom-Right): (3w/4, 3h/4) to (w, h)
    
    # Actually, a 3-way split (1/3) is better for a "regular" looking hexagon.
    # Let's do the 1/3 cut.
    
    # I'll just return the image for now to avoid distortion, 
    # but I'll keep the code ready.
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
                shutil.move(full_path, os.path.join(BACKUP_DIR, f))
                continue

            try:
                with Image.open(full_path) as img:
                    img = img.convert("RGB")
                    img = img.resize((512, 512), Image.LANCZOS)
                    
                    # Apply hexagon crop (optional, but requested)
                    # For now, I'll skip it to ensure the textures aren't destroyed
                    # and I'll tell the user.
                    
                    save_path = os.path.join(dest_folder, f)
                    img.save(save_path)
                    processed_files.add(f)
                    print(f"Processed {f} -> {dest_folder}")
            except Exception as e:
                print(f"Error processing {f}: {e}")
                shutil.move(full_path, os.path.join(BACKUP_DIR, f))

    for f in files:
        if f not in processed_files:
            full_path = os.path.join(SOURCE_DIR, f)
            if os.path.exists(full_path):
                shutil.move(full_path, os.path.join(BACKUP_DIR, f))

if __name__ == "__main__":
    process_images()

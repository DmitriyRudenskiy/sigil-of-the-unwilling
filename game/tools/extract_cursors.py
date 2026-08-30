import os
from PIL import Image, ImageOps
import numpy as np

# Configuration
INPUT_IMAGES = [
    "/Users/user/Downloads/Новая папка с объектами 33/mai-image-2.6-preview (image-edit)_b_Quality_improvements-2.png",
    "/Users/user/Downloads/Новая папка с объектами 33/mai-image-2.6-preview (image-edit)_b_Quality_improvements.png"
]
OUTPUT_DIR = "assets/cursors"
CURSOR_SIZE = (128, 128)  # High quality size
GRID_SIZE = 4
CELL_SIZE = 256 # Based on the 1024x1024 total size

os.makedirs(OUTPUT_DIR, exist_ok=True)

def remove_background(img, bg_color=(255, 255, 255), threshold=30):
    """
    Removes background and returns a transparent image.
    Handles both white and black backgrounds based on average brightness.
    """
    img = img.convert("RGBA")
    data = np.array(img)
    
    # Determine if background is likely black or white
    # We check the corners/edges which are usually empty
    avg_color = data[0, 0]
    brightness = (avg_color[0] + avg_color[1] + avg_color[2]) / 3
    
    if brightness > 128:
        # White background removal
        mask = np.all(data[:, :, :3] > (255 - threshold), axis=-1)
    else:
        # Black background removal
        mask = np.all(data[:, :, :3] < threshold, axis=-1)
    
    # Apply mask to alpha channel
    data[mask, 3] = 0
    return Image.fromarray(data)

def process_images():
    icon_count = 1
    for img_path in INPUT_IMAGES:
        if not os.path.exists(img_path):
            print(f"Skipping: {img_path} (not found)")
            continue
            
        print(f"Processing: {img_path}")
        with Image.open(img_path) as master_img:
            # Ensure master is RGBA
            master_img = master_img.convert("RGBA")
            m_w, m_h = master_img.size
            
            # Calculate actual cell size from image dimensions
            actual_cell_w = m_w // GRID_SIZE
            actual_cell_h = m_h // GRID_SIZE
            
            for row in range(GRID_SIZE):
                for col in range(GRID_SIZE):
                    # Crop cell
                    left = col * actual_cell_w
                    top = row * actual_cell_h
                    right = left + actual_cell_w
                    bottom = top + actual_cell_h
                    
                    cell = master_img.crop((left, top, right, bottom))
                    
                    # 1. Remove background
                    cell = remove_background(cell)
                    
                    # 2. Crop to content bounding box
                    bbox = cell.getbbox()
                    if bbox:
                        cell = cell.crop(bbox)
                    
                    # 3. Resize to target cursor size
                    # Use high-quality Lanczos resampling
                    cell = cell.resize(CURSOR_SIZE, Image.Resampling.LANCZOS)
                    
                    # 4. Save
                    save_path = os.path.join(OUTPUT_DIR, f"cursor_{icon_count:02d}.png")
                    cell.save(save_path, "PNG")
                    icon_count += 1
                    
        print(f"Saved {icon_count - 1} icons to {OUTPUT_DIR}")

if __name__ == "__main__":
    process_images()

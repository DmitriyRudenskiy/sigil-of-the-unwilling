import os
from pathlib import Path
from PIL import Image, ImageOps, ImageFilter
import numpy as np

def remove_background(img, color='white', threshold=20):
    """Removes background based on color."""
    img = img.convert("RGBA")
    data = np.array(img)
    
    if color == 'white':
        # Background is white (high values)
        # We look for pixels where all channels are > 255 - threshold
        mask = np.all(data[:, :, :3] > (255 - threshold), axis=-1)
    elif color == 'black':
        # Background is black (low values)
        mask = np.all(data[:, :, :3] < threshold, axis=-1)
    else:
        mask = np.zeros(data.shape[:2], dtype=bool)

    data[mask, 3] = 0
    return Image.fromarray(data)

def resize_and_save(img, path, size):
    """Resizes and saves image preserving aspect ratio, centering it in a square."""
    img = img.convert("RGBA")
    # Crop to content (bounding box of non-zero alpha)
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    
    # Create square background
    w, h = img.size
    square_size = max(w, h)
    res = Image.new("RGBA", (square_size, square_size), (0, 0, 0, 0))
    
    # Center original image
    offset_x = (square_size - w) // 2
    offset_y = (square_size - h) // 2
    res.paste(img, (offset_x, offset_y))
    
    # Resize to target
    res = res.resize((size, size), Image.Resampling.LANCZOS)
    res.save(path, "PNG")

def process_creatures(input_path, output_dir):
    """Processes img_00003.png (4x3 grid, white bg, captions)."""
    img = Image.open(input_path).convert("RGBA")
    w, h = img.size
    cols, rows = 4, 3
    cell_w, cell_h = w // cols, h // rows
    
    creatures = [
        "swordsmen", "archers", "cavalry", "mages",
        "guardians", "archmages", "champions", "knights",
        "goblins", "wolves", "trolls", "archmages_alt"
    ]
    
    contact = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    
    for r in range(rows):
        for c in range(cols):
            idx = r * cols + c
            if idx >= len(creatures): break
            
            # Crop cell
            left = c * cell_w
            top = r * cell_h
            right = left + cell_w
            bottom = top + cell_h
            cell = img.crop((left, top, right, bottom))
            
            # Remove bottom 15% (captions)
            caption_h = int(cell_h * 0.15)
            cell = cell.crop((0, 0, cell_w, cell_h - caption_h))
            
            # Remove white background
            cell = remove_background(cell, 'white', threshold=30)
            
            # Save sizes
            key = creatures[idx]
            resize_and_save(cell, Path(output_dir) / f"{key}.png", 128)
            resize_and_save(cell, Path(output_dir) / f"{key}_s.png", 48)
            
            # Add to contact sheet (small version for check)
            contact.paste(cell.resize((cell_w, cell_h)), (left, top))

    contact.save("assets/raw/_contact/creatures_contact.png")

def process_icons_4(input_path, output_dir):
    """Processes img_00004.png (4x4 grid, black bg, outer frame)."""
    img = Image.open(input_path).convert("RGBA")
    w, h = img.size
    
    # 8% inset to remove outer frame
    inset = int(min(w, h) * 0.08)
    img = img.crop((inset, inset, w - inset, h - inset))
    w, h = img.size
    
    cols, rows = 4, 4
    cell_w, cell_h = w // cols, h // rows
    
    icons = [
        "atk_sword", "helm", "battle_flag", "scout",
        "sword2", "alert", "help", "compass",
        "point", "horse", "horse2", "hand",
        "hourglass", "ship", "treasure", "army"
    ]
    
    contact = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    
    for r in range(rows):
        for c in range(cols):
            idx = r * cols + c
            if idx >= len(icons): break
            
            left = c * cell_w
            top = r * cell_h
            cell = img.crop((left, top, left + cell_w, top + cell_h))
            cell = remove_background(cell, 'black', threshold=40)
            
            key = icons[idx]
            resize_and_save(cell, Path(output_dir) / f"{key}.png", 48)
            resize_and_save(cell, Path(output_dir) / f"{key}_s.png", 24)
            
            contact.paste(cell.resize((cell_w, cell_h)), (left, top))
            
    contact.save("assets/raw/_contact/icons4_contact.png")

def process_icons_5(input_path, output_dir):
    """Processes img_00005.png (4x4 grid, black bg)."""
    img = Image.open(input_path).convert("RGBA")
    w, h = img.size
    
    cols, rows = 4, 4
    cell_w, cell_h = w // cols, h // rows
    
    icons = [
        "cursor", "hourglass2", "gold", "expand",
        "horse3", "horse4", "gold2", "fireball",
        "scroll", "arrow", "swords", "flag",
        "map", "naval", "hourglass3", "spell"
    ]
    
    contact = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    
    for r in range(rows):
        for c in range(cols):
            idx = r * cols + c
            if idx >= len(icons): break
            
            left = c * cell_w
            top = r * cell_h
            cell = img.crop((left, top, left + cell_w, top + cell_h))
            cell = remove_background(cell, 'black', threshold=40)
            
            key = icons[idx]
            resize_and_save(cell, Path(output_dir) / f"{key}.png", 48)
            resize_and_save(cell, Path(output_dir) / f"{key}_s.png", 24)
            
            contact.paste(cell.resize((cell_w, cell_h)), (left, top))
            
    contact.save("assets/raw/_contact/icons5_contact.png")

if __name__ == "__main__":
    os.makedirs("assets/units", exist_ok=True)
    os.makedirs("assets/ui/icons", exist_ok=True)
    os.makedirs("assets/raw/_contact", exist_ok=True)
    
    process_creatures("assets/raw/img_00003.png", "assets/units")
    process_icons_4("assets/raw/img_00004.png", "assets/ui/icons")
    process_icons_5("assets/raw/img_00005.png", "assets/ui/icons")
    print("Processing complete.")

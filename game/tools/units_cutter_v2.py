import os
from pathlib import Path
from PIL import Image, ImageOps, ImageFilter
import numpy as np

def remove_white_background(img):
    """
    Implements the BFS flood-fill white removal from the provided GDScript.
    Removes pixels where luminosity > 0.85 and (max-min) < 0.25.
    """
    img = img.convert("RGBA")
    data = np.array(img).astype(np.float32) / 255.0
    w, h = img.size
    
    # mask for 'white-ish' pixels
    # lum = (r+g+b)/3
    lum = np.mean(data[:, :, :3], axis=-1)
    # sat = max(r,g,b) - min(r,g,b)
    mx = np.max(data[:, :, :3], axis=-1)
    mn = np.min(data[:, :, :3], axis=-1)
    sat = mx - mn
    
    white_mask = (lum > 0.85) & (sat < 0.25)
    
    # BFS from borders
    final_mask = np.zeros((h, w), dtype=bool)
    stack = []
    
    # Borders
    for x in range(w):
        stack.append((0, x))
        stack.append((h-1, x))
    for y in range(h):
        stack.append((y, 0))
        stack.append((y, w-1))
        
    # We use a set for visited and a list for stack to avoid recursion limits
    visited = np.zeros((h, w), dtype=bool)
    
    while stack:
        y, x = stack.pop()
        if visited[y, x]:
            continue
        visited[y, x] = True
        
        if white_mask[y, x]:
            final_mask[y, x] = True
            # Neighbors
            if x > 0: stack.append((y, x-1))
            if x < w-1: stack.append((y, x+1))
            if y > 0: stack.append((y-1, x))
            if y < h-1: stack.append((y+1, x))
            
    # Apply mask to alpha channel
    data[final_mask, 3] = 0
    return Image.fromarray((data * 255).astype(np.uint8))

def resize_and_save(img, path, size):
    img = img.convert("RGBA")
    # Crop to content to ensure centering
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    
    w, h = img.size
    square_size = max(w, h)
    res = Image.new("RGBA", (square_size, square_size), (0, 0, 0, 0))
    res.paste(img, ((square_size - w) // 2, (square_size - h) // 2))
    res = res.resize((size, size), Image.Resampling.LANCZOS)
    res.save(path, "PNG")

def process_sheets():
    file_keys = {
        "img_00017.jpeg": ["pikeman","halberdier","lancer","alchemist","berserker","griffin","royal_griffin","pegasus","gargoyle","titan","dwarf","battle_dwarf"],
        "img_00015.jpeg": ["centaur","elf","grand_elf","druid","great_druid","unicorn","war_unicorn","treant","dryad","green_dragon","gold_dragon","black_dragon"],
        "img_00016.jpeg": ["skeleton","zombie","ghost","wraith","vampire","lich","orc","ogre","behemoth","harpy","minotaur","hydra"],
        "img_00014.jpeg": ["gremlin","master_gremlin","stone_golem","iron_golem","gold_golem","diamond_golem","magus","genie","master_genie","naga","naga_queen","giant"],
        "img_00013.jpeg": ["gnoll","gnoll_marauder","lizardman","lizard_warrior","serpent_fly","dragon_fly","basilisk","greater_basilisk","wyvern","wyvern_monarch","gorgon","mighty_gorgon"],
        "img_00012.jpeg": ["hobgoblin","wolf_rider","wolf_raider","orc_chieftain","ogre_mage","roc","thunderbird","cyclops","cyclops_king","air_elemental","fire_elemental","water_elemental"],
        "img_00011.jpeg": ["earth_elemental","storm_elemental","ice_elemental","magma_elemental","phoenix","firebird","troglodyte","beholder","medusa","manticore","red_dragon","rust_dragon"],
    }
    
    out_dir = Path("assets/units")
    out_dir.mkdir(parents=True, exist_ok=True)
    
    for fname, keys in file_keys.items():
        fpath = Path("assets/raw") / fname
        if not fpath.exists():
            print(f"MISSING: {fname}")
            continue
        
        img = Image.open(fpath).convert("RGBA")
        w, h = img.size
        cw, ch = w // 4, h // 3
        
        for i, key in enumerate(keys):
            rx, ry = i % 4, i // 4
            # Crop cell
            cell = img.crop((rx * cw, ry * ch, (rx+1) * cw, (ry+1) * ch))
            
            # Remove labels (bottom 14%)
            cut_h = int(ch * 0.86)
            cell = cell.crop((0, 0, cw, cut_h))
            
            # Remove white background
            cell = remove_white_background(cell)
            
            # Save sizes
            resize_and_save(cell, out_dir / f"{key}.png", 128)
            resize_and_save(cell, out_dir / f"{key}_s.png", 48)
            
    print("=== units cutter done ===")

if __name__ == "__main__":
    process_sheets()

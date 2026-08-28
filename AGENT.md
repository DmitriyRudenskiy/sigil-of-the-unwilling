# Agent Documentation

## Project Tools and Solutions

### Image Processing & Sprite Generation

- **Combining Images into a Sprite (Grid):**
  Use `tools/make_grid.py`. This script collects images from a directory and combines them into a 4x4 grid (1024x1024 resolution).
  - If there are more than 16 images, it automatically creates multiple sprite sheets (e.g., `grid_2.png`, `grid_3.png`).
  - Missing cells are filled with a green chroma key (`#00FF00`).
  - Preserves aspect ratio and centers images in cells.
  - Supports `.png`, `.jpg`, `.jpeg`, `.webp`, `.bmp`, `.gif`, `.tiff`.
  
  **Usage:**
  ```bash
  python3 tools/make_grid.py "/path/to/your/images" -o "output_sprite.png" --bg "black"
  ```

- **Asset Slicing & Resizing:**
  Use `tools/asset_slicer.py`. This tool is used for processing specific sets of images (e.g., creatures, icons) by removing backgrounds and resizing them to specific dimensions (128x128, 48x48, 24x24).

- **Tileset Building:**
  Use `tools/tileset_builder.gd` (Godot script). Used for generating complex tilesets for hex biomes. It handles:
  - Scanning biome folders (`base` and `objects`).
  - Synthesizing missing background textures.
  - Calculating terrain colors and edge peering.
  - Generating `hex_atlas_base.png`, `hex_atlas_objects.png`, and `hex_tileset.tres`.

  **Usage:**
  ```bash
  godot --path . --headless -s tools/tileset_builder.gd
  ```

## Documentation

- **Overview**: `DOCS/OVERVIEW.md`
- **Architecture**: `DOCS/ARCHITECTURE.md`
- **Biome System**: `DOCS/BIOME_SYSTEM.md`
- **Tools Catalog**: `DOCS/TOOLS.md`
- **Knowledge Graph**: `DOCS/GRAPH_KNOWLEDGE.md`
- **Task Roadmap**: `DOCS/TASK.md`

# Biome & Texture System

This document describes the logic for handling world textures, biomes, and the automated pipeline for generating tilesets.

## Core Concept: Base vs. Objects
The project distinguishes between two types of textures for every biome to allow for dynamic environment generation:
1. **Base**: The underlying ground texture (e.g., grass, water, sand).
2. **Objects**: Decoration, props, and landmarks that sit *on top* of the base (e.g., rocks, trees, ruins).

This distinction allows the engine to:
- Layer objects over bases dynamically.
- Maintain visual consistency by ensuring objects are only placed in biomes where they are "compatible."
- Efficiently manage memory by reusing base textures while varying object placement.

## Biome Clustering & Classification
Textures are classified into biomes using a color-clustering approach.
- **Input**: Raw textures from `assets/raw`.
- **Process**: A color analysis script identifies dominant colors and clusters similar textures together.
- **Output**: Textures are automatically moved to `data/processed/{biome}/`.
- **Visual Weight**: The system analyzes "warm/rough" vs. "cool/smooth" textures to establish contrast guidelines (e.g., Swamp vs. Water).

## Hexagonal Tiling Logic
The project utilizes a hexagonal grid. To ensure textures tile correctly without artifacts:
- **Corner Cropping**: A specific mask is applied to all textures to remove the 4 corner triangles that would otherwise overlap or create "seams" on a hexagon.
- **Atlas Generation**: The `tileset_builder.gd` script combines all base and object textures into two primary atlases: `hex_atlas_base.png` and `hex_atlas_objects.png`.

## Automation Pipeline
The following automated steps are used to prepare assets:
1. **Resizing**: All primary assets are standardized to **512x512** using the `LANCZOS` algorithm for high-quality downsampling.
2. **Classification**: `organize_assets.py` sorts images into biome folders based on color.
3. **Masking**: A hexagon-cropping mask is applied to all processed textures.
4. **Atlas Building**: `tileset_builder.gd` generates the final `.tres` resources used by Godot.

## Biome Registry
The `data/ResourceRegistry.gd` serves as the "Source of Truth" for biome properties, including:
- Color palettes.
- Object density.
- Transition weights (how easily one biome blends into another).

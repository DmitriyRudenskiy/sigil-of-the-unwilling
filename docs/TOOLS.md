# Development Tools

This document lists the scripts and tools available in the project for asset processing, analysis, and development.

## Python Scripts

| Script | Location | Description |
|---|---|---|
| `scripts/tools/make_grid.py` | `scripts/tools/` | Creates sprite sheets by arranging images into a grid. |
| `process_assets.py` | (tools/) | Primary pipeline script for resizing, masking, and moving assets to `data/processed`. |
| `organize_assets.py` | (tools/) | Performs color-based clustering to sort raw textures into biome folders. |
| `analyze_texture_pairs.py` | `tools/` | Compares two textures to determine visual weight, color harmony, and transition quality. |
| `generate_map_preview.py` | (tools/) | Generates a procedural map visualization to validate biome distribution and distribution logic. |
| `biome_showcase.py` | (tools/) | Generates a visual "daidgest" (showcase) of all processed biomes and their combinations. |

## Godot Tools (GDScript)

| Tool | Location | Description |
|---|---|---|
| `tileset_builder.gd` | `tools/` | The main tool for generating Godot `.tres` tileset resources from processed base and object textures. |
| `BiomeClusterer.gd` | `tools/texture_slicer/` | Logic for grouping textures into biome clusters based on color similarity. |
| `PreviewRenderer.gd` | `tools/texture_slicer/` | Renders previews of biome transitions and cluster distributions. |
| `ResourceRegistry.gd` | `data/` | A global registry for biome constants, compatibility rules, and global game data. |

## Knowledge Graph (Graphify)
The project utilizes **Graphify** to map relationships between game entities:
- **Purpose**: To query complex dependencies (e.g., "Which resources are required for this spell?") without hard-coding paths.
- **Workflow**: Run `/graphify .` to map the codebase and docs into a queryable JSON graph.
- **Usage**: Use `graphify query` and `graphify path` to explore connections between systems, assets, and documentation.

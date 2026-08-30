# Project Overview: Sigil of the Unwilling

## Description
A large-scale world-building and procedural generation project focused on creating visually consistent and logically structured environments. The project emphasizes an automated asset pipeline, where raw textures are processed into biome-specific tilesets using automated color clustering and geometry adjustments.

## Core Objectives
- **Visual Consistency**: Ensuring seamless transitions between diverse biomes (e.g., Swamp, Water, Mountains) through color palette guidelines and visual weight balancing.
- **Scalable Architecture**: Utilizing a "Feature-based" project structure to allow for modular expansion of game systems (Spells, Resources, UI).
- **Automated Asset Pipeline**: Moving from raw image folders to production-ready sprite sheets and hexagonal tilesets with minimal manual intervention.
- **Knowledge-Driven Design**: Using Knowledge Graphs (via Graphify) to map relationships between game objects, resources, and environmental constraints.

## Technology Stack
- **Engine**: Godot 4.7
- **Language**: GDScript (Game Logic), Python (Tooling & Asset Processing)
- **AI & Analysis**: Gemma 4 Vision (Image analysis), Graphify (Knowledge Graph), PIL/NumPy (Image processing)
- **Data Management**: JSON-based registries, ResourceRegistry.gd, and automated folder structures.

## Key Features
- **Biome Clustering**: Automated classification of textures into biomes based on color analysis.
- **Hexagonal Tiling**: Custom texture cropping and mask application for hexagonal grid compatibility.
- **Resource Registry**: A centralized system for managing biome compatibility and global game constants.
- **Procedural Map Visualization**: Tools for generating and previewing biome distribution before final production.

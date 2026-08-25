# Testing Guide

## Headless Testing
To verify scenes and logic without a GPU/Window, use the Godot `--headless` mode.

### Automatic Termination
By default, Godot scenes in headless mode run in an infinite loop. To perform a "smoke test" that exits after initialization:
1. Ensure the scene's controller script (e.g., `WorldController.gd`) handles the `--autoquit` argument.
2. Run the following command:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --scene <path_to_scene> --autoquit
```

### Expected Result
The process should print the "Scene ready" message and exit automatically after 1 second.

## Stage Verification
- **Stage 0**: Run `tools/run_normalizer.gd`
- **Stage 1**: Run `tools/run_tileset_builder_v2.gd`
- **Stage 2**: Run `scenes/World.tscn` with `--autoquit`

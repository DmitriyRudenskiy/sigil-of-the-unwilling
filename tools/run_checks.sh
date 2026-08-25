#!/usr/bin/env bash
set -e

echo "=== Compile ==="
godot --headless -s tools/compile_all.gd

echo "=== Scene refs ==="
godot --headless -s tools/check_scene_refs.gd

echo "=== HexUtils tests ==="
godot --headless -s tests/test_hex_utils.gd

echo "=== UnitRegistry tests ==="
godot --headless -s tests/test_unit_registry.gd

echo "=== MapModel tests ==="
godot --headless -s tests/test_map_model.gd

echo "=== BattleState tests ==="
godot --headless -s tests/test_battle_state.gd

echo "=== BattleAI tests ==="
godot --headless -s tests/test_battle_ai.gd

echo "=== Battle integration tests ==="
godot --headless -s tests/test_battle_integration.gd

echo "=== World smoke test ==="
godot --headless res://scenes/World.tscn --autoquit

echo "=== ALL CHECKS PASSED ==="

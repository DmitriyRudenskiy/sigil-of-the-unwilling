#!/usr/bin/env bash
# Облегчённая проверка: compile + scene-refs + подборка тестов + world smoke.
# Запускать из корня репозитория: ./tools/run_checks.sh
set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT_BIN:-godot}"

cd "$REPO_DIR"

echo "=== Compile ==="
"$GODOT" --headless --path game -s tools/compile_all.gd

echo "=== Scene refs ==="
"$GODOT" --headless --path game -s tools/check_scene_refs.gd

echo "=== HexUtils tests ==="
"$GODOT" --headless --path game -s tests/test_hex_utils.gd

echo "=== UnitRegistry tests ==="
"$GODOT" --headless --path game -s tests/test_unit_registry.gd

echo "=== MapModel tests ==="
"$GODOT" --headless --path game -s tests/test_map_model.gd

echo "=== BattleState tests ==="
"$GODOT" --headless --path game -s tests/test_battle_state.gd

echo "=== BattleAI tests ==="
"$GODOT" --headless --path game -s tests/test_battle_ai.gd

echo "=== Battle integration tests ==="
"$GODOT" --headless --path game -s tests/test_battle_integration.gd

echo "=== World smoke test ==="
"$GODOT" --headless --path game --scene scenes/World.tscn --autoquit

echo "=== ALL CHECKS PASSED ==="

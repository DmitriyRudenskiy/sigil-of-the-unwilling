#!/bin/bash
# Ритуал статического анализа. Запуск: bash tools/lint.sh
set -uo pipefail
GODOT=${GODOT:-"/Applications/Godot.app/Contents/MacOS/Godot"}
FAIL=0

run_check() {
  echo ""
  echo "=== $1 ==="
  shift
  "$@" || FAIL=1
}

run_check "[1/4] Компиляция всех .gd" $GODOT --headless -s tools/compile_all.gd
run_check "[2/4] Ссылки в сценах" $GODOT --headless -s tools/check_scene_refs.gd

echo ""
echo "=== [3/4] Grep-lint (регрессии прошлых багов) ==="
if grep -rn "emit_signal(" --include="*.gd" scripts scenes 2>/dev/null; then
  echo "❌ legacy emit_signal"; FAIL=1
fi
if grep -rn "set_point_weight_segment" --include="*.gd" scripts 2>/dev/null; then
  echo "❌ nonexistent AStar2D method"; FAIL=1
fi
if grep -rn "\.distance_to(" --include="*.gd" scripts/battle 2>/dev/null; then
  echo "❌ distance_to вместо HexUtils.distance"; FAIL=1
fi
if grep -rn ":= queue\[" --include="*.gd" scripts 2>/dev/null; then
  echo "❌ inference из нетипизированного массива"; FAIL=1
fi

echo ""
if [ $FAIL -eq 0 ]; then
  echo "✅ ALL CHECKS PASSED"
else
  echo "❌ CHECKS FAILED"
  exit 1
fi

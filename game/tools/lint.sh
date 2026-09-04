#!/usr/bin/env bash
# Быстрый СТАТИЧЕСКИЙ линтер: компиляция + ссылки в сценах + grep-регрессии.
# Запуск: bash tools/lint.sh   (или ./tools/lint.sh)
#
#   --runtime   дополнительно прогнать headless-рантайм (World.tscn, авто-стоп)
#
# Зависимости: godot 4.x (GODOT_BIN) или стандартный путь к .app.

set -uo pipefail

GODOT="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"     # корень репозитория (game/tools/ -> ../..)
PROJ="$REPO_DIR/game"                                # корень Godot-проекта
FAIL=0

run_check() {
    local name="$1"; shift
    echo ""
    echo "=== $1 ==="
    if "$@"; then
        echo "  ✅ ok"
    else
        echo "  ❌ FAIL"; FAIL=1
    fi
}

# ---------- 1. Компиляция всех .gd (dev-tooling-rebuild: GUT-инвариант) ----------
run_check "[1/4] Compile all .gd (GUT test_compile_all)" \
    "$GODOT" --headless --path "$PROJ" -s addons/gut/gut_cmdln.gd -gtest=res://tests/functional/test_compile_all.gd -gexit

# ---------- 2. Ссылки в сценах (dev-tooling-rebuild: GUT-инвариант) ----------
run_check "[2/4] Scene refs (GUT test_scene_refs)" \
    "$GODOT" --headless --path "$PROJ" -s addons/gut/gut_cmdln.gd -gtest=res://tests/functional/test_scene_refs.gd -gexit

# ---------- 3. Grep-регрессии (ловим старые баги) ----------
echo ""
echo "=== [3/4] Grep-lint (регрессии) ==="
grep_fail() {
    local desc="$1"; shift
    if grep -rn "$@" "$REPO_DIR/game" 2>/dev/null; then
        echo "  ❌ $desc"; FAIL=1
    else
        echo "  ✅ ok"
    fi
}
grep_fail "nonexistent AStar2D method" --include="*.gd" -e "set_point_weight_segment"
# NOTE: Vector2.distance_to легитимен в pixel-space (BattleInput CLICK_RADIUS_PX,
# PlaceholderTexture) — не гребём его, иначе будет много фейлов. Проверку на
# HexUtils делаем только в файлах, работающих с гекс-координатами.
grep_fail "nonexistent AStar2D method" --include="*.gd" -e "set_point_weight_segment"
grep_fail "inference из нетипизированного массива" --include="*.gd" -e ":= queue["

# ---------- 4. (опционально) Headless-рантайм ----------
if [ "${1:-}" = "--runtime" ]; then
    run_check "[4/4] Runtime smoke (World.tscn)" \
        "$GODOT" --headless --path "$PROJ" --scene scenes/World.tscn --autoquit
else
    echo ""
    echo "=== [4/4] Runtime: пропущено (добавьте --runtime для World.tscn) ==="
fi

echo ""
if [ $FAIL -eq 0 ]; then
    echo "✅ ALL STATIC CHECKS PASSED"
else
    echo "❌ CHECKS FAILED"
    exit 1
fi

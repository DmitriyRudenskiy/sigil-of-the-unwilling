#!/usr/bin/env bash
# CI pipeline: последовательный запуск всех headless-проверок.
# Любая ошибка валит пайплайн (set -e).
#
# Использование:
#   tools/shell/run_all_ci_checks.sh           # все проверки
#   tools/shell/run_all_ci_checks.sh --fast    # только компиляция + валидация (без тестов)
#   tools/shell/run_all_ci_checks.sh --tests   # только тесты
#
# Зависимости: godot 4.x в PATH

set -euo pipefail

# Разрешение Godot: GODOT_BIN → godot в PATH → macOS-приложение.
if [ -n "${GODOT_BIN:-}" ]; then
    GODOT="$GODOT_BIN"
elif command -v godot >/dev/null 2>&1; then
    GODOT="godot"
elif [ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]; then
    GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
else
    echo "ERROR: Godot не найден. Поставьте GODOT_BIN=/path/to/godot" >&2
    exit 1
fi

REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"   # корень репозитория
PROJECT_DIR="$REPO_DIR/game"                       # корень Godot-проекта
EXIT_CODE=0
STEPS=0
PASSED=0
FAILED=0

_step() {
    STEPS=$((STEPS + 1))
    echo ""
    echo "========================================"
    echo "  [$STEPS] $1"
    echo "========================================"
}

_pass() {
    PASSED=$((PASSED + 1))
    echo "  ✅ PASS  ($1)"
}

_fail() {
    FAILED=$((FAILED + 1))
    EXIT_CODE=1
    echo "  ❌ FAIL  ($1)"
}

# ---------- 1. Компиляция всех скриптов ----------
_step "Compile check (compile_all.gd)"
if "$GODOT" --headless --path "$PROJECT_DIR" -s "$REPO_DIR/game/tools/compile_all.gd" 2>&1; then
    _pass "compile_all"
else
    _fail "compile_all"
fi

# ---------- 2. Проверка ссылок в сценах ----------
_step "Scene refs check (check_scene_refs.gd)"
if "$GODOT" --headless --path "$PROJECT_DIR" -s "$REPO_DIR/game/tools/check_scene_refs.gd" 2>&1; then
    _pass "check_scene_refs"
else
    _fail "check_scene_refs"
fi

# ---------- 3. Валидация данных ----------
_step "Spell validation"
if "$GODOT" --headless --path "$PROJECT_DIR" \
    -s "$REPO_DIR/game/tools/spell_validation/validate_spells.gd" --strict --json 2>&1; then
    _pass "spell_validation"
else
    _fail "spell_validation"
fi

# ---------- 4. Проверка тайлсетов ----------
_step "Tileset integrity (check_tileset.gd)"
if "$GODOT" --headless --path "$PROJECT_DIR" -s "$REPO_DIR/game/tools/check_tileset.gd" 2>&1; then
    _pass "check_tileset"
else
    _fail "check_tileset"
fi

# ---------- 5. Юнит-тесты (если не --fast) ----------
if [ "${1:-}" != "--fast" ]; then
    _step "Unit tests (run_tests.gd)"
    if "$GODOT" --headless --path "$PROJECT_DIR" -s "$REPO_DIR/game/tests/run_tests.gd" 2>&1; then
        _pass "unit_tests"
    else
        _fail "unit_tests"
    fi
fi

# ---------- Итог ----------
echo ""
echo "========================================"
echo "  CI SUMMARY: $PASSED passed, $FAILED failed (of $STEPS steps)"
echo "========================================"
exit $EXIT_CODE

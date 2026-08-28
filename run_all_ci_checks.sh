#!/usr/bin/env bash
# CI pipeline: последовательный запуск всех headless-проверок.
# Любая ошибка валит пайплайн (set -e).
#
# Использование:
#   ./run_all_ci_checks.sh           # все проверки
#   ./run_all_ci_checks.sh --fast    # только компиляция + валидация (без тестов)
#   ./run_all_ci_checks.sh --tests   # только тесты
#
# Зависимости: godot 4.x в PATH

set -euo pipefail

GODOT="${GODOT_BIN:-godot}"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
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
if "$GODOT" --headless --path "$PROJECT_DIR" -s tools/compile_all.gd 2>&1; then
    _pass "compile_all"
else
    _fail "compile_all"
fi

# ---------- 2. Проверка ссылок в сценах ----------
_step "Scene refs check (check_scene_refs.gd)"
if "$GODOT" --headless --path "$PROJECT_DIR" -s tools/check_scene_refs.gd 2>&1; then
    _pass "check_scene_refs"
else
    _fail "check_scene_refs"
fi

# ---------- 3. Валидация данных ----------
_step "Card spells validation"
if "$GODOT" --headless --path "$PROJECT_DIR" \
    -s tools/card_validation/validate_card_spells.gd --strict --json 2>&1; then
    _pass "card_validation"
else
    _fail "card_validation"
fi

# ---------- 4. Проверка тайлсетов ----------
_step "Tileset integrity (check_tileset.gd)"
if "$GODOT" --headless --path "$PROJECT_DIR" -s tools/check_tileset.gd 2>&1; then
    _pass "check_tileset"
else
    _fail "check_tileset"
fi

# ---------- 5. Юнит-тесты (если не --fast) ----------
if [ "${1:-}" != "--fast" ]; then
    _step "Unit tests (run_tests.gd)"
    if "$GODOT" --headless --path "$PROJECT_DIR" -s tests/run_tests.gd 2>&1; then
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

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

set -uo pipefail

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

# Корни вычисляем от расположения самого скрипта (game/tools/shell/),
# а не от текущей директории — иначе при запуске из game/ получается game/game/….
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"      # корень Godot-проекта (game/)
REPO_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"      # корень репозитория

# Запуск godot -s <script> с определением провала по ЛОГУ, а не по коду выхода.
# Godot возвращает 0 даже когда скрипт не загрузился (Can't load script), поэтому
# проверяем маркеры ошибок в выводе. $@ — аргументы к godot после --path.
_godot_script() {
    local desc="$1"; shift
    local out; out="$(mktemp)"
    "$GODOT" --headless --path "$PROJECT_DIR" "$@" >"$out" 2>&1
    # Маркеры — только с префиксами Godot (SCRIPT ERROR:, Failed to load script) и
    # собственные отчёты тулов (RESULT: FAILED / SOME TESTS FAILED). Избегаем
    # «Parse error»/«File not found» — их приложение логирует само (напр. SaveManager).
    if grep -qiE "SCRIPT ERROR|Failed to load script|Can't load script|Could not find type|does not inherit from|Nonexistent function|SOME TESTS FAILED|RESULT: FAILED" "$out"; then
        _fail "$desc"
        echo "  --- последние строки вывода ---"
        tail -n 25 "$out" | sed 's/^/    /'
    else
        _pass "$desc"
    fi
    rm -f "$out"
}
# ---------- 0. Автозагрузка реестра class_name ----------
# Проверкам (-s) нужны глобальные class_name (BattleState, Spellbook, ...). В
# headless -s/импорте Godot реестр НЕ пишет — его строит только редактор.
# Если кэша нет (чистый checkout / удалён .godot) — прогоняем редактор один
# раз, он импортирует ассеты и запишет global_script_class_cache.cfg.
_REGISTRY="$PROJECT_DIR/.godot/global_script_class_cache.cfg"
# Запуск с таймаутом (на macOS нет утилиты timeout): фоновый запуск + kill -9.
_run_with_timeout() {
    local secs="$1"; shift
    "$@" >/tmp/_ci_boot.log 2>&1 &
    local pid=$!
    ( sleep "$secs"; kill -9 "$pid" 2>/dev/null ) &
    local killer=$!
    wait "$pid"
    local rc=$?
    kill -9 "$killer" 2>/dev/null
    return $rc
}
_bootstrap_registry() {
    if [ -s "$_REGISTRY" ]; then
        echo "  реестр class_name уже есть: $(wc -l < "$_REGISTRY") строк"
        return 0
    fi
    echo "  реестра нет — строим редактором (godot --editor)..."
    # Реестр записывается ещё до загрузки UI-макета редактора, поэтому 240с — с запасом.
    if _run_with_timeout 240 "$GODOT" --headless --path "$PROJECT_DIR" --editor; then
        echo "  реестр собран: $(wc -l < "$_REGISTRY") строк"
        return 0
    fi
    if [ ! -s "$_REGISTRY" ]; then
        echo "  ❌ редактор не собрал реестр" >&2
        tail -n 20 /tmp/_ci_boot.log | sed 's/^/    /' >&2
        return 1
    fi
    echo "  реестр собран (импорт прёрван по таймауту, но кэш записан): $(wc -l < "$_REGISTRY") строк"
    return 0
}

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

# ---------- 0. (выполняется всегда) автозагрузка реестра ----------
if ! _bootstrap_registry; then
    echo "  Прервано: нельзя проверить проекты без реестра class_name." >&2
    exit 1
fi

# ---------- 1. Компиляция всех скриптов ----------
_step "Compile check (compile_all.gd)"
_godot_script "compile_all" -s "$PROJECT_DIR/tools/compile_all.gd"

# ---------- 2. Проверка ссылок в сценах ----------
_step "Scene refs check (check_scene_refs.gd)"
_godot_script "check_scene_refs" -s "$PROJECT_DIR/tools/check_scene_refs.gd"

# ---------- 3. Валидация данных ----------
_step "Spell validation"
_godot_script "spell_validation" -s "$PROJECT_DIR/tools/spell_validation/validate_spells.gd" --strict --json

# ---------- 4. Проверка тайлкетов ----------
_step "Tileset integrity (check_tileset.gd)"
_godot_script "check_tileset" -s "$PROJECT_DIR/tools/check_tileset.gd"

# ---------- 5. Юнит-тесты (если не --fast) ----------
if [ "${1:-}" != "--fast" ]; then
    _step "Unit tests (run_tests.gd)"
    _godot_script "unit_tests" -s "$PROJECT_DIR/tests/run_tests.gd"
fi

# ---------- Итог ----------
echo ""
echo "========================================"
echo "  CI SUMMARY: $PASSED passed, $FAILED failed (of $STEPS steps)"
echo "========================================"
exit $EXIT_CODE

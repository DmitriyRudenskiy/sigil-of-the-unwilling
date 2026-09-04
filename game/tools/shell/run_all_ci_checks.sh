#!/usr/bin/env bash
# CI pipeline: последовательный запуск всех headless-проверок.
# Любая ошибка валит пайплайн (set -e).
#
# Использование:
#   tools/shell/run_all_ci_checks.sh           # все проверки (GUT + console clean)
#   tools/shell/run_all_ci_checks.sh --fast    # только GUT (инварианты без console clean)
#   tools/shell/run_all_ci_checks.sh --tests   # только GUT (без console clean)
#
## Инварианты (компиляция, scene refs, тайлкет, валидация спеллов, бот scenes,
## бенчи, memory, unit registry) теперь живут как GUT-тесты в res://tests/
## functional/ — один шаг «Unit tests (GUT)» их все покрывает. Старые
## godot -s tools/*.gd шаги удалены (см. dev-tooling-rebuild).
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

# Директория захвата логов + шаблоны скана для итогового гейта «конец цикла» (AGENT.md 8.2).
# Исключаем «Parse error»/«File not found» — их приложение логирует само (напр. SaveManager):
# это ложные срабатывания, а не реальные ошибки (см. _godot_script). Строки app-логгера
# ([color=]) исключаются при скане — это намеренные логи, не регрессия кода.
CI_LOG_DIR="${CI_LOG_DIR:-/tmp/ci_logs}"
CI_ERROR_RE='SCRIPT ERROR|Failed to load script|Can'"'"'t load script|Could not find type|does not inherit from|Nonexistent function|Nonexistent class|Nonexistent base|SOME TESTS FAILED|RESULT: FAILED'
CI_WARN_RE='^WARNING|^NOTICE|leaked|LEAK|deprecated|^W [0-9]'
rm -f "$CI_LOG_DIR"/*.log 2>/dev/null
mkdir -p "$CI_LOG_DIR"

# Запуск godot -s <script> с определением провала по ЛОГУ, а не по коду выхода.
# Godot возвращает 0 даже когда скрипт не загрузился (Can't load script), поэтому
# проверяем маркеры ошибок в выводе. $@ — аргументы к godot после --path.
_godot_script() {
    local desc="$1"; shift
    local out; out="$CI_LOG_DIR/$desc.log"
    mkdir -p "$CI_LOG_DIR"
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

# ---------- 1. Юнит-тесты (GUT) — покрывает все инварианты (dev-tooling-rebuild) ----------
# compile_all / scene_refs / tileset / spell_validation / scene_boot / benchmarks /
# memory / unit_report теперь живут как GUT-тесты в res://tests/functional/.
_step "Unit tests (GUT)"
_godot_script "unit_tests" -s "$PROJECT_DIR/addons/gut/gut_cmdln.gd" -gdir=res://tests -ginclude_subdirs -gexit
# Скан выше не видит падение ассертов (GUT печатает "[Failed]:") — гейтим
# на маркере успеха (печатается только при failing==0 && risky==0).
if ! grep -q "All tests passed!" "$CI_LOG_DIR/unit_tests.log"; then
    _fail "unit_tests"
    echo "  GUT: 'All tests passed!' не найдено — см. $CI_LOG_DIR/unit_tests.log"
    tail -n 25 "$CI_LOG_DIR/unit_tests.log" | sed 's/^/    /'
fi

# ---------- 2. Console clean (живые сценарии 1–5) ----------
# Прогон 5 сценариев через play_scenario.sh + скан логов: любой error-маркер
# валит шаг; warning валит, только если не в docs/CONSOLE_ALLOWLIST.md.
# Длительный шаг (~3–5 мин) — --fast его пропускает.
if [ "${1:-}" != "--fast" ]; then
    _step "Console clean (scenarios 1-5)"
    if (
        cd "$PROJECT_DIR"
        LOG_DIR="$CI_LOG_DIR" GODOT_BIN="$GODOT" bash tools/shell/check_console_clean.sh
    ); then
        _pass "console_clean"
    else
        _fail "console_clean"
    fi
fi

# ---------- Итог: скан логов (гейт «конец цикла», AGENT.md 8.2) ----------
# Печатает ⚠️ WARNINGS / ❌ ERRORS по всем захваченным логам. В --fast — пропускается
# (guard — не меняем вывод --fast). Выходит с ненулевым кодом при ошибках.
if [ "${1:-}" != "--fast" ]; then
    _step "Console scan (end-of-cycle gate)"
    if [ -d "$CI_LOG_DIR" ]; then
        total_errs=$(cat "$CI_LOG_DIR"/*.log 2>/dev/null | grep -vE '\[color=' | grep -ciE "$CI_ERROR_RE")
        total_warns=$(cat "$CI_LOG_DIR"/*.log 2>/dev/null | grep -vE '\[color=' | grep -ciE "$CI_WARN_RE")
        echo "  ⚠️  WARNINGS: $total_warns | ❌ ERRORS: $total_errs"
        [ "$total_errs" -gt 0 ] && EXIT_CODE=1
    fi
fi

# ---------- Итог ----------
echo ""
echo "========================================"
echo "  CI SUMMARY: $PASSED passed, $FAILED failed (of $STEPS steps)"
echo "========================================"
exit $EXIT_CODE

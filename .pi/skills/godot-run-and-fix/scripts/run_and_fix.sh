#!/usr/bin/env bash
# run_and_fix.sh — Запуск Godot-проекта в режиме отладки с захватом ошибок
#
# Usage:
#   bash run_and_fix.sh <project_path> [timeout] [extra_args...]
#
# Examples:
#   bash run_and_fix.sh /path/to/project
#   bash run_and_fix.sh /path/to/project 15 -- --headless -s tests/debug_load.gd
#
# Output:
#   stdout — полный вывод Godot
#   /tmp/godot_errors_<PID>.txt — только ошибки

set -uo pipefail

# --- Configuration ---
GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
PROJECT_PATH="$1"
TIMEOUT="${2:-30}"
# Убираем "--" из аргументов (разделитель bash)
EXTRA_ARGS="${@:3}"
EXTRA_ARGS=$(echo "$EXTRA_ARGS" | sed 's/^-- //')

# --- Validate ---
if [ ! -d "$PROJECT_PATH" ]; then
    echo "ERROR: Project directory not found: $PROJECT_PATH" >&2
    exit 1
fi

if ! [ -f "$GODOT_BIN" ]; then
    echo "ERROR: Godot binary not found at $GODOT_BIN" >&2
    echo "Set GODOT_BIN to override." >&2
    exit 1
fi

# --- Output files ---
ERROR_FILE="/tmp/godot_errors_$$.txt"
WARN_FILE="/tmp/godot_warnings_$$.txt"
FULL_LOG="/tmp/godot_full_$$.txt"
STDERR_LOG="/tmp/godot_stderr_$$.txt"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  Godot Run & Fix                                        ║"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║  Project : $PROJECT_PATH"
echo "║  Timeout : ${TIMEOUT}s"
echo "║  Godot   : $GODOT_BIN"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# --- Kill any existing headless Godot processes ---
pkill -f "Godot.*headless" 2>/dev/null || true
sleep 1

# --- Run Godot ---
echo "▶ Запуск Godot (PID $$)..."
# Создаём файлы логов заранее
touch "$FULL_LOG" "$STDERR_LOG"
# Godot в headless-режиме буферизует вывод. Используем script (macOS) для захвата.
# script пишет весь вывод терминала в файл
# Простой запуск с захватом stdout и stderr в файлы
# Godot пишет ошибки парсера в stderr, остальное — в stdout
"$GODOT_BIN" --path "$PROJECT_PATH" --headless $EXTRA_ARGS 2>"$STDERR_LOG" >>"$FULL_LOG" &
GODOT_PID=$!

# Ждём завершения или таймаута
# Godot в headless-режиме может держать процесс открытым (TCP-сервер и т.д.)
# Поэтому ждём таймаут и потом убиваем процесс
START=$(date +%s)
while kill -0 "$GODOT_PID" 2>/dev/null; do
    ELAPSED=$(( $(date +%s) - START ))
    if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
        echo ""
        echo "⏱ Таймаут ${TIMEOUT}s — завершение"
        kill "$GODOT_PID" 2>/dev/null || true
        break
    fi
    sleep 0.5
done

# Ждём завершения процесса
wait "$GODOT_PID" 2>/dev/null || true

# Небольшая задержка для сброса буферов
sleep 0.5

# Объединяем stdout + stderr в один лог
cat "$STDERR_LOG" >> "$FULL_LOG" 2>/dev/null || true

# --- Extract errors ---
# Охватывает: parse errors, runtime errors, missing methods, type mismatches
# Формат Godot: "E 0:00:0X:XXX  <message>" или "SCRIPT ERROR: <message>"
grep -iE "SCRIPT ERROR|Parse error|CRASH|FATAL|Cannot find|Nonexistent function|Trying to assign|Too many arguments|Cannot infer|Nonexistent class|Invalid call|Invalid get|Invalid set|Cannot convert|Attempt to call function|is not declared|is not a valid|Error running|assertion failed|E 0:" "$FULL_LOG" > "$ERROR_FILE" 2>/dev/null || true
ERROR_COUNT=$(wc -l < "$ERROR_FILE" | tr -d ' ')

# --- Extract warnings & notices ---
grep -iE "WARNING|NOTICE|WARN:|LEAK|leaked|still in use|deprecated|deprecate|ObjectDB.*leak|W 0:" "$FULL_LOG" > "$WARN_FILE" 2>/dev/null || true
WARN_COUNT=$(wc -l < "$WARN_FILE" | tr -d ' ')

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Результаты"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$ERROR_COUNT" -gt 0 ]; then
    echo " ❌ Ошибки: $ERROR_COUNT"
    echo ""
    echo "--- Ошибки ---"
    cat "$ERROR_FILE"
    echo "--- Конец ошибок ---"
else
    echo " ✅ Ошибок нет"
fi

if [ "$WARN_COUNT" -gt 0 ]; then
    echo ""
    echo " ⚠️  Предупреждения: $WARN_COUNT"
    echo ""
    echo "--- Предупреждения ---"
    cat "$WARN_FILE"
    echo "--- Конец предупреждений ---"
else
    echo " ⚠️  Предупреждений нет"
fi

echo ""
echo "📋 Полный лог:      $FULL_LOG"
echo "📋 Ошибки:          $ERROR_FILE"
echo "📋 Предупреждения:  $WARN_FILE"

# Cleanup old logs (keep last 5)
ls -t /tmp/godot_errors_*.txt 2>/dev/null | tail -n +6 | xargs rm -f 2>/dev/null || true
ls -t /tmp/godot_warnings_*.txt 2>/dev/null | tail -n +6 | xargs rm -f 2>/dev/null || true
ls -t /tmp/godot_full_*.txt 2>/dev/null | tail -n +6 | xargs rm -f 2>/dev/null || true
ls -t /tmp/godot_stderr_*.txt 2>/dev/null | tail -n +6 | xargs rm -f 2>/dev/null || true

# Exit with error count (warnings don't fail the build)
exit "$ERROR_COUNT"

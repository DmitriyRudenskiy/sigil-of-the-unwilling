#!/bin/bash
# play_scenario_1.sh — один запуск сценария «Collect All» без поиска файлов.
#
#   ./play_scenario_1.sh            # сценарий 1 (по умолчанию)
#   ./play_scenario_1.sh 2          # сценарий 2 (если протобой реализован)
#
# Делает всё сам: находит Godot -> стартует сервер (9095) -> ждёт сокета ->
# гоняет сценарий -> гашет сервер -> возвращает код сценария.

set -u

PORT=9095
SCENARIO="${1:-1}"
LOG="/tmp/godot_scenario.log"
HERE="$(cd "$(dirname "$0")" && pwd)"

# --- 1. Находим Godot (env -> стандартный путь -> поиск) ---
GODOT_BIN="${GODOT_BIN:-}"
if [ -z "$GODOT_BIN" ]; then
    for cand in \
        "/Applications/Godot.app/Contents/MacOS/Godot" \
        "/usr/local/bin/godot" \
        "/usr/bin/godot"; do
        [ -x "$cand" ] && GODOT_BIN="$cand" && break
    done
fi
if [ -z "$GODOT_BIN" ]; then
    found="$(command -v godot || true)"
    [ -n "$found" ] && GODOT_BIN="$found"
fi
if [ -z "$GODOT_BIN" ] || [ ! -x "$GODOT_BIN" ]; then
    echo "❌ Godot не найден. Установите Godot 4.x или задайте GODOT_BIN=..."
    exit 127
fi
echo "🚀 Godot: $GODOT_BIN"

# --- 2. Стартуем сервер (та же команда, что в run_scenarios.sh) ---
"$GODOT_BIN" --path "$HERE" --headless --scene scenes/MainMenu.tscn >"$LOG" 2>&1 &
GODOT_PID=$!

cleanup() {
    kill "$GODOT_PID" 2>/dev/null
    wait "$GODOT_PID" 2>/dev/null
}
trap cleanup EXIT

# --- 3. Ждём готовности сокета ---
echo "⏳ Ждём сервер на $PORT ..."
ready=0
for _ in $(seq 1 30); do
    if nc -z localhost "$PORT" 2>/dev/null; then ready=1; break; fi
    if ! kill -0 "$GODOT_PID" 2>/dev/null; then
        echo "❌ Сервер упал при старте. Лог:"; cat "$LOG"; exit 1
    fi
    sleep 1
done
[ "$ready" -eq 1 ] || { echo "❌ Сервер не поднялся за 30с. Лог:"; cat "$LOG"; exit 1; }
echo "✅ Сервер готов."

# --- 4. Гоняем сценарий ---
SC_FILE="tools/scenarios/scenario_${SCENARIO}_collect.py"
[ -f "$HERE/$SC_FILE" ] || SC_FILE="tools/scenarios/scenario_${SCENARIO}_flee.py"
echo "🏃 Сценарий: $SC_FILE"
( cd "$HERE" && python3 "tools/scenarios/scenario_${SCENARIO}_collect.py" \
   || python3 "tools/scenarios/scenario_${SCENARIO}_flee.py" )
RES=$?

cleanup
trap - EXIT
echo "🧹 Сервер остановлен."
exit $RES

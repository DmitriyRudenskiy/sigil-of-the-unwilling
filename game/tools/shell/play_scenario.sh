#!/usr/bin/env bash
# play_scenario.sh — запуск игрового сценария через живую игру (сокет-сервер).
#
#   ./tools/shell/play_scenario.sh [N]          # сценарий N (по умолчанию 1)
#
# Делает всё сам: Godot -> старт сервера (9095) -> ждёт сокета -> гоняет
# сценарий (scenario_${N}_collect.py, с фолбэком на *_flee.py) -> гашет сервер.
# Возвращает код сценария (0 = passed).
#
#   --log <file>   писать лог сервера в файл (по умолчанию /tmp/godot_scenario.log)

set -u

PORT=9095
SCENARIO="${1:-1}"
LOG="/tmp/godot_scenario.log"
# последний аргумент --log <file> меняет лог, всё остальное — номер сценария
if [ "${2:-}" = "--log" ]; then
    LOG="${3:-$LOG}"
    SCENARIO="${1:-1}"
fi
HERE="$(cd "$(dirname "$0")/../../.." && pwd)"   # корень репозитория (скрипт в game/tools/shell/)

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

# --- 2. Стартуем сервер ---
"$GODOT_BIN" --path "$HERE/game" --headless --test-server --scene scenes/MainMenu.tscn >"$LOG" 2>&1 &
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

# --- 4. Гоняем сценарий (collect/flee/explore/endure) ---
SC_DIR="$HERE/game/tools/scenarios"
if [ -f "$SC_DIR/scenario_${SCENARIO}_collect.py" ]; then
    SC_PY="scenario_${SCENARIO}_collect.py"
elif [ -f "$SC_DIR/scenario_${SCENARIO}_flee.py" ]; then
    SC_PY="scenario_${SCENARIO}_flee.py"
elif [ -f "$SC_DIR/scenario_${SCENARIO}_explore.py" ]; then
    SC_PY="scenario_${SCENARIO}_explore.py"
elif [ -f "$SC_DIR/scenario_${SCENARIO}_endure.py" ]; then
    SC_PY="scenario_${SCENARIO}_endure.py"
else
    echo "❌ Нет файла сценария scenario_${SCENARIO}_{collect,flee,explore,endure}.py"
    exit 2
fi
echo "🏃 Сценарий: game/tools/scenarios/$SC_PY"
( cd "$HERE" && python3 "game/tools/scenarios/$SC_PY" )
RES=$?

cleanup
trap - EXIT
echo "🧹 Сервер остановлен."
exit $RES

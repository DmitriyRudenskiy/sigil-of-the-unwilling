#!/bin/bash
# run_scenarios.sh — CI/CD оркестратор сценариев через живую игру.
#
# Прогоняет сценарии через сокет-сервер Godot (localhost:9095, action-based
# протокол: START_GAME / GET_STATE / MOVE_TO / COLLECT_HERE / END_TURN).
# Проще и надёжнее: ./play_scenario_1.sh (один запуск сценария 1).

GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
PORT=9095
HERE="$(cd "$(dirname "$0")" && pwd)"

echo "🚀 Starting Godot Test Server..."
"$GODOT_BIN" --path "$HERE" --headless --scene scenes/MainMenu.tscn > /tmp/godot_scenario.log 2>&1 &
GODOT_PID=$!

cleanup() {
    kill "$GODOT_PID" 2>/dev/null
    wait "$GODOT_PID" 2>/dev/null
}
trap cleanup EXIT

# Ждём готовности сокета
echo "⏳ Waiting for server to start..."
MAX_RETRIES=30
COUNT=0
while ! nc -z localhost "$PORT"; do
    sleep 1
    COUNT=$((COUNT+1))
    if [ $COUNT -ge $MAX_RETRIES ]; then
        echo "❌ Error: Godot server failed to start."
        cat /tmp/godot_scenario.log
        exit 1
    fi
done
echo "✅ Server is ready!"

# Сценарий 1: Collect All (работает в текущем протоколе).
echo "🏃 Running Scenario 1: Collect All..."
python3 "$HERE/tools/scenarios/scenario_1_collect.py"
S1_RES=$?

# Сценарий 2: Flee All — пока отложен: требует battle-команд (challenge /
# get_battle_state / battle_retreat), которых нет в сокет-протоколе.
echo "⏭️  Scenario 2 (Flee): skipped — needs battle protocol commands."
S2_RES=0

if [ $S1_RES -eq 0 ]; then
    echo "🎉 SCENARIO 1 PASSED!"
    exit 0
else
    echo "❌ Scenario 1 failed (exit $S1_RES)."
    exit 1
fi

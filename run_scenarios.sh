#!/bin/bash
# run_scenarios.sh - CI/CD Orchestrator for TASK_ADDENDUM_11

GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
PORT=9080

echo "🚀 Starting Godot Test Server..."
$GODOT_BIN --path "$(pwd)" --headless --test-server=$PORT &
GODOT_PID=$!

# Wait for server to be ready
echo "⏳ Waiting for server to start..."
MAX_RETRIES=20
COUNT=0
while ! nc -z localhost $PORT; do
    sleep 1
    COUNT=$((COUNT+1))
    if [ $COUNT -ge $MAX_RETRIES ]; then
        echo "❌ Error: Godot server failed to start."
        kill $GODOT_PID
        exit 1
    fi
done
echo "✅ Server is ready!"

# Run Scenario 1
echo "🏃 Running Scenario 1: Collect All..."
python3 tools/scenarios/scenario_1_collect.py
S1_RES=$?

# Run Scenario 2
echo "🏃 Running Scenario 2: Flee All..."
python3 tools/scenarios/scenario_2_flee.py
S2_RES=$?

# Cleanup
echo "🧹 Shutting down server..."
kill $GODOT_PID

if [ $S1_RES -eq 0 ] && [ $S2_RES -eq 0 ]; then
    echo "🎉 ALL SCENARIOS PASSED!"
    exit 0
else
    echo "❌ Some scenarios failed."
    exit 1
fi

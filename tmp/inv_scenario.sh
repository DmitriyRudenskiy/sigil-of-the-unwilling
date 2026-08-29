#!/usr/bin/env bash
# Автосценарий для инвентаря героя: перелистывание, назначение в слот, все комбинации.
# Запуск: bash tmp/inv_scenario.sh
# Выход 0 — всё ок, 1 — есть фейлы.
set -u
cd "$(dirname "$0")/.."

GODOT_BIN=""
for cand in "/Applications/Godot.app/Contents/MacOS/Godot" "/usr/local/bin/godot" "/usr/bin/godot"; do
  [ -x "$cand" ] && GODOT_BIN="$cand" && break
done
[ -z "$GODOT_BIN" ] && GODOT_BIN="$(command -v godot || true)"
if [ -z "$GODOT_BIN" ]; then echo "Godot not found"; exit 2; fi

# 1) Импортируем ресурсы (создаёт .import-файлы для новых инок артефактов).
"$GODOT_BIN" --headless --import > /tmp/godot_import.out 2>&1 &
IMP=$!
sleep 20
kill $IMP 2>/dev/null
wait $IMP 2>/dev/null

# 2) Запуск сценария.
"$GODOT_BIN" --headless -s tmp/inv_scenario.gd > /tmp/inv_scenario_out.log 2>&1 &
PID=$!
sleep 25
kill $PID 2>/dev/null
wait $PID 2>/dev/null

echo "=== INV SCENARIO OUTPUT ==="
cat /tmp/inv_scenario_out.log
echo "=== RESULT ==="
grep -E "RESULT" /tmp/inv_scenario_out.log

# Код выхода: 0 если 0 фейлов, иначе 1.
if grep -q "❌" /tmp/inv_scenario_out.log; then
  exit 1
else
  exit 0
fi

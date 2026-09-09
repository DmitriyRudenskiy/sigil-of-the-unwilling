#!/bin/bash
# Полный прогон тестов (заменяет ручные команды из TASK_11 §3.3/§6):
#   1. gdUnit4 — все GDScript-тесты, junit-отчёт в reports/junit.xml
#   2. MCP — pytest на официальном mcp SDK (живой Godot через godot-mcp)
#   3. Структурные проверки из критериев приёмки
# Запуск: bash tests/run_all.sh   (из game/ или из любого места)
set -e
cd "$(dirname "$0")/.."

GODOT="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
PY="${MCP_PY:-$PWD/addons/venv/bin/python}"
mkdir -p reports

echo "=== 1/3 gdUnit4 ==="
# Отчёт gdUnit4 — нативный XML: reports/report_*/results.xml (junit-флаг в 4.x отсутствует)
"$GODOT" --headless --path . -s addons/gdunit4/bin/GdUnitCmdTool.gd \
  --ignoreHeadlessMode -c -a res://tests
latest=$(ls -dt reports/report_* 2>/dev/null | head -1)
echo "XML-отчёт: $latest/results.xml"

echo "=== 2/3 MCP (pytest) ==="
node --version || { echo "НЕТ Node.js (нужен для godot-mcp)"; exit 1; }
[ -f addons/godot-mcp/build/index.js ] || { echo "НЕТ сервера godot-mcp: addons/godot-mcp/build/index.js"; exit 1; }
( cd tests/mcp && "$PY" -m pytest -q -rs )

echo "=== 3/3 структурные проверки ==="
if ls tests/Test*.gd >/dev/null 2>&1; then
  echo "ДУБЛИ ОСТАЛИСЬ (tests/Test*.gd)"; exit 1
fi
echo "OK: дублей в корне tests/ нет"

if grep -rn "mcp_client" tests/ --include="*.py" --include="*.gd" \
    | grep -v "^tests/mcp/godot_mcp.py:" >/dev/null 2>&1; then
  echo "САМОПИСНЫЙ КЛИЕНТ ОСТАЛСЯ (mcp_client)"; exit 1
fi
echo "OK: mcp_client удалён"

# Базовые static var (кэши/реестры/синглтон-указатели) зафиксированы в
# tests/static_var_baseline.txt; провал = появился новый (в т.ч. сессионный).
static_hits=$(grep -rn "static var" scripts/ --include="*.gd" \
  | grep -v "_cache\|_handlers\|_config" | grep -v -E ":[0-9]+:#" \
  | awk -F: '{name=$3; sub(/^static var /,"",name); sub(/[^A-Za-z_0-9].*/,"",name); print $1": "name}' | sort)
static_baseline=$(sort tests/static_var_baseline.txt)
if [ "$static_hits" != "$static_baseline" ]; then
  echo "STATIC VAR: базовый набор изменился (новый static var?):"
  diff <(echo "$static_baseline") <(echo "$static_hits") | sed 's/^/  /'
  echo "  (если это кэш — добавьте строку в tests/static_var_baseline.txt)"
  exit 1
fi
echo "OK: static var — только базовые кэши ($(echo "$static_baseline" | wc -l | tr -d ' '))"

if grep -n "get_node_or_null" scripts/ui/BattleUI.gd >/dev/null 2>&1; then
  echo "get_node_or_null остался в BattleUI"; exit 1
fi
echo "OK: BattleUI без get_node_or_null"

echo "=== ВСЁ ПРОШЛО (XML-отчёт в reports/report_*/results.xml) ==="

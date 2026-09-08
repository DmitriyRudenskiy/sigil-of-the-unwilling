#!/usr/bin/env bash
# Запуск тестов: GdUnit4 (tests/, классы GdUnitTestSuite) + MCP-тесты (tugcantopaloglu/godot-mcp).
# GUT удалён из проекта (addons/gut отсутствует) — секции GUT нет.
# Exit code GdUnit4: 0 = pass, 101 = только orphan-предупреждения (гигиена тестов),
# 100 и прочие = реальные падения.
set -u
cd "$(dirname "$0")"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"

echo "=== gdUnit4: unit + integration + functional ==="
# --import: обновить кэш глобальных классов (иначе новые class_name дают parse errors)
"$GODOT" --headless --path . --import >/dev/null 2>&1

"$GODOT" --headless --path . -s addons/gdunit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -c -a res://tests
RC=$?
if [ "$RC" -ne 0 ] && [ "$RC" -ne 101 ]; then
	exit "$RC"
fi

echo ""
echo "=== MCP-тесты (tugcantopaloglu/godot-mcp) ==="
MCP_SERVER="${GODOT_MCP_SERVER:-$PWD/addons/godot-mcp/build/index.js}"
if [ ! -f "$MCP_SERVER" ]; then
	echo "Skipped: godot-mcp сервер не найден ($MCP_SERVER)"
	echo "Укажите GODOT_MCP_SERVER, чтобы запустить MCP-тесты."
	exit 0
fi
export GODOT_MCP_SERVER="$MCP_SERVER"
export GODOT_PROJECT_PATH="${GODOT_PROJECT_PATH:-$PWD}"
cd tests/mcp
python3 -m pytest -xvs --timeout=300 --tb=short \
  test_battle_tween.py \
  test_resource_and.py \
  test_hexutils_perf.py \
  test_session_reset.py \
  test_shard_pruning.py \
  test_battle_profiling.py
MCP_RC=$?
cd "$(dirname "$0")"
# Вендорный MCP-сервер инжектит mcp_interaction_server.gd + autoload в project.godot
# и при выгрузке оставляет пустые строки — возвращаем чистое дерево.
rm -f mcp_interaction_server.gd mcp_interaction_server.gd.uid
git checkout -- project.godot 2>/dev/null || true
exit "$MCP_RC"

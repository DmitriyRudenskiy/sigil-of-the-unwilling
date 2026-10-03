#!/usr/bin/env bash
# Sigil of the Unwilling — полный тестовый прогон (CI-2, 2026-10-03).
# Уровни: (1) GdUnit4 unit/integration/functional; (2) MCP (pytest + server).
#
# Политика exit-кодов (CI-2, владелец 2026-10-03):
#   * GdUnit4: 0 = pass; 101 = только orphan-предупреждения; 100/прочие = падения.
#   * Orphan = warning, НЕ влияет на exit (красный = только падения/регрессии).
#   * MCP-секция не имеет права молчать: явные строки PYTEST: SKIPPED (причина)
#     при отсутствии сервера или модуля pytest.
#
# Порядок разрешения Godot (CI-3, 2026-10-03):
#   $GODOT_BIN → путь из AGENTS.md → `command -v godot` → дефолты ОС.
set -u
cd "$(dirname "$0")"

if [ -n "${GODOT_BIN:-}" ]; then
  GODOT="$GODOT_BIN"
elif [ -x /home/user/.local/bin/godot ]; then
  GODOT="/home/user/.local/bin/godot"
elif command -v godot >/dev/null 2>&1; then
  GODOT="$(command -v godot)"
else
  GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
fi
echo "GODOT: $GODOT"

echo "=== gdUnit4: unit + integration + functional ==="
# Pre-import to refresh the global class cache (class_name).
"$GODOT" --headless --path . --import >/dev/null 2>&1
"$GODOT" --headless --path . -s addons/gdunit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -c -a res://tests
RC=$?
case "$RC" in
  0)   GATE=0; echo "GDUNIT: exit=0 -> GATE=0 (green)" ;;
  101) GATE=0; echo "GDUNIT: exit=101 (orphan = warning, policy CI-2) -> GATE=0 (green)" ;;
  *)   GATE=$RC; echo "GDUNIT: exit=$RC -> GATE=$RC (red: failures)" ;;
esac
if [ "$GATE" -ne 0 ]; then
  exit "$GATE"
fi

echo ""
echo "=== MCP tests (tugcantopaloglu/godot-mcp) ==="
MCP_SERVER="${GODOT_MCP_SERVER:-$PWD/addons/godot-mcp/build/index.js}"
if [ ! -f "$MCP_SERVER" ]; then
  echo "PYTEST: SKIPPED (no MCP server: $MCP_SERVER)"
  exit 0
fi
if ! python3 -m pytest --version >/dev/null 2>&1; then
  echo "PYTEST: SKIPPED (no module 'pytest'; install: python3 -m pip install pytest — долг Q-M23)"
  exit 0
fi
if [ ! -f mcp_interaction_server.gd ]; then
  echo "MCP: no mcp_interaction_server.gd, skipping"
  exit 0
fi
GODOT_MCP_SERVER="$MCP_SERVER" \
GODOT_BIN="$GODOT" \
GODOT_PROJECT="$PWD" \
  python3 -m pytest tests/mcp/ -v --timeout=120
MCP_RC=$?
# restore
rm -f mcp_interaction_server.gd
git checkout -- project.godot 2>/dev/null || true
exit "$MCP_RC"

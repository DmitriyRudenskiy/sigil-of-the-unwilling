#!/usr/bin/env bash
# Запуск тестов: GdUnit4 (tests/, классы GdUnitTestSuite) + MCP-тесты (tugcantopaloglu/godot-mcp).
# GUT удалён из проекта (addons/gut отсутствует) — секции GUT нет.
# Exit code GdUnit4: 0 = pass, 101 = только orphan-предупреждения (гигиена тестов),
# 100 и прочие = реальные падения.
#
# MCP e2e (feat/mcp-e2e-activation, 2026-10-04): venv + Xvfb + GODOT_PATH +
# --timeout=900; MCP-секция не имеет права молчать (явные PYTEST: SKIPPED).
set -u
cd "$(dirname "$0")"
# Порядок разрешения Godot (2026-10-04, флаг 8): $GODOT_BIN → $GODOT (legacy) →
# command -v godot → дефолты ОС (путь бинаря задокументирован в AGENTS.md)
GODOT="${GODOT_BIN:-${GODOT:-}}"
if [ -z "$GODOT" ]; then
	GODOT="$(command -v godot || true)"
fi
if [ -z "$GODOT" ]; then
	case "$(uname -s)" in
		Darwin) GODOT="/Applications/Godot.app/Contents/MacOS/Godot" ;;
		*) GODOT="$HOME/.local/bin/godot" ;;
	esac
fi
echo "GODOT: $GODOT"

echo "=== gdUnit4: unit + integration + functional ==="
# --import: обновить кэш глобальных классов (иначе новые class_name дают parse errors)
"$GODOT" --headless --path . --import >/dev/null 2>&1

"$GODOT" --headless --path . -s addons/gdunit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -c -a res://tests
RC=$?
# Политика orphan (CI-2, T-114): 0 = pass; 101 = только orphan-предупреждения
# (гигиена, не падение); любой другой код = red. Политика закодирована в гейте.
if [ "$RC" -ne 0 ] && [ "$RC" -ne 101 ]; then
	exit "$RC"
fi

echo ""
echo "=== MCP-тесты (tugcantopaloglu/godot-mcp) ==="
MCP_SERVER="${GODOT_MCP_SERVER:-$PWD/addons/godot-mcp/build/index.js}"
if [ ! -f "$MCP_SERVER" ]; then
	echo "PYTEST: SKIPPED (no MCP server: $MCP_SERVER; build: cd addons/godot-mcp && npm ci && npm run build)"
	exit 0
fi
# MCP e2e-тесты запускают живой Godot (не headless) — нужен X-дисплей.
# Если DISPLAY не задан, а Xvfb доступен — поднимаем виртуальный на :97
# (:98/:99 могут быть заняты другими сессиями; :99 с auth не подойдёт).
XVFB_PID=""
if [ -z "${DISPLAY:-}" ] && command -v Xvfb >/dev/null 2>&1; then
	Xvfb :97 -screen 0 1024x768x24 >/dev/null 2>&1 &
	XVFB_PID=$!
	sleep 2
	if ! kill -0 "$XVFB_PID" 2>/dev/null; then
		echo "PYTEST: SKIPPED (Xvfb :97 не стартовал — дисплей занят? укажите DISPLAY)"
		exit 0
	fi
	export DISPLAY=:97
fi
# venv MCP-тестов: путь зафиксирован в AGENTS.md.
PYTEST_PY="${MCP_PYTEST_PY:-/home/user/.venv/godot-mcp-tests/bin/python}"
if [ ! -x "$PYTEST_PY" ]; then
	echo "PYTEST: SKIPPED (no venv: $PYTEST_PY; create: python3 -m venv /home/user/.venv/godot-mcp-tests && $PYTEST_PY -m pip install pytest pytest-timeout mcp anyio)"
	[ -n "$XVFB_PID" ] && kill "$XVFB_PID" 2>/dev/null || true
	exit 0
fi
export GODOT_MCP_SERVER="$MCP_SERVER"
export GODOT_PROJECT_PATH="${GODOT_PROJECT_PATH:-$PWD}"
# conftest.py читает GODOT_PATH (не GODOT_BIN) — баг старого скрипта исправлен.
# --timeout=900: READY_TIMEOUT в godot_mcp.py = 900 c; старое --timeout=300 резало
# e2e раньше собственного дедлайна.
# Полный свит tests/mcp/ (39 тестов), не выборка из 6 файлов.
GODOT_PATH="$GODOT" \
GODOT_BIN="$GODOT" \
"$PYTEST_PY" -m pytest tests/mcp/ -v --timeout=900 --tb=short
MCP_RC=$?
# Вендорный MCP-сервер инжектит mcp_interaction_server.gd + autoload в project.godot
# и при выгрузке оставляет пустые строки — возвращаем чистое дерево.
[ -n "$XVFB_PID" ] && kill "$XVFB_PID" 2>/dev/null || true
rm -f mcp_interaction_server.gd mcp_interaction_server.gd.uid
git checkout -- project.godot 2>/dev/null || true
exit "$MCP_RC"

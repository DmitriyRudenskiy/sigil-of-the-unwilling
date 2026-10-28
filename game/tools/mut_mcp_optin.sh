#!/usr/bin/env bash
# Мутационная батарея T-240 (автозагрузка MCP в `main` ≠ «слушает порт»).
#
# Краснеть должен tests/unit/core/test_mcp_server.gd: он держит три вещи —
# строка автозагрузки указывает на домашний форк (а не на вендорский монолит),
# без MCP_ENABLE порт не поднимается (и узел не тикает), а с MCP_ENABLE
# поднимается и честно освобождается по stop().
#
# Мутанты: снятая opt-in-проверка (M1) — ровно та дыра тикета, любой
# `godot --path game` поднимает TCP с полным доступом к игре; инвертированная
# проверка (M2) — стенд остаётся без сервера, а игрок с ним; всегда-истинный
# предикат (M3); снятый set_process(false) на закрытой ветке (M4) — узел тикает
# с мёртвым транспортом; возврат регистрации команд в start() (M5) — при
# закрытом порту реестр пуст, тесты реестра этого не видят; stop() без сброса
# состояния (M6) — «остановленный» сервер числится запущенным; подмена пути
# автозагрузки на вендорский скрипт (M7) — молча возвращает монолит без MCP_PORT.
#
# Батарея не покрывает conftest (MCP_ENABLE там): его снятие краснит весь MCP-свит
# неспособностью подключиться, это проверяется самим прогоном, а не GdUnit.
#
# Запуск: bash game/tools/mut_mcp_optin.sh   (из корня репо, дерево чистое)
set -u
G=${GODOT_BIN:-/home/user/.local/bin/godot}
TESTS=(-a res://tests/unit/core/test_mcp_server.gd)
SRV=game/tools/mcp/mcp_interaction_server.gd
PROJ=game/project.godot
FAILED=0

run() { # имя, файл-мишень
	local name="$1"
	local out
	out=$(cd game && timeout 900 "$G" --headless --path . -s addons/gdunit4/bin/GdUnitCmdTool.gd \
		--ignoreHeadlessMode -c "${TESTS[@]}" 2>&1 | grep -oE "0 errors \| [0-9]+ failures" | tail -1)
	echo "$name: $out"
	case "$out" in
	"" | *"0 errors | 0 failures"*)
		echo "  !! ЗЕЛЁНЫЙ (или нечитаемый) МУТАНТ — гейт не ловит"
		FAILED=1
		;;
	esac
	git checkout -- "$2"
}

mutate() { # файл, python-выражение; неприменившийся мутант — падение батареи
	python3 - "$1" "$2" <<'PY'
import sys, pathlib
path, body = sys.argv[1], sys.argv[2]
p = pathlib.Path(path); s0 = p.read_text(encoding="utf-8"); s = s0
exec(body)
assert s != s0, "МУТАНТ НЕ ПРИМЕНИЛСЯ: %s" % path
p.write_text(s, encoding="utf-8")
PY
}

# M1 — сама дыра T-240: транспорт слушает без явного приказа.
mutate "$SRV" '
old = """	if not enabled_by_env():
		push_warning(
			"McpInteractionServer: autoload is present but the TCP endpoint stays "
			+ "closed without %s=1 (T-240). Set it only in the MCP test harness."
			% ENABLE_ENV)
		set_process(false)
		return false
"""
assert s.count(old) == 1
s = s.replace(old, "", 1)
'
run M1 "$SRV"

# M2 — инверсия: opt-in закрывает порт вместо того чтобы открывать.
mutate "$SRV" '
old = "\tif not enabled_by_env():\n"
assert s.count(old) == 1
s = s.replace(old, "\tif enabled_by_env():\n", 1)
'
run M2 "$SRV"

# M3 — предикат, который всегда «да» (проверка есть, но ничего не значит).
mutate "$SRV" '
old = "\treturn OS.get_environment(ENABLE_ENV) == \"1\""
assert s.count(old) == 1
s = s.replace(old, "\treturn true", 1)
'
run M3 "$SRV"

# M4 — закрытый порт, но узел продолжает тикать (полупрозрачное состояние).
mutate "$SRV" '
old = """			% ENABLE_ENV)
		set_process(false)
		return false"""
assert s.count(old) == 1
s = s.replace(old, """			% ENABLE_ENV)
		return false""", 1)
'
run M4 "$SRV"

# M5 — регистрация команд возвращается в start(): без opt-in реестр пуст.
mutate "$SRV" '
old = """	_dispatcher.clear()
	for group in _groups:
		_dispatcher.register(group)
	start()"""
assert s.count(old) == 1
s = s.replace(old, "\tstart()", 1)
old2 = """	_auth_token = OS.get_environment(AUTH_TOKEN_ENV)
	_server = TCPServer.new()"""
assert s.count(old2) == 1
s = s.replace(old2, """	_auth_token = OS.get_environment(AUTH_TOKEN_ENV)
	_dispatcher.clear()
	for group in _groups:
		_dispatcher.register(group)
	_server = TCPServer.new()""", 1)
'
run M5 "$SRV"

# M6 — stop() не сбрасывает состояние: «остановленный» сервер числится живым.
mutate "$SRV" '
old = "func stop() -> void:\n	if _client != null:"
assert s.count(old) == 1
s = s.replace(old, "func stop() -> void:\n	if true:\n		return\n	if _client != null:", 1)
'
run M6 "$SRV"

# M7 — автозагрузка переводит на вендорский скрипт (монолит без MCP_PORT/токена).
mutate "$PROJ" '
old = "McpInteractionServer=\"*res://tools/mcp/mcp_interaction_server.gd\""
assert s.count(old) == 1
s = s.replace(old, "McpInteractionServer=\"*res://mcp_interaction_server.gd\"", 1)
'
run M7 "$PROJ"

echo "battery rc=$FAILED"
exit $FAILED

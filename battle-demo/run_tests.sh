#!/usr/bin/env bash
# Гейт демо: GdUnit4 headless. Тот же контракт кодов выхода, что и game/run_tests.sh:
# 0 = pass, 101 = только orphan-предупреждения (гигиена, не падение) -> GATE=0.
# MCP e2e, CI-поллинг и orphan-allowlist основного проекта сюда не перенесены:
# у демо их пока нет (задача 1.5).
set -u
cd "$(dirname "$0")"

GODOT="${GODOT_BIN:-${GODOT:-}}"
if [ -z "$GODOT" ]; then
	for p in /Applications/Godot.app/Contents/MacOS/Godot "$(command -v godot || true)"; do
		[ -n "$p" ] && [ -x "$p" ] && GODOT="$p" && break
	done
fi
if [ ! -x "$GODOT" ]; then
	echo "GODOT: НЕ НАЙДЕН — задай GODOT_BIN (уровень молчит = красный)"
	exit 2
fi
echo "GODOT: $("${GODOT}" --version 2>/dev/null | tail -1)"

mkdir -p artifacts
"${GODOT}" --headless --path . --import >/dev/null 2>&1

LOG=artifacts/gate.log
"${GODOT}" --headless --path . -s addons/gdunit4/bin/GdUnitCmdTool.gd \
	--ignoreHeadlessMode -c -a res://tests 2>&1 | tee "$LOG"
RC=${PIPESTATUS[0]}

if [ "$RC" -ne 0 ] && [ "$RC" -ne 101 ]; then
	echo "GATE=RED (gdunit exit ${RC}, лог ${LOG})"
	exit 1
fi
if grep -q "No test cases found" "$LOG"; then
	echo "GATE=WARN: тестов нет — зелёный пустой гейт, ничего не проверяется"
fi
echo "GATE=GREEN (gdunit exit ${RC}, лог ${LOG})"

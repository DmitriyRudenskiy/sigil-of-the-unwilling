#!/usr/bin/env bash
# Мутационная батарея сталл-защиты автоигрока (scenario-matrix 9.2/9.3, бой-патруль T-205).
# Каждый мутант обязан покраснить test_probe_battle_stall.gd; зелёный мутант = дыра меры.
# Мутации бьют по обоим слоям: правила приёма атаки (M1 — прежняя «d > 1» политика,
# M2 — приоритет дальней цели над соседом, M3 — ближний бой принимает дальнюю цель)
# и ключ необратимого прогресса (M4 — ключ из активного юнита/has_moved, как было до
# фикса; M5 — позиции выпали из ключа; M6 — живость и состав стэков выпали из ключа).
#
# Запуск: bash game/tools/mut_probe_battle_stall.sh   (из корня репо, дерево чистое)
set -u
G=${GODOT_BIN:-/home/user/.local/bin/godot}
TEST=res://tests/unit/probe/test_probe_battle_stall.gd
PROBE=game/scripts/probe/balance_probe.gd
FAILED=0

mutate() { # python-мутация: старая строка, новая строка
	python3 - "$1" "$2" <<'PY'
import pathlib, sys
p = pathlib.Path("game/scripts/probe/balance_probe.gd")
s = p.read_text(encoding="utf-8")
old, new = sys.argv[1], sys.argv[2]
assert s.count(old) == 1, "якорь мутации не найден уникально: %r" % old[:60]
p.write_text(s.replace(old, new, 1), encoding="utf-8")
PY
}

run() {
	local name="$1"
	local out
	out=$(cd game && timeout 600 "$G" --headless --path . -s addons/gdunit4/bin/GdUnitCmdTool.gd \
		--ignoreHeadlessMode -c -a "$TEST" 2>&1 | grep -oE "0 errors \| [0-9]+ failures" | tail -1)
	echo "$name: $out"
	case "$out" in
	"" | *"0 errors | 0 failures"*)
		echo "  !! ЗЕЛЁНЫЙ (или нечитаемый) МУТАНТ — мера не ловит"
		FAILED=1
		;;
	esac
	git checkout -- "$PROBE"
}

mutate 'if unit.is_ranged() and d < best_d and BattleLineOfSight.can_target_ranged(bs, unit.cell, e):' \
	'if unit.is_ranged() and d > 1 and d < best_d:'
run M1-прежняя-политика-дальнего "$PROBE"

mutate 'return adjacent if adjacent != null else ranged' \
	'return ranged if ranged != null else adjacent'
run M2-дальняя-цель-над-соседом

mutate '		if d == 1:
			adjacent = e' \
	'		if d <= 3:
			adjacent = e'
run M3-ближний-бьёт-издалека

mutate '	return ",".join(parts)' \
	'	return "%s|%d|%s" % [",".join(parts), int(bs.turn_idx), str(bs.active_unit.uid if bs.active_unit != null else -1)]'
run M4-ключ-из-активного-юнита

mutate '		int(u.cell.x), int(u.cell.y), int(u.get_count())]' \
	'		0, 0, int(u.get_count())]'
run M5-позиции-вне-ключа

mutate '		int(u.uid), "a" if u.is_alive() else ("d" if u.is_downed() else "x"),' \
	'		int(u.uid), "a",'
mutate '		int(u.cell.x), int(u.cell.y), int(u.get_count())]' \
	'		int(u.cell.x), int(u.cell.y), 0]'
run M6-живость-и-состав-вне-ключа

echo "ИТОГ: $([ "$FAILED" = 0 ] && echo 'все мутанты красные (мера держит)' || echo 'ЕСТЬ ЗЕЛЁНЫЕ МУТАНТЫ')"
exit "$FAILED"

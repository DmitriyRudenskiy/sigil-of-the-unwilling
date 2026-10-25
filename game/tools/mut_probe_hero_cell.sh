#!/usr/bin/env bash
# Мутационная батарея стража «героя нет» (T-207, D-257).
# Каждый мутант обязан покраснить test_probe_hero_cell_after_death.gd; зелёный мутант =
# дыра меры. Падение процесса (SIGSEGV/SCRIPT ERROR без сводки) тоже считается красным:
# именно так выглядел исходный дефект в матричном прогоне.
#
# Мутанты:
#   M1 — страж снят совсем (исходный дефект: чтение get_component у освобождённого);
#   M2 — страж возвращает (0,0) вместо «нет цели» (цель в стартовой клетке = ложное прибытие);
#   M3 — роль не смотрит на валидность героя (metrics/HP читают мёртвого);
#   M4 — HP читается всегда, `gone` учитывается только в дистанции;
#   M5 — страж проглатывает живого героя (всегда «нет клетки»).
#
# Запуск: bash game/tools/mut_probe_hero_cell.sh   (из корня репо, дерево чистое)
set -u
G=${GODOT_BIN:-/home/user/.local/bin/godot}
TEST=res://tests/unit/probe/test_probe_hero_cell_after_death.gd
PROBE=game/scripts/probe/balance_probe.gd
ROLE=game/scripts/probe/TravelerRole.gd
FAILED=0

mutate() { # python-мутация: файл, старая строка, новая строка
	python3 - "$1" "$2" "$3" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
s = p.read_text(encoding="utf-8")
old, new = sys.argv[2], sys.argv[3]
assert s.count(old) == 1, "якорь мутации не найден уникально: %r" % old[:60]
p.write_text(s.replace(old, new, 1), encoding="utf-8")
PY
}

run() {
	local name="$1"
	local out
	out=$(cd game && timeout 600 "$G" --headless --path . -s addons/gdunit4/bin/GdUnitCmdTool.gd \
		--ignoreHeadlessMode -c -a "$TEST" 2>&1 | grep -oE "[0-9]+ errors \| [0-9]+ failures" | tail -1)
	echo "$name: ${out:-ПАДЕНИЕ ПРОЦЕССА (сводки нет) — тоже красный}"
	case "$out" in
	"" | "0 errors | 0 failures")
		echo "  !! ЗЕЛЁНЫЙ (или нечитаемый) МУТАНТ — мера не ловит"
		FAILED=1
		;;
	esac
	git checkout -- "$PROBE" "$ROLE"
}

mutate "$PROBE" '	if _hero == null or not is_instance_valid(_hero):
		return Vector2i(-1, -1)
' ''
run M1-страж-снят

mutate "$PROBE" '	if _hero == null or not is_instance_valid(_hero):
		return Vector2i(-1, -1)' '	if _hero == null or not is_instance_valid(_hero):
		return Vector2i.ZERO'
run M2-страж-ноль-вместо-стражи

mutate "$ROLE" '	var gone: bool = hero == null or not is_instance_valid(hero)' '	var gone: bool = false'
run M3-роль-не-смотрит-на-валидность

mutate "$ROLE" '		"hp": int(hero.combat_hp) if not gone else 0,' '		"hp": int(hero.combat_hp) if hero != null else 0,'
run M4-hp-читается-всегда

mutate "$PROBE" '	if _hero == null or not is_instance_valid(_hero):
		return Vector2i(-1, -1)
	var mv: Node = _hero.get_component("Movement")' '	if true:
		return Vector2i(-1, -1)
	var mv: Node = _hero.get_component("Movement")'
run M5-страж-проглатывает-живого

echo "ИТОГ: $([ "$FAILED" = 0 ] && echo 'все мутанты красные (мера держит)' || echo 'ЕСТЬ ЗЕЛЁНЫЕ МУТАНТЫ')"
exit "$FAILED"

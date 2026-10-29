#!/usr/bin/env bash
# `timeout` не из POSIX и на macOS живёт как `gtimeout` (из coreutils). Без этого
# shim'а каждый мутант «падал» до запуска Godot, а батарея печатала «гейт держит»,
# ничего не прогнав: отсутствующая команда = «тоже красный».
timeout() {
	# есть gtimeout — работаем им; нет — исполняем команду без ограничения времени
	# (сдвиг аргумента: $1 — длительность, а не команда).
	if command -v gtimeout >/dev/null; then gtimeout "$@"; else shift; "$@"; fi
}
# Мутационная батарея контраста боевой последовательности атаки (T-227 С-4).
#
# Каждый мутант обязан покраснить test_attack_sequence.gd; зелёный мутант = дыра
# контраста. Мутации бьют по решениям машины, а не по её локальным переменным:
# число стриков (M1–M2), выстрел против драки (M3–M4), право на контратаку (M5–M7),
# лишний ход за моралью (M8–M10), соседство (M11), закрытие удара (M12).
#
# Запуск: bash game/tools/mut_attack_sequence.sh   (из корня репо, дерево чистое)
set -u
G=${GODOT_BIN:-/home/user/.local/bin/godot}
TEST=res://tests/unit/battle/test_attack_sequence.gd
SRC=game/scripts/systems/battle_attack_sequence.gd
FAILED=0

run() {
	local name="$1"
	local out
	out=$(cd game && timeout 600 "$G" --headless --path . -s addons/gdunit4/bin/GdUnitCmdTool.gd \
		--ignoreHeadlessMode -c -a "$TEST" 2>&1 | grep -oE "0 errors \| [0-9]+ failures" | tail -1)
	echo "$name: $out"
	case "$out" in
	"0 errors | 0 failures")
		echo "  !! ЗЕЛЁНЫЙ МУТАНТ — контраст не ловит"
		FAILED=1
		;;
	esac
	git checkout -- "$SRC"
}

# Эквивалентный мутант: зелёный по конструктивной причине, а не из-за дыры в
# контрасте. Проверяется, что мутация вообще применилась, и фиксируется как эквивалент.
run_equivalent() {
	local name="$1"
	local reason="$2"
	local out
	out=$(cd game && timeout 600 "$G" --headless --path . -s addons/gdunit4/bin/GdUnitCmdTool.gd \
		--ignoreHeadlessMode -c -a "$TEST" 2>&1 | grep -oE "0 errors \| [0-9]+ failures" | tail -1)
	echo "$name: $out — ЭКВИВАЛЕНТЕН: $reason"
	git checkout -- "$SRC"
}

mutate() { # python-выражение
	python3 - "$1" <<'PY'
import sys, pathlib
path = "game/scripts/systems/battle_attack_sequence.gd"
body = sys.argv[1]
p = pathlib.Path(path); s0 = p.read_text(encoding="utf-8"); s = s0
exec(body)
assert s != s0, "МУТАЦИЯ НЕ ПРИМЕНИЛАСЬ: %s" % path
p.write_text(s, encoding="utf-8")
PY
}

# M1: тег double_strike перестал удваивать — второй удар исчез.
mutate 's = s.replace("\t_attack_strikes_left = 2 if atk.is_double_strike() else 1", "\t_attack_strikes_left = 1")'
run M1_double_strike_ignored "$SRC"

# M2: обратная сторона — удар всегда двойной, одиночка бьёт twice.
mutate 's = s.replace("\t_attack_strikes_left = 2 if atk.is_double_strike() else 1", "\t_attack_strikes_left = 2")'
run M2_always_double "$SRC"

# M3: лучник вплотную остаётся «выстрелом» — контратака у цели пропадает.
mutate 's = s.replace("var is_ranged_shot := atk.is_ranged() and distance > 1 and not adjacent_enemy", "var is_ranged_shot := atk.is_ranged() and distance > 1")'
run M3_melee_as_shot "$SRC"

# M4: проверка дальности/линии огня обойдена — выстрел через всю карту становится ударом.
mutate 's = s.replace("if is_ranged_shot and not BattleLineOfSight.can_target_ranged(_battle_state, atk.cell, def):", "if false and is_ranged_shot:")'
run M4_los_bypass "$SRC"

# M5: мёртвый защитник получает право ответить.
mutate 's = s.replace("\tif not _attack_defender.is_alive():\n\t\treturn false\n\n\tif not _attack_attacker.is_alive():", "\tif not _attack_attacker.is_alive():")'
run M5_dead_counterstriker "$SRC"

# M6: контратака не помечается использованной — счётчик ответов не существует.
mutate 's = s.replace("\toriginal_defender.has_retaliated = true", "\tpass")'
run M6_retaliation_unmarked "$SRC"

# M7: тег no_retaliation не читается.
mutate 's = s.replace("\tif _attack_attacker.is_no_retaliation():", "\tif false:")'
run M7_no_retaliation_ignored "$SRC"

# M8: лишний ход не сбрасывает флаг движения — «дополнительный» ход нулевой.
mutate 's = s.replace("\tunit.has_moved = false", "\tpass")'
run M8_extra_turn_no_move "$SRC"

# M9: лишний ход привязан к зоне, но не к владельцу удара — один Триумф кормит всех.
mutate 's = s.replace("\tif _last_strike_unit != unit or _last_strike_zone != BattleRules.ZONE_TRIUMPH:", "\tif _last_strike_zone != BattleRules.ZONE_TRIUMPH:")'
run M9_morale_not_owner_bound "$SRC"

# M10: Триумф перестал быть условием — лишний ход за любой удар.
mutate 's = s.replace("\tif _last_strike_unit != unit or _last_strike_zone != BattleRules.ZONE_TRIUMPH:", "\tif _last_strike_unit != unit:")'
run M10_morale_any_zone "$SRC"

# M11: соседство считается по мёртвым — выстрел деградирует в драку из-за трупа.
mutate 's = s.replace("\t\tif u != null and u.is_alive():", "\t\tif u != null:")'
run_equivalent M11_adjacent_corpse \
	"мёртвый юнит снимаётся с клетки (kill_unit/down_unit -> _unit_grid.erase), поэтому get_unit_at его не вернёт: проверка is_alive() в has_adjacent_enemy — страховка, а не правило. Убить её публичным контрактом невозможно."

# M12: finish() не снимает активную пару — удар висит после завершения.
mutate 's = s.replace("func finish() -> void:\n\t_attack_attacker = null", "func finish() -> void:\n\tpass")'
run M12_finish_keeps_pair "$SRC"

echo "===================="
if [ "$FAILED" -eq 0 ]; then
	echo "MUTATION BATTERY: все мутанты красные (контраст работает)"
else
	echo "MUTATION BATTERY: есть зелёные мутанты — контраст слеп"
fi
exit "$FAILED"

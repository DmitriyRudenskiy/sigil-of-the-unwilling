#!/usr/bin/env bash
# `timeout` не из POSIX и на macOS живёт как `gtimeout` (из coreutils). Без этого
# shim'а каждый мутант «падал» до запуска Godot, а батарея печатала «гейт держит»,
# ничего не прогнав: отсутствующая команда = «тоже красный».
timeout() {
	# есть gtimeout — работаем им; нет — исполняем команду без ограничения времени
	# (сдвиг аргумента: $1 — длительность, а не команда).
	if command -v gtimeout >/dev/null; then gtimeout "$@"; else shift; "$@"; fi
}
# Мутационная батарея «Удача донесена до BattleState» (T-221 → D-268).
# Каждый мутант обязан покраснить tests/unit/systems/test_battle_luck_carrier.gd;
# зелёный мутант = дыра гейта.
#
# M6 — писатель забыт (мод не читается из артефактных модов): историческое
#      состояние, из-за которого удача была писателем без читателя.
# M7 — проставляется число, но не источник: ровно та половина инварианта, ради
#      которой введено `luck_source`.
# M8 — строка показывается без источника: возвращает «ноль из ниоткуда», то, что
#      M1 запрещает прямо (тот же дефект, что строка способностей у не-dnd юнита).
# M9 — знак мода теряется (absi): «-1» печатается как «+1», то есть штраф удачей.
# M10 — `has_luck()` выводится из числа, а не из источника: инвариант пары
#      («источник важнее числа») перестаёт держаться, `luck = 3` без писателя
#      снова рисует строку.
#
# Запуск: bash game/tools/mut_battle_luck.sh   (из корня репо, дерево чистое)
set -u
G=${GODOT_BIN:-/home/user/.local/bin/godot}
TEST=res://tests/unit/systems/test_battle_luck_carrier.gd
BUILDER=game/scripts/systems/battle_state_builder.gd
UI=game/scripts/ui/battle_ui.gd
STATE=game/scripts/systems/battle_state.gd
FILES=("$BUILDER" "$UI" "$STATE")
FAILED=0

run() {
	local name="$1"
	local out
	out=$(cd game && timeout 600 "$G" --headless --path . -s addons/gdunit4/bin/GdUnitCmdTool.gd \
		--ignoreHeadlessMode -c -a "$TEST" 2>&1 | grep -oE "0 errors \| [0-9]+ failures" | tail -1)
	echo "$name: ${out:-<нет сводки: прогон упал до сводки — тоже красный>}"
	case "$out" in
	"0 errors | 0 failures")
		echo "  !! ЗЕЛЁНЫЙ МУТАНТ — гейт не ловит"
		FAILED=1
		;;
	esac
	git checkout -- "${FILES[@]}"
}

mut() { # mut <файл> <было> <станет>
	python3 - "$@" <<'PY'
import pathlib, sys
path, old, new = sys.argv[1:4]
p = pathlib.Path(path)
s = p.read_text(encoding="utf-8")
assert s.count(old) == 1, f"{path}: якорь встречается {s.count(old)} раз"
p.write_text(s.replace(old, new, 1), encoding="utf-8")
PY
}

mut "$BUILDER" '	var luck_mod: int = int(mods.get("luck", 0))' '	var luck_mod: int = 0'
run "M6 — мод не читается из артефактных модов"

mut "$BUILDER" '			u.luck_source = &"artifact"' '			pass'
run "M7 — число без источника"

mut "$UI" '	_tc_luck_row.visible = unit.has_luck()' '	_tc_luck_row.visible = true'
run "M8 — строка без источника"

mut "$UI" '		_tc_luck.text = "%+d" % unit.luck' '		_tc_luck.text = "%+d" % absi(unit.luck)'
run "M9 — знак мода потерян"

mut "$STATE" '		return luck_source != &""' '		return luck != 0'
run "M10 — источник выводится из числа"

echo "ИТОГ: $([ "$FAILED" = 0 ] && echo 'все мутанты красные — гейт держит' || echo 'ЕСТЬ ЗЕЛЁНЫЕ МУТАНТЫ')"
exit "$FAILED"

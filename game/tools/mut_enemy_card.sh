#!/usr/bin/env bash
# Мутационная батарея «карточка врага видна всегда» (dnd-battle-ladder 4.1, M1).
# Каждый мутант обязан покраснить tests/unit/ui/test_enemy_card_always_visible.gd;
# зелёный мутант = дыра гейта.
#
# M1 — дефолтная карточка снова прячет окно (историческое состояние: `target_card`
#      был тултипом прицеливания, между наведениями AC/HP не было видно).
# M2 — проверка `alive` выброшена: окно показывает последнего мёртвого врага.
# M3 — подпись «Противник» заменена на «Цель»: окно врёт, пока никто не наведён
#      (тот же класс дефекта, что «строка без источника» в M1-принципе UI).
# M4 — вызов снят из `BattleController._ready`: карточка появляется только после
#      первого наведения мыши, то есть «всегда» не выполняется в первом кадре.
# M5 — параметр подписи игнорируется в `show_target_card`: прицеливание перестаёт
#      переименовывать окно, различие «Цель»/«Противник» стирается.
#
# Запуск: bash game/tools/mut_enemy_card.sh   (из корня репо, дерево чистое)
set -u
G=${GODOT_BIN:-/home/user/.local/bin/godot}
TEST=res://tests/unit/ui/test_enemy_card_always_visible.gd
UI=game/scripts/ui/battle_ui.gd
CTRL=game/scripts/systems/battle_controller.gd
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
	git checkout -- "$UI" "$CTRL"
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

mut "$UI" '			show_target_card(unit, "Противник")' '			hide_target_card()'
run "M1 — дефолт прячет окно (исторический дефект)"

mut "$UI" '		if unit != null and unit.alive:' '		if unit != null:'
run "M2 — мёртвый враг остаётся в окне"

mut "$UI" '			show_target_card(unit, "Противник")' '			show_target_card(unit, "Цель")'
run "M3 — подпись врёт до наведения"

mut "$CTRL" '	# 4.1 (M1): карточка врага видна с первого кадра боя, а не с первого наведения
	_ui.show_default_enemy_card(_state)
' ''
run "M4 — вызов снят из _ready"

mut "$UI" '	_tc_caption.text = caption' '	_tc_caption.text = "Цель"'
run "M5 — параметр подписи проигнорирован"

echo "ИТОГ: $([ "$FAILED" = 0 ] && echo 'все мутанты красные — гейт держит' || echo 'ЕСТЬ ЗЕЛЁНЫЕ МУТАНТЫ')"
exit "$FAILED"

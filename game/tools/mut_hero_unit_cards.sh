#!/usr/bin/env bash
# Мутационная батарея карточек отряда и строки уровня экрана «Герой» (T-306).
#
# Что под защитой. Экран живёт в единственном носителе — окне «Модель героя» из
# настроек (D-255), где показывается модель нового героя. У этой модели уровня
# нет (`HeroController` хранит только опыт, а его писатель `add_xp` живёт в
# архивной мирной линии), а у стека отряда нет ни уровня, ни текущего HP, ни
# второй шкалы — `UnitStack` это `count` + `UnitStats`. Поэтому имя, иконка и
# численность показываются, а `CardLv_*`/`CardHp_*`/`CardMp_*` и `LevelRow`
# скрыты, а не обнулены (D-280, T-251).
#
# Гард двусторонний: `test_unit_cards_and_level_row_show_only_what_has_a_carrier`
# в `game/tests/unit/ui/test_inventory_grid.gd` краснеет и если скрытые метки
# вернут на экран, и если экран перестанет показывать то, что показать должен.
# Отсюда и мутации с двух сторон: M1/M5 — «вернули нечем», M2/M3/M4 — «перестали
# показывать тем, чем можно».
#
# Запуск: bash game/tools/mut_hero_unit_cards.sh   (из корня репо, дерево чистое)
set -u
G=${GODOT_BIN:-/home/user/.local/bin/godot}
TEST=res://tests/unit/ui/test_inventory_grid.gd
SRC=game/scripts/ui/artifact_inventory_screen.gd
TST=game/tests/unit/ui/test_inventory_grid.gd
FAILED=0

# Батарея откатывает свои правки через `git checkout --`, поэтому чужая
# незакоммиченная работа в затронутых файлах — повод не начинать.
dirty=$(git status --porcelain -- "$SRC" "$TST")
if [ -n "$dirty" ]; then
	echo "ДЕРЕВО ГРЯЗНОЕ В ЗАТРОНУТЫХ ФАЙЛАХ — запускать на закоммиченном:"; echo "$dirty"; exit 2
fi

run() { # имя
	local name="$1" out
	out=$(cd game && timeout 600 "$G" --headless --path . -s addons/gdunit4/bin/GdUnitCmdTool.gd \
		--ignoreHeadlessMode -c -a "$TEST" 2>&1 \
		| sed 's/\x1b\[[0-9;]*m//g' | grep -E "^Statistics:" | tail -1 \
		| sed -E 's/(.*orphans \|).*/\1/')
	echo "$name: ${out:-<нет сводки: прогон упал до сводки — тоже красный>}"
	case "$out" in
	*"0 errors | 0 failures"*)
		echo "  !! ЗЕЛЁНЫЙ МУТАНТ — гейт не ловит"
		FAILED=1
		;;
	esac
	git checkout -- "$SRC"
}

# Якоря содержат двойные кавычки и `%d` — передаются через окружение, чтобы
# оболочка и python не спорили за экранирование.
sub() { # python-тело: FIG -> TO
	python3 - "$1" <<'PY'
import os, sys, pathlib
p = pathlib.Path(sys.argv[1]); s0 = p.read_text(encoding="utf-8")
s = s0.replace(os.environ["FIG"], os.environ["TO"])
assert s != s0, "МУТАЦИЯ НЕ ПРИМЕНИЛАСЬ: %s" % sys.argv[1]
p.write_text(s, encoding="utf-8")
PY
}

# M1 — скрытые метки карточки возвращены на экран: рисовать нечем.
FIG='				ph.visible = false' TO='				ph.visible = true' sub "$SRC"
run M1

# M2 — имя стека не пишется: карточка заполненная, но безымянная.
FIG='			nm.text = str(army.army[i].get_display_name()) if filled else ""' \
TO='			nm.text = ""' sub "$SRC"
run M2

# M3 — численность показывается и в пустом слоте: ноль вместо «нет стека».
FIG='			ct.visible = filled' TO='			ct.visible = true' sub "$SRC"
run M3

# M4 — иконка показывается и в пустом слоте: пустая рамка вместо «нет стека».
FIG='			ic.visible = filled' TO='			ic.visible = true' sub "$SRC"
run M4

# M5 — строка уровня возвращена: «Уровень:» без числа или с нулём (T-251).
FIG='		lv.visible = false' TO='		lv.visible = true' sub "$SRC"
run M5

echo "Мутации: 5, красных ожидалось 5, провалов: $FAILED"
exit "$FAILED"

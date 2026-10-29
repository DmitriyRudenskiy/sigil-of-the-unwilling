#!/usr/bin/env bash
# Мутационная батарея зон переноса экрана «Герой» (T-257).
#
# Что под защитой. Полоса маны со школой (BandMana) и колонка навыков с
# построениями (BandSkills) стоят внешним краем впритык к прямоугольнику камня
# (`HeroLayout.BLOCKS`). Рамка камня `panel_stone` — 9-slice с марджином 40 px
# (носитель — `assets/ui/hero/MANIFEST.json`): в этой полосе лежат и латунная
# линия, и угловой орнамент. Без внутреннего отступа зона стоит на рамке, а со
# знаком наружу — вообще на пергаменте за камнем: «полоса маны на пергаментном
# листе», «строки навыков уходят за правый край» из тикета.
#
# Гард читает MANIFEST (носитель марджина рамки) и сравнивает фактические
# прямоугольники зоны и её детей с внутренней границей камня, поэтому мутанты —
# не про сам факт отступа, а про его знак, стороны, величину и наличие:
#
#   M1 — знак вывернут (историческое состояние 16224d78: offset_left = −14);
#   M2 — отступа нет вовсе (зона впритык к прямоугольнику камня);
#   M3 — отступ только сверху, внешние стороны оставлены на рамке;
#   M4 — отступ вдвое меньше марджина (символический, а не по носителю).
#
# Почему мутантов четыре: гард бессилен, если он проверяет «отступ вообще
# есть», — половина из них проходит такой тест. Проверяется принадлежность
# грани, а не наличие числа.
#
# Сцена — генерируемая: после правки генератора обязателен перегенерационный
# шаг, иначе тест читает старый .tscn и остаётся зелёным.
#
# Запуск: bash game/tools/mut_hero_bands.sh   (из корня репо, дерево чистое)
set -u
G=${GODOT_BIN:-/home/user/.local/bin/godot}
TEST=res://tests/unit/ui/test_inventory_grid.gd
GEN=game/scripts/build/gen_inventory_scene.gd
SCENE=game/scenes/ui/artifact_inventory_screen.tscn
FAILED=0

# Батарея перезаписывает свои файлы (`git checkout --`), поэтому чужая
# незакоммиченная работа в них — повод не начинать.
dirty=$(git status --porcelain -- "$GEN" "$SCENE" game/tests/unit/ui/test_inventory_grid.gd)
if [ -n "$dirty" ]; then
	echo "ДЕРЕВО ГРЯЗНОЕ В ЗАТРОНУТЫХ ФАЙЛАХ — запускать на закоммиченном:"; echo "$dirty"; exit 2
fi

run() { # имя, тест
	local name="$1" test="$2"
	local out
	(cd game && timeout 300 "$G" --headless --path . -s res://scripts/build/gen_inventory_scene.gd \
		>/dev/null 2>&1)
	out=$(cd game && timeout 600 "$G" --headless --path . -s addons/gdunit4/bin/GdUnitCmdTool.gd \
		--ignoreHeadlessMode -c -a "$test" 2>&1 \
		| sed 's/\x1b\[[0-9;]*m//g' | grep -E "^Statistics:" | tail -1 \
		| sed -E 's/(.*orphans \|).*/\1/')
	echo "$name: ${out:-<нет сводки: прогон упал до сводки — тоже красный>}"
	case "$out" in
	*"0 errors | 0 failures"*)
		echo "  !! ЗЕЛЁНЫЙ МУТАНТ — гейт не ловит"
		FAILED=1
		;;
	esac
	git checkout -- "$GEN" "$SCENE"
}

mutate() { # файл, python-выражение
	python3 - "$1" "$2" <<'PY'
import sys, pathlib
path, body = sys.argv[1], sys.argv[2]
p = pathlib.Path(path); s0 = p.read_text(encoding="utf-8"); s = s0
exec(body)
assert s != s0, "МУТАЦИЯ НЕ ПРИМЕНИЛАСЬ: %s" % path
p.write_text(s, encoding="utf-8")
PY
}

# M1 — знак вывернут: отступ растёт наружу, зона лезет за камень с другой стороны.
mutate "$GEN" 's = s.replace(
	"var signed := v if side in [\"left\", \"top\"] else -v",
	"var signed := -v if side in [\"left\", \"top\"] else v")'
run M1 "$TEST"

# M2 — отступ снят: левый край полосы маны совпадает с краем камня.
mutate "$GEN" 'for a in ("{\"left\": stone_edge, \"top\": stone_edge}",
		"{\"right\": stone_edge, \"top\": stone_edge}"):
	s = s.replace(a, "{}")'
run M2 "$TEST"

# M3 — внешние стороны забыты: верх убран за рамку, край — нет.
mutate "$GEN" 'for a in ("{\"left\": stone_edge, \"top\": stone_edge}",
		"{\"right\": stone_edge, \"top\": stone_edge}"):
	s = s.replace(a, "{\"top\": stone_edge}")'
run M3 "$TEST"

# M4 — отступ не по носителю: половина марджина рамки.
mutate "$GEN" 's = s.replace(
	"var stone_edge := _kit_margin(\"panel_stone\")",
	"var stone_edge := _kit_margin(\"panel_stone\") / 2")'
run M4 "$TEST"

echo "ИТОГ: $([ $FAILED -eq 0 ] && echo 'все мутанты красные' || echo 'ЕСТЬ ЗЕЛЁНЫЕ МУТАНТЫ')"
exit $FAILED

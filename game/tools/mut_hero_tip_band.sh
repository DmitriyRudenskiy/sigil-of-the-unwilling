#!/usr/bin/env bash
# Мутационная батарея геометрии панели предмета (T-271).
#
# Что под защитой. Панель предмета («Equip»/«Remove»/«Dispose» + описание)
# обязана жить в поле сумки и не ложиться на куклу: прежний rect ставил плиту
# над полем куклы, и три её рамки оказывались под открытой подсказкой — слот
# под ней нельзя было выбрать. Защита состоит из четырёх частей, и у каждой
# свой мутант:
#
#   M1 — дом панели в таблице геометрии (`HeroLayout.BLOCKS["ItemTip"]`);
#   M2 — отжимание плиты от предмета в скрипте экрана (`_layout_tip`);
#   M3 — поле сумки в координатах канвы (`HeroLayout.bag_canvas`);
#   M4 — перенос rect'а в доли якорей (`_set_anchors_to_canvas`).
#
# Почему мутантов четыре, а не один: таблица задаёт дом, рантайм — отжимание, а
# живой тест читает фактические прямоугольники после layout. Дом, возвращённый
# над куклой (M1), живой тест не замечает — плита всё равно уезжает в поле, —
# поэтому у дома есть отдельная сверка таблицы с кадром фигуры.
#
# Честная лакуна: середина поля плитой перекрывается и мутантом не проверяется —
# это не дефект, а цена размера (панель 460×240 при поле 720×354). Размер
# тикет править запретил («правится местом, не размером»).
#
# Запуск: bash game/tools/mut_hero_tip_band.sh   (из корня репо, дерево чистое)
set -u
G=${GODOT_BIN:-/home/user/.local/bin/godot}
TIP=res://tests/unit/ui/test_inventory_grid.gd
SCREEN=game/scripts/ui/artifact_inventory_screen.gd
LAYOUT=game/scripts/ui/hero_layout.gd
FAILED=0

run() { # имя, тест
	local name="$1" test="$2"
	local out
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
	git checkout -- "$SCREEN" "$LAYOUT"
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

# M1 — дом панели возвращён в прежнее место: над полем куклы.
mutate "$LAYOUT" 's = s.replace(
	"\"ItemTip\": Rect2(831, 629, 460, 240)",
	"\"ItemTip\": Rect2(571, 300, 460, 240)")'
run M1 "$TIP"

# M2 — плита больше не отжимается от предмета: всегда стоит дома.
mutate "$SCREEN" 's = s.replace(
	"\tif cell.size.x > 0.0:",
	"\tif cell.size.x < 0.0:")'
run M2 "$TIP"

# M3 — полем сумки объявлен кадр фигуры: плита едет по кукле.
mutate "$LAYOUT" 's = s.replace(
	"\tvar bag: Rect2 = BLOCKS[\"Bag\"]\n\treturn Rect2(bag.position + stone.position, bag.size)",
	"\tvar bag: Rect2 = BLOCKS[\"Figure\"]\n\treturn Rect2(bag.position + stone.position, bag.size)")'
run M3 "$TIP"

# M4 — вертикальные доли считаются от ширины канвы: плита уезжает за поле.
mutate "$SCREEN" 's = s.replace(
	"\tnode.anchor_top = r.position.y / c.y",
	"\tnode.anchor_top = r.position.y / c.x")'
run M4 "$TIP"

echo "ИТОГ: $([ $FAILED -eq 0 ] && echo 'все мутанты красные' || echo 'ЕСТЬ ЗЕЛЁНЫЕ МУТАНТЫ')"
exit $FAILED

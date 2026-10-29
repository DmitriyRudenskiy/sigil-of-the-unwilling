#!/usr/bin/env bash
# Мутационная батарея гейта «экран героя показывает надетое» (T-254, T-294, T-295).
# Каждый мутант обязан покраснить свой тест; зелёный мутант = дыра гейта.
#
# Что под защитой. Писатель строк «Надето» (M1–M4), рамки куклы (M5–M6) и пути
# писателя центральной полосы (M7–M8), гигиена подписи (M9). Все три дефекта
# жили молча, потому что единственный сторож в этих местах —
# `get_node_or_null(...) is Label`: отсутствующий узел и незаполненный узел
# выглядят одинаково. Отсюда и мутанты — каждый либо убирает запись, либо
# возвращает путь/сверку, которые ничего не находили.
#
# M4 (обратный порядок рамок) ловится тестом порядка, а не тестом содержимого:
# именно так и задумано — набор надетого при перестановке не меняется.
#
# Честная лакуна: переполнение (11 надетых вещей при 7 строках) мутантом не
# проверяется — писатель берёт строки со сцены, и «лишние» вещи он не прячет, а
# просто не доходит до них. Покрытие — тест `test_more_equipment_than_rows_...`,
# он же единственное место, где число строк прочитано со сцены.
#
# Запуск: bash game/tools/mut_equip_rows.sh   (из корня репо, дерево чистое)
# Классификатор читает строку Statistics целиком: мутант может и не дать тестам
# собраться (ошибка компиляции скрипта), это тоже красный, но в отчёте он подписан
# иначе, чем «тест поймал дефект» — иначе батарея не отличает защиту от поломки.
set -u
G=${GODOT_BIN:-/home/user/.local/bin/godot}
# Оба мутанта пишут в один тест-файл: 14 кейсов списка/куклы/полосы живут в
# test_inventory_actions.gd (сводный файл — требование merge_files-рэтчета testmap,
# отдельный файл под уже оскоплённым носителем его красит).
ROWS=res://tests/unit/ui/test_inventory_actions.gd
BANDS=res://tests/unit/ui/test_inventory_actions.gd
SCREEN=game/scripts/ui/artifact_inventory_screen.gd
LAYOUT=game/scripts/ui/hero_layout.gd
FAILED=0

run() { # имя, тест
	# Классификатор читает строку Statistics целиком (мутант вправе уронить прогон
	# до сводки — это тоже красный, но подписан иначе, чем «тест поймал дефект»).
	# Хвост строки — цветовой тег кода выхода GdUnit («PASSED 253ms»): рядом с
	# красным мутантом он читается как «тест прошёл», поэтому отрезаем.
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

# M1 — писатель строк вообще не вызывается (довольно было собрать сцену).
mutate "$SCREEN" 's = s.replace("\t_refresh_equip_list()\n", "")'
run M1 "$ROWS"

# M2 — рамка строки видима всегда: пустые строки снова рисуются пустыми камнями.
mutate "$SCREEN" 's = s.replace("\t\trow.visible = art != null", "\t\trow.visible = true")'
run M2 "$ROWS"

# M3 — строка есть, имени предмета нет (рамка без подписи).
mutate "$SCREEN" 's = s.replace("\t\t\tlbl.text = art.display_name if art != null else \"\"", "\t\t\tlbl.text = \"\"")'
run M3 "$ROWS"

# M4 — порядок строк обратный порядку рамок куклы.
mutate "$SCREEN" 's = s.replace("\tfor f in HeroLayout.DOLL_SLOTS_N:", "\tfor f in range(HeroLayout.DOLL_SLOTS_N - 1, -1, -1):")'
run M4 "$ROWS"

# M5 — писатель куклы снова ищет иконку внутри рамки (узла с таким путём нет).
mutate "$SCREEN" 's = s.replace("const SLOT_ICON := \"Center/Window/Sheet/Stone/Doll/DollIcon_%d\"", "const SLOT_ICON := \"Center/Window/Sheet/Stone/Doll/DollSlot_%d/EquipIcon\"")'
run M5 "$ROWS"

# M6 — карта «слот → рамка» сравнивает StringName-метку с enum-целым: не срабатывает никогда.
mutate "$LAYOUT" 's = s.replace("String(Artifact.Slot.find_key(slot))", "String()")'
run M6 "$ROWS"

# M7 — путь писателя маны снова со старым префиксом переезда D-280.
mutate "$SCREEN" 's = s.replace("Center/Window/Sheet/BandMana/Mana_lbl", "Center/Window/Sheet/Stone/BandMana/Mana_lbl")'
run M7 "$BANDS"

# M8 — то же для полосы навыков.
mutate "$SCREEN" 's = s.replace("Center/Window/Sheet/BandSkills/Skills_lbl", "Center/Window/Sheet/Stone/BandSkills/Skills_lbl")'
run M8 "$BANDS"

# M9 — подпись строки не обрезается: длинное имя переносится на вторую строку.
mutate "$SCREEN" 's = s.replace("\t\t\tlbl.clip_text = true", "\t\t\tlbl.clip_text = false")'
run M9 "$ROWS"

echo "ИТОГ: $([ $FAILED -eq 0 ] && echo 'все мутанты красные' || echo 'ЕСТЬ ЗЕЛЁНЫЕ МУТАНТЫ')"
exit $FAILED

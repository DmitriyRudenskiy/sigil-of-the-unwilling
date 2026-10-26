#!/usr/bin/env bash
# Мутационная батарея гейта «экран артефактов отвечает на выбор игрока»
# (ui-mockup-parity 6.4/6.6/6.7). Каждый мутант обязан покраснить
# test_inventory_actions.gd; зелёный мутант = дыра гейта.
#
# Мутации бьют по всем веткам, которые чинил срез: выбор предмета (M1, M10), guard
# неприменимости (M2), «Remove» по выбранному слоту (M4), «Dispose» по выбранному
# предмету (M3), видимость маркеров (M5 — не рисуется, M6 — рисуется прозрачным),
# пересчёт характеристик (M7), подписка на инвентарь (M8), приём клика ячейкой (M9).
#
# Честная лакуна: `Exp_val` мутантом не проверяется — у тестового героя опыт и есть 0,
# так что литеральная «0» прошла бы зелёной. Поле покрыто только чтением кода состояния
# кадра (UX-REVIEW, sigil-reserve/inventory-t218), тестом — нет.
#
# Запуск: bash game/tools/mut_inventory_marks.sh   (из корня репо, дерево чистое)
set -u
G=${GODOT_BIN:-/home/user/.local/bin/godot}
TEST=res://tests/unit/ui/test_inventory_actions.gd
SCREEN=game/scripts/ui/artifact_inventory_screen.gd
FAILED=0

run() {
	local name="$1"
	local out
	out=$(cd game && timeout 600 "$G" --headless --path . -s addons/gdunit4/bin/GdUnitCmdTool.gd \
		--ignoreHeadlessMode -c -a "$TEST" 2>&1 | grep -oE "0 errors \| [0-9]+ failures" | tail -1)
	echo "$name: $out"
	case "$out" in
	"0 errors | 0 failures")
		echo "  !! ЗЕЛЁНЫЙ МУТАНТ — гейт не ловит"
		FAILED=1
		;;
	esac
	git checkout -- "$SCREEN"
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

# M1 — надевается первый предмет сумки, а не выбранный (историческое поведение).
mutate "$SCREEN" 's = s.replace("\treturn bp[_selected_bp]", "\treturn bp[0]")'
run M1

# M2 — guard неприменимости снят: «Equip» действует и когда некуда.
mutate "$SCREEN" 's = s.replace("\tif not inv.can_equip(art):\n\t\t# 6.4:", "\tif false:\n\t\t# 6.4:")'
run M2

# M3 — «Dispose» снова ест нулевую ячейку.
mutate "$SCREEN" 's = s.replace("\tvar idx: int = inv.backpack.find(art)", "\tvar idx: int = 0")'
run M3

# M4 — «Remove» снова снимает слот по умолчанию.
mutate "$SCREEN" 's = s.replace("_selected_slot):", "Artifact.Slot.WEAPON):").replace("inv.unequip(_selected_slot)", "inv.unequip(Artifact.Slot.WEAPON)")'
run M4

# M5 — маркер создаётся, но никогда не показывается.
mutate "$SCREEN" 's = s.replace("\tframe.visible = on", "\tframe.visible = false")'
run M5

# M6 — маркер показывается полностью прозрачным (ровно то, что сгубило первую версию).
mutate "$SCREEN" 's = s.replace("\t\t\tstrip.color = color", "\t\t\tstrip.color = Color(color, 0.0)")'
run M6

# M7 — панель характеристик не пересобирается после действия.
mutate "$SCREEN" 's = s.replace("\t_refresh_stats()\n\t_rebuild_equipped()", "\t_rebuild_equipped()")'
run M7

# M8 — экран не подписывается на инвентарь: подобранный в мире предмет не виден.
mutate "$SCREEN" 's = s.replace("\t_build()\n\t_watch_inventory()", "\t_build()")'
run M8

# M9 — ячейка не принимает мышь: клик по предмету не доходит до выбора.
mutate "$SCREEN" 's = s.replace("cell.mouse_filter = Control.MOUSE_FILTER_STOP", "cell.mouse_filter = Control.MOUSE_FILTER_IGNORE")'
run M9

# M10 — выбор не запоминается (публичный API есть, состояния нет).
mutate "$SCREEN" 's = s.replace("\t_selected_bp = idx\n\t_refresh_backpack()", "\t_refresh_backpack()")'
run M10

echo "ИТОГ: $([ $FAILED -eq 0 ] && echo 'все мутанты красные' || echo 'ЕСТЬ ЗЕЛЁНЫЕ МУТАНТЫ')"
exit $FAILED

#!/usr/bin/env bash
# Мутационная батарея инварианта проводки главного меню (T-299, носитель
# точки входа загрузок — T-307).
#
# Что под защитой. `tests/unit/ui/test_main_menu_structure.gd` измеряет три вещи:
# у каждого `func _on_*` в `scripts/ui/main_menu.gd` есть проводка (MA), снятый
# блок выбора героя не возвращается (MB), а список разрешённого молчания не протух
# (MC). Отдельно — санитарная граница: если файл-носитель не читается, проверки
# обязаны покраснеть, а не сойтись к зелёному «сирот нет» (MD).
#
# Почему инвариант вообще появился. Месяц в меню жил блок выбора героя: сторожем
# стоял `get_node_or_null("HeroSelection")`, узла в сцене не было, сигнал
# `hero_selected` не эмитился никогда. Отсутствие узла, незаполненное поле и
# несоединённый обработчик выглядят одинаково — молчанием; молчание и есть дефект.
#
# Запуск: bash game/tools/mut_menu_wiring.sh   (из корня репо, дерево чистое)
# Классификатор читает строку Statistics целиком. Прогон без сводки — красный
# (мутант вправе не дать скрипту собраться), а не «зелёный мутант»: зелёным
# считается только `0 errors | 0 failures`. Ровно на этом месте ручная проверка
# до коммита сначала ошиблась: переименование всех обработчиков обрывало прогон
# на ошибке разбора, а классификатор-черновик прочитал это как «никто не
# покраснел».
set -u
G=${GODOT_BIN:-/home/user/.local/bin/godot}
SRC=game/scripts/ui/main_menu.gd
TESTF=game/tests/unit/ui/test_main_menu_structure.gd
TEST=res://tests/unit/ui/test_main_menu_structure.gd
FAILED=0

git diff --quiet -- "$SRC" "$TESTF" || {
	echo "дерево по $SRC/$TESTF грязное — батарея не запускается"; exit 2; }

restore() { git checkout -- "$SRC" "$TESTF"; }

run() { # имя, ожидаемая красная проверка
	local name="$1" expect="$2" out stat
	out=$(cd game && timeout 600 "$G" --headless --path . -s addons/gdunit4/bin/GdUnitCmdTool.gd \
		--ignoreHeadlessMode -c -a "$TEST" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
	stat=$(printf '%s\n' "$out" | grep -E "^Statistics:" | tail -1 | sed -E 's/(.*orphans \|).*/\1/')
	local red
	red=$(printf '%s\n' "$out" | sed -n 's/.*> \([A-Za-z0-9_]*\) FAILED.*/\1/p' | sort -u | tr '\n' ' ')
	echo "$name: ${stat:-<нет сводки: прогон упал до сводки — тоже красный>} | красные: ${red:-нет}"
	case "$stat" in
	*"0 errors | 0 failures"*)
		echo "  !! ЗЕЛЁНЫЙ МУТАНТ — гейт не ловит"; FAILED=1 ;;
	*)
		case "$red" in
		*"$expect"*) : ;;
		*) echo "  !! покраснело не то: ожидался $expect"; FAILED=1 ;;
		esac ;;
	esac
	restore
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

# MA — обработчик без проводки (ровно та форма, в которой жил снятый блок).
mutate "$SRC" 's += "\nfunc _on_zombie() -> void:\n    pass\n"'
run MA test_main_menu_every_handler_is_connected

# MB — у снятого блока вернулся сигнал: код снова обещает API, которого сценой не обеспечит.
mutate "$SRC" 's = s.replace("func _ready() -> void:", "signal hero_selected(hero_name: String)\n\nfunc _ready() -> void:")'
run MB test_main_menu_hero_selection_api_is_gone

# MC — проводка у `_on_load_game` появилась, а строка в списке молчания осталась:
# allowlist обязан гнить в обе стороны, иначе он превращается в кладбище.
mutate "$SRC" 's = s.replace("    _save_load_screen.delete_requested.connect(_on_slot_delete_requested)", "    _save_load_screen.delete_requested.connect(_on_slot_delete_requested)\n    _save_load_screen.load_requested.connect(_on_load_game)")'
run MC test_main_menu_silence_allowlist_is_not_stale

# MD — носитель не читается (переезд/опечатка в пути): проверки должны покраснеть,
# а не сложиться в зелёное «сирот нет».
mutate "$TESTF" 's = s.replace("res://scripts/ui/main_menu.gd", "res://scripts/ui/main_menu_absent.gd")'
run MD test_main_menu_every_handler_is_connected

echo "ИТОГ: $([ $FAILED -eq 0 ] && echo 'все мутанты красные' || echo 'ЕСТЬ ЗЕЛЁНЫЕ МУТАНТЫ')"
exit $FAILED

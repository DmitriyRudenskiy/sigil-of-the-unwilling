#!/usr/bin/env bash
# Мутационная батарея T-228 (носитель варианта темы и пластины подсказки).
#
# Краснеть должны четыре файла: test_theme_source_scan.gd (литеральные присваивания
# `theme_type_variation` в production), test_theme_variation_matrix.gd (секции темы =
# тип/вариант/сирота + «движок читает нативный не-классовый тип»),
# test_kitchen_sink_theme_carrier.gd (живое дерево витрины + механизм подсказки),
# test_theme_override_reader.gd (типы темы вне ClassDB).
#
# Мутанты собраны вокруг самой дыры T-228: присваивание имени, которого нет в теме
# (M1 — молчаливое ничего), мёртвое самоприсваивание типа узла в сцене (M2) и в
# генераторе сцен (M3), настоящая сирота темы, которую гард обязан не проглотить после
# смягчения критерия (M4), пластина подсказки, которую движок не читает (M5), снятый
# механизм подсказки (M6), вариант чужого базового типа на живом узле (M7), возврат
# ложного критерия «нативный тип == класс» в самый гард (M8) и снятие секции пластины с
# раздела §4.8 — регресс кадра, пойманный ux-review (M9).
#
# Важно про M1/M9: «не зарегистрирован как вариант» ≠ «мёртвое». Замер кадра показал,
# что TooltipPanel/TooltipLabel на витрине живые, поэтому мутант, который их СНИМАЕТ,
# обязан краснеть (M9), а мутант, который делает вид, краснит отсутствие имени в теме.
#
# Запуск: bash game/tools/mut_theme_variations.sh   (из корня репо, дерево чистое)
set -u
G=${GODOT_BIN:-/home/user/.local/bin/godot}
TESTS=(-a res://tests/unit/ui/test_theme_source_scan.gd
	-a res://tests/unit/ui/test_theme_variation_matrix.gd
	-a res://tests/unit/ui/test_kitchen_sink_theme_carrier.gd
	-a res://tests/unit/ui/test_theme_override_reader.gd)
THEME=game/assets/theme/game_theme.tres
SINK=game/scripts/ui/kitchen_sink.gd
SCENE=game/scenes/ui/artifact_inventory_screen.tscn
GEN=game/scripts/build/gen_inventory_scene.gd
MATRIX=game/tests/unit/ui/test_theme_variation_matrix.gd
FAILED=0

run() { # имя, файл-мишень (его и возвращаем)
	local name="$1"
	local out
	out=$(cd game && timeout 900 "$G" --headless --path . -s addons/gdunit4/bin/GdUnitCmdTool.gd \
		--ignoreHeadlessMode -c "${TESTS[@]}" 2>&1 | grep -oE "0 errors \| [0-9]+ failures" | tail -1)
	echo "$name: $out"
	case "$out" in
	"" | *"0 errors | 0 failures"*)
		echo "  !! ЗЕЛЁНЫЙ (или нечитаемый) МУТАНТ — гейт не ловит"
		FAILED=1
		;;
	esac
	git checkout -- "$2"
}

mutate() { # файл, python-выражение; неприменившийся мутант — падение батареи
	python3 - "$1" "$2" <<'PY'
import sys, pathlib
path, body = sys.argv[1], sys.argv[2]
p = pathlib.Path(path); s0 = p.read_text(encoding="utf-8"); s = s0
exec(body)
assert s != s0, "МУТАНТ НЕ ПРИМЕНИЛСЯ: %s" % path
p.write_text(s, encoding="utf-8")
PY
}

# M1 — настоящая дыра этого класса: литерала нет ни среди вариантов, ни среди типов
# темы (узел остаётся на базовом типе, автор думает, что перекрасил).
mutate "$SINK" '
old = "\tpanel.theme_type_variation = \"TooltipPanel\""
assert s.count(old) == 1, "присваивание пластины витрины не найдено: %d" % s.count(old)
s = s.replace(old, "\tpanel.theme_type_variation = \"GhostPanel\"", 1)
'
run M1 "$SINK"

# M9 — регресс, пойманный ux-review: секцию пластины подсказки сняли с раздела §4.8
# «как не-вариант», и золотая рамка ушла с единственного кадра-доказательства К-6.
mutate "$SINK" '
old = "\tpanel.theme_type_variation = \"TooltipPanel\"\n"
assert old in s, "присваивание пластины витрины не найдено"
s = s.replace(old, "", 1)
'
run M9 "$SINK"

# M2 — сценевое самоприсваивание имени базового типа (кнопка = вариант "Button"):
# резолвится ровно тот же набор стилей, вид не меняется (проверено: 0 px дельты).
mutate "$SCENE" '
old = "text = \"×\"\n"
assert s.count(old) == 1, "кнопка Close не найдена одна: %d" % s.count(old)
s = s.replace(old, "text = \"×\"\ntheme_type_variation = &\"Button\"\n", 1)
'
run M2 "$SCENE"

# M3 — тот же литерал, но через генератор сцен (esc-кавычки): скан обязан читать и их.
mutate "$GEN" '
old = "+ \"text = \\\"×\\\"\\n\", uid)"
assert s.count(old) == 1, "строка генератора не найдена: %d" % s.count(old)
s = s.replace(old, "+ \"text = \\\"×\\\"\\ntheme_type_variation = &\\\\\"GhostVariant\\\\\"\\n\", uid)", 1)
'
run M3 "$GEN"

# M4 — настоящая сирота темы: секция без base_type и не тип. Гард после смягчения
# критерия (T-228) обязан её покраснить, иначе «не сирота == что угодно» = молчание.
mutate "$THEME" '
old = "TooltipPanel/styles/panel = SubResource(\"StyleBoxFlat_tooltip\")"
assert old in s, "секция TooltipPanel не найдена"
s = s.replace(old, old + "\nGhostPlate/styles/panel = SubResource(\"StyleBoxFlat_tooltip\")", 1)
'
run M4 "$THEME"

# M5 — пластина подсказки переименована: движок такого пункта у типа не знает,
# и наша секция повисает непрочитанной (пиксел подсказки уедет на дефолт).
mutate "$THEME" '
old = "TooltipPanel/styles/panel = SubResource(\"StyleBoxFlat_tooltip\")"
assert old in s, "секция TooltipPanel не найдена"
s = s.replace(old, "TooltipPanel/styles/plastina = SubResource(\"StyleBoxFlat_tooltip\")", 1)
'
run M5 "$THEME"

# M6 — механизм подсказки снят: §4.8 снова рисует имитацию (панель без tooltip_text).
mutate "$SINK" '
old = "\tpanel.tooltip_text = \"Значение: 60\"\n"
assert old in s, "tooltip_text витрины не найден"
s = s.replace(old, "", 1)
'
run M6 "$SINK"

# M7 — вариант чужого базового типа на живом узле (Panel-вариант на Label): литерал
# зарегистрирован и сканом пропускается, краснить обязано дерево витрины.
mutate "$SINK" '
old = "\t\tl.theme_type_variation = variation"
assert s.count(old) == 1, "присваивание _label не найдено: %d" % s.count(old)
s = s.replace(old, "\t\tl.theme_type_variation = \"PanelChip\"", 1)
'
run M7 "$SINK"

# M8 — возврат ложного критерия в гард: «нативный тип == класс ClassDB». TooltipPanel
# снова объявляется сиротой, допуск пуст — красное. Мутация самого гейта: без неё
# «исправили критерий» ничего не стоит (прецедент M6 в mut_form_row.sh).
mutate "$MATRIX" '
old = "\tif ClassDB.class_exists(StringName(section)):\n\t\treturn true\n\treturn ThemeDB.get_default_theme().get_type_list().has(section)"
assert old in s, "критерий _is_theme_type не найден"
s = s.replace(old, "\treturn ClassDB.class_exists(StringName(section))", 1)
'
run M8 "$MATRIX"

echo "ИТОГ: $([ "$FAILED" -eq 0 ] && echo "все мутанты красные (гейт держит)" || echo "ЕСТЬ ЗЕЛЁНЫЕ — гейт дырявый")"
git status --porcelain | grep -v "^??" || echo "дерево чистое"

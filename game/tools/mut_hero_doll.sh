#!/usr/bin/env bash
# Мутационная батарея кадра куклы экрана «Герой» (T-258).
#
# Что под защитой. `Figure` — TextureRect с арт `hero/figure.png` (428×478),
# адрес блока — `HeroLayout.BLOCKS["Figure"]` = E1–G6, т.е. 427×477 локальных
# px камня (54 % его высоты). Тикет утверждал, что фигура «стоит вверху блока и
# по высоте вдвое меньше макета»; это было верно про заглушку и снято T-249.
# Гард проверяет следствие — что после layout узел совпадает со своим адресом,
# что текстура рисуется во весь узел и что чернила занимают саму текстуру.
#
# Мутанты бьют по четырём разным причинам «куклы меньше блока»:
#   M1 — адрес урезан пополам по высоте (ровно симптом тикета);
#   M2 — адрес сдвинут при сохранённом размере (узел не там);
#   M3 — stretch_mode = STRETCH_SCALE (арт растягивается вместо сохранения
#        пропорций — обратный дефект, тот же узел);
#   M4 — expand_mode = KEEP_SIZE (минимумом узла становится размер текстуры,
#        якоря перестают слушаться — класс урока T-255 про custom_minimum_size).
#
# Чего среди мутантов нет: доли чернил в текстуре (fill >= 0.85). Её регрессия
# приходит со сменой арта, а в репо нет ассета с прозраческими полями, которым
# можно было бы подменить figure.png; подделывать его бинарником батарея не
# может, не трогая носители. Это зазор гарда, а не зелёный мутант.
#
# Урок первого прогона. M1 и M2 сначала были зелёными — не из-за гарда, а из-
# за самого теста: первая проверка стояла `assert_bool(cond)\
# .override_failure_message(...)` без `.is_true()`, а в GdUnit assert без
# check-метода не проверяет ничего. Мутанты поймали это раньше гейта
# (`scripts/ci2_vacuous_asserts.py` исполняется в game/run_tests.sh и указал
# ту же строку).
#
# Сцена — генерируемая: после правки генератора обязателен перегенерационный
# шаг, иначе тест читает старый .tscn и остаётся зелёным.
#
# Запуск: bash game/tools/mut_hero_doll.sh   (из корня репо, дерево чистое)
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

# Якоря содержат и двойные кавычки, и обратные слеши — они передаются через
# окружение, чтобы оболочка и python не спорили за экранирование.
sub() { # python-тело: FIG -> TO
	python3 - "$1" <<'PY'
import os, sys, pathlib
p = pathlib.Path(sys.argv[1]); s0 = p.read_text(encoding="utf-8")
s = s0.replace(os.environ["FIG"], os.environ["TO"])
assert s != s0, "МУТАЦИЯ НЕ ПРИМЕНИЛАСЬ: %s" % sys.argv[1]
p.write_text(s, encoding="utf-8")
PY
}

# M1 — кадр урезан пополам по высоте: кукла в верхней половине блока.
FIG='_anchor_within("Figure", S)' \
TO='_anchor_rect(Rect2(_L.BLOCKS["Figure"].position, _L.BLOCKS["Figure"].size * Vector2(1, 0.5)), S)' \
	sub "$GEN"
run M1 "$TEST"

# M2 — размер верный, адрес сдвинут на полублок: узел не в своём месте.
FIG='_anchor_within("Figure", S)' \
TO='_anchor_rect(Rect2(_L.BLOCKS["Figure"].end - _L.BLOCKS["Figure"].size / 2.0, _L.BLOCKS["Figure"].size), S)' \
	sub "$GEN"
run M2 "$TEST"

# M3 — пропорции сброшены: арт растягивается по узлу вместо KEEP_ASPECT_CENTERED.
FIG='\nstretch_mode = 5\nmouse_filter = 2\n' \
TO='\nstretch_mode = 0\nmouse_filter = 2\n' \
	sub "$GEN"
run M3 "$TEST"

# M4 — якоря перестают слушаться: минимум узла = размер текстуры.
mutate "$GEN" 's = s.replace("\t\textra += \"expand_mode = 1\\n\"", "\t\textra += \"expand_mode = 0\\n\"")'
run M4 "$TEST"

echo "ИТОГ: $([ $FAILED -eq 0 ] && echo 'все мутанты красные' || echo 'ЕСТЬ ЗЕЛЁНЫЕ МУТАНТЫ')"
exit $FAILED

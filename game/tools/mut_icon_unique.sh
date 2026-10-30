#!/usr/bin/env bash
# Мутационная батарея инварианта «набор иконок — набор» (T-235).
# Каждый мутант обязан покраснить свой тест; зелёный мутант = дыра гейта.
#
# Что под защитой. `tests/unit/assets/test_artifact_icons_unique.gd` держит три
# правды: область скана живая (M3), у двух id не один растр на двоих (M1), у
# каждой иконки есть видимые пиксели (M2). Исторический дефект — 12 групп дублей
# (процедурный генератор рисовал форму по слоту): 60 файлов, 31 уникальный
# рисунок. Ни `test_rows_and_icons_are_one_to_one`, ни `test_forgeable_icons`
# этот дефект не краснят: файлы на месте, имена сходятся, шесть кузнечных id
# непустые.
#
# Честная лакуна: батарея трогает три файла и не проверяет, что дубль закрался
# именно через генератор (контура генерации в репо нет — иконки рисует
# `scripts/concept_art/`, а его выход сверяется уже по факту на диске).
#
# Запуск: bash game/tools/mut_icon_unique.sh   (из корня репо, дерево чистое)
set -u
G=${GODOT_BIN:-/home/user/.local/bin/godot}
TEST=game/tests/unit/assets/test_artifact_icons_unique.gd
A=game/assets/artifacts/club.png
B=game/assets/artifacts/stone_axe.png
C=game/assets/artifacts/rune_sword.png
TESTRES=res://tests/unit/assets/test_artifact_icons_unique.gd
FAILED=0

# Батарея разрушает рабочее дерево (перезаписывает байты иконок и константу
# теста). Требует чистого дерева по затрагиваемым путям и их отслеживаемости —
# восстанавливать будем через `git checkout`.
git diff --quiet -- "$A" "$B" "$C" "$TEST" || { echo "дерево грязное — батарея не запускается"; exit 2; }
for f in "$A" "$B" "$C" "$TEST"; do
	git ls-files --error-unmatch "$f" >/dev/null || { echo "$f не отслеживается git — восстанавливать будет нечем"; exit 2; }
done
cp "$TEST" /tmp/mut_icon_unique_backup.gd

restore() {
	git checkout -- "$A" "$B" "$C" "$TEST"
	cmp -s "$TEST" /tmp/mut_icon_unique_backup.gd \
		|| { echo "  !! восстановление разошлось с бэкапом: $TEST"; exit 3; }
}

run() { # имя, что должен покраснить
	local name="$1" why="$2" out
	out=$(cd game && timeout 600 "$G" --headless --path . -s addons/gdunit4/bin/GdUnitCmdTool.gd \
		--ignoreHeadlessMode -c -a "$TESTRES" 2>&1 \
		| sed 's/\x1b\[[0-9;]*m//g' | grep -E "^Statistics:" | tail -1 \
		| sed -E 's/(.*orphans \|).*/\1/')
	echo "$name ($why): ${out:-<нет сводки: прогон упал до сводки — тоже красный>}"
	case "$out" in
	*"0 errors | 0 failures"*)
		echo "  !! ЗЕЛЁНЫЙ МУТАНТ — гейт не ловит"
		FAILED=1
		;;
	esac
	restore
}

# M1 — два id получили один растр: так выглядит вернувшийся дефект «иконка по
# слоту». Красным обязан стать именно тест хеша, а не соседние проверки.
cp "$A" /tmp/mut_icon_unique_A.png
cp "$A" "$B"
run M1 "дубль растра: club == stone_axe"

# M2 — иконка стала полностью прозрачной: файл, размер и хеш образцовые, в игре
# пустая клетка. Красным обязан стать тест видимых пикселей.
cp "$C" /tmp/mut_icon_unique_C.png
python3 - "$C" <<'PY'
import sys
from PIL import Image
Image.new("RGBA", (128, 128), (0, 0, 0, 0)).save(sys.argv[1])
PY
run M2 "прозрачная иконка: rune_sword"

# M3 — путь каталога в тесте разошёлся с реальностью (каталог переехал):
# проверки не находят файлов и зеленеют, ничего не измерив.
python3 - "$TEST" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1]); s0 = p.read_text(encoding="utf-8"); s = s0
s = s.replace('const ICON_DIR := "res://assets/artifacts"',
              'const ICON_DIR := "res://assets/artifactz"')
assert s != s0, "МУТАЦИЯ M3 НЕ ПРИМЕНИЛАСЬ"
p.write_text(s, encoding="utf-8")
PY
run M3 "область скана несуществующая"

rm -f /tmp/mut_icon_unique_A.png /tmp/mut_icon_unique_C.png /tmp/mut_icon_unique_backup.gd
echo "ИТОГ: $([ $FAILED -eq 0 ] && echo 'все мутанты красные' || echo 'ЕСТЬ ЗЕЛЁНЫЕ МУТАНТЫ')"
exit $FAILED

#!/usr/bin/env bash
# Мутационная батарея описи строк экрана «Герой» (T-247).
#
# Что под защитой. game/scenes/ui/artifact_inventory_screen.carriers.csv —
# машиночитаемая опись: строка карты макета §3 (docs/20-ux-hero-screen.md) ↔
# узел сцены ↔ пиксель кита ↔ писатель данных ↔ статус. Опись — единственный
# носитель ответа на вопрос «что на экране есть и чем оно заполняется»; проза
# карты этот ответ описывает, но с кодом не сверяется.
#
# Гард `game/tests/unit/ui/test_inventory_grid.gd` (кейсы test_carrier_*) краснеет
# на: рассогласовании шапки COVERAGE со строками `# TYPE` и со статусами строк,
# на типе макета без строк описи, на пути узла которого нет в сцене, на пикселе
# кита которого нет на диске, на строке без носителя или вне макета без ссылки на
# билет, и на текстуре кита в сцене, которую опись не назвала.
#
# Мутации бьют по каждому из шести утверждений: M1 — шапка врёт о покрытии,
# M2 — путь узла разошёлся со сценой, M3 — ассет разошёлся с диском, M4 — строка
# без носителя осталась без билета, M5 — опись перестала называть узел который
# в сцене рисуется пикселем кита.
#
# Запуск: bash game/tools/mut_hero_carriers.sh   (из корня репо, дерево чистое)
set -u
G=${GODOT_BIN:-/home/user/.local/bin/godot}
TEST=res://tests/unit/ui/test_inventory_grid.gd
CSV=game/scenes/ui/artifact_inventory_screen.carriers.csv
FAILED=0

# Батарея откатывает свои правки через `git checkout --`, поэтому чужая
# незакоммиченная работа в описи — повод не начинать.
dirty=$(git status --porcelain -- "$CSV")
if [ -n "$dirty" ]; then
	echo "ДЕРЕВО ГРЯЗНОЕ В ЗАТРОНУТОМ ФАЙЛЕ — запускать на закоммиченном:"; echo "$dirty"; exit 2
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
	git checkout -- "$CSV"
}

sub() { # python-тело: FIG -> TO (или DEL=1 — выкинуть строку с FIG)
	python3 - "$1" <<'PY'
import os, sys, pathlib
p = pathlib.Path(sys.argv[1]); s0 = p.read_text(encoding="utf-8")
if os.environ.get("DEL") == "1":
    keep = [l for l in s0.splitlines(keepends=True) if os.environ["FIG"] not in l]
    s = "".join(keep)
else:
    s = s0.replace(os.environ["FIG"], os.environ["TO"])
assert s != s0, "МУТАЦИЯ НЕ ПРИМЕНИЛАСЬ: %s" % sys.argv[1]
p.write_text(s, encoding="utf-8")
PY
}

# M1 — шапка COVERAGE обещает закрытых типов больше, чем их есть.
FIG='covered 13 / outside-mockup 7 / missing 1' TO='covered 14 / outside-mockup 7 / missing 1' sub "$CSV"
run M1

# M2 — опись ссылается на узел, которого в сцене нет (переименование без правки описи).
FIG='Center/Window/Sheet/Left/NamePlate' TO='Center/Window/Sheet/Left/NamePlateGone' sub "$CSV"
run M2

# M3 — опись ссылается на пиксель кита, которого нет на диске.
FIG='hero/figure.png' TO='hero/figureGone.png' sub "$CSV"
run M3

# M4 — строка без носителя осталась без ссылки: «некуда записать» превращается в «забыли».
FIG='Q-M121 · T-306 · T-251 — уровня в модели нет; скрыто по значению' \
TO='уровня в модели нет' sub "$CSV"
run M4

# M5 — из описи выброшена строка полосы маны: узел остаётся в сцене и рисуется
# пикселем кита, но опись о нём молчит.
DEL=1 FIG='BandMana/ManaTrack' sub "$CSV"
run M5

echo "Мутации: 5, красных ожидалось 5, провалов: $FAILED"
exit "$FAILED"

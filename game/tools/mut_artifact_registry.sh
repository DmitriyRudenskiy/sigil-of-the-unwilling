#!/usr/bin/env bash
# Мутационная батарея контракта реестра артефактов (T-227 С-4).
#
# Каждый мутант обязан покраснить test_artifact_registry.gd; зелёный мутант = дыра
# контракта. Мутации бьют по всем проверкам-suite: цена и имя строки (M1–M2),
# соответствие строк иконок (M3), партиция по редкости (M4), словарь модификаторов
# (M6), габарит из таблицы слотов (M7). M5 (reset без сброса корзин) задокументирован
# как эквивалентный мутант: `ensure_definitions` чистит `_by_rarity` сам.
#
# Запуск: bash game/tools/mut_artifact_registry.sh   (из корня репо, дерево чистое)
set -u
G=${GODOT_BIN:-/home/user/.local/bin/godot}
TEST=res://tests/unit/autoload/test_artifact_registry.gd
REG=game/scripts/autoload/artifact_registry.gd
ART=game/scripts/data/artifact.gd
FAILED=0

run() {
	local name="$1"
	local file="$2"
	local out
	out=$(cd game && timeout 600 "$G" --headless --path . -s addons/gdunit4/bin/GdUnitCmdTool.gd \
		--ignoreHeadlessMode -c -a "$TEST" 2>&1 | grep -oE "0 errors \| [0-9]+ failures" | tail -1)
	echo "$name: $out"
	case "$out" in
	"0 errors | 0 failures")
		echo "  !! ЗЕЛЁНЫЙ МУТАНТ — контракт не ловит"
		FAILED=1
		;;
	esac
	git checkout -- "$file"
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

# M1: цена строки обнуляется — предмет нельзя оценить (value_of даёт половину от нуля).
mutate "$REG" 's = s.replace("\"value_gold\": gold,", "\"value_gold\": 0,")'
run M1_gold_zero "$REG"

# M2: имя строки пустое — игрок видит предмет без названия.
mutate "$REG" 's = s.replace("\"display_name\": display_name,", "\"display_name\": \"\",")'
run M2_name_empty "$REG"

# M3: из выдачи выпадает id — строки реестра и набор иконок расходятся.
mutate "$REG" 's = s.replace("\tfor id in _artifacts:\n\t\tresult.append(_artifacts[id])", "\tfor id in _artifacts:\n\t\tif String(id) == &\"leather_vest\":\n\t\t\tcontinue\n\t\tresult.append(_artifacts[id])")'
run M3_icon_pairing "$REG"

# M4: корзина редкости игнорирует редкость — партиция превращается в полный список.
mutate "$REG" 's = s.replace("\t\tif not _by_rarity.has(art.rarity):\n\t\t\t_by_rarity[art.rarity] = []\n\t\t_by_rarity[art.rarity].append(art)", "\t\tif not _by_rarity.has(Artifact.Rarity.MINOR):\n\t\t\t_by_rarity[Artifact.Rarity.MINOR] = []\n\t\t_by_rarity[Artifact.Rarity.MINOR].append(art)")'
run M4_rarity_ignored "$REG"

# M5 (эквивалентный мутант, ожидается зелёным): reset без `_by_rarity.clear()`.
#green
# Мертв по построению: `ensure_definitions` перед сборкой корзин сам вызывает
# `_by_rarity.clear()` (строка сборки индекса), поэтому «забытый» сброс наблюдаемо
# ничем не отличается — ни один тест его не отличит. Оставлен в батарее как запись
# факта, в вердикт не входит.

# M6: у строки появляется новый немой ключ модификатора — пишется в сумму
# get_total_modifiers() и не читается никем.
mutate "$REG" 's = s.replace("{\"castle_growth_percent\": 50}", "{\"castle_growth_percent\": 50, \"aura\": 3}")'
run M6_new_neme_key "$REG"

# M7: габарит слота не влезает в сетку снаряжения — предмет невозможно положить.
mutate "$ART" 's = s.replace("    Slot.TORSO: Vector2i(2, 3),", "    Slot.TORSO: Vector2i(20, 9),")'
run M7_footprint_too_big "$ART"

echo "===================="
if [ "$FAILED" -eq 0 ]; then
	echo "MUTATION BATTERY: все мутанты красные (контракт работает)"
else
	echo "MUTATION BATTERY: есть зелёные мутанты — контракт слеп"
fi
exit "$FAILED"

#!/usr/bin/env bash
# Батарея мутантов генераторов карты (T-227 С-4).
#
# Каждый мутант обязан покраснить ровно один гардинг-тест `test_map_generators.gd`.
# Зелёный мутант = слепой тест; неприменившийся мутант = зелёный по ошибке,
# поэтому перед прогоном проверяется `git diff` по мутируемому файлу (урок
# 2026-10-28, mut_spell_bridge: четыре мутанта молча не нашли исходник и были
# зачтены как «эквивалентные»).
#
# Запуск: bash game/tools/mut_map_generators.sh          (все мутанты)
#         ONLY="M6 M8" bash game/tools/mut_map_generators.sh
set -u
cd "$(dirname "$0")/.." || exit 1
G="${GODOT_BIN:-$(command -v godot || echo /home/user/.local/bin/godot)}"
TEST="res://tests/unit/world/test_map_generators.gd"
MOUNTAIN=scripts/world/map_mountain_generator.gd
RIVER=scripts/world/map_river_generator.gd
FOREST=scripts/world/map_forest_generator.gd
ONLY="${ONLY:-}"
FAILED=0

mut() { # mut <файл> <было> <станет>
	python3 - "$@" <<'PY'
import pathlib, sys
path, old, new = sys.argv[1:4]
p = pathlib.Path(path)
s = p.read_text(encoding="utf-8")
assert s.count(old) == 1, f"{path}: якорь встречается {s.count(old)} раз: {old[:60]!r}"
p.write_text(s.replace(old, new, 1), encoding="utf-8")
PY
}

check() { # имя файл [ожидаем]  (по умолчанию red; green — эквивалентный мутант)
	local name="$1" file="$2" expect="${3:-red}"
	if [ -n "$ONLY" ] && [[ " $ONLY " != *" $name "* ]]; then
		# Мутацию уже наложила строка выше — обязаны вернуть файл, иначе
		# следующий мутант наложится на чужую правку и покраснеет не своя проверка.
		git checkout -- "$file"
		return 0
	fi
	if git diff --quiet -- "$file"; then
		echo "$name: *** МУТАНТ НЕ ПРИМЕНИЛСЯ — правка не нашла исходник ***"
		FAILED=1
		return
	fi
	local out
	out=$(timeout 600 "$G" --headless --path . -s addons/gdunit4/bin/GdUnitCmdTool.gd \
		--ignoreHeadlessMode -c -a "$TEST" 2>&1 | grep -oE "0 errors \| [0-9]+ failures" | tail -1)
	if [ "$expect" = "green" ]; then
		# Эквивалентный мутант: правка меняет только недостижимую ветку. Красный
		# прогон здесь означает, что ветка достижима, — то есть запись ниже неверна.
		case "$out" in
		"0 errors | 0 failures") echo "$name: эквивалентен ($out)"
			;;
		"") echo "$name: СВОДКА НЕ ПРОЧИТАНА — прогон не засчитывается"
			FAILED=1
			;;
		*) echo "$name: КРАСНЫЙ, хотя заявлен эквивалентным ($out)"
			FAILED=1
			;;
		esac
		git checkout -- "$file"
		return
	fi
	case "$out" in
	"0 errors | 0 failures")
		echo "$name: ЗЕЛЁНЫЙ ПОСЛЕ МУТАЦИИ ($out) — гард слепой"
		FAILED=1
		;;
	"") echo "$name: СВОДКА НЕ ПРОЧИТАНА — прогон не засчитывается"
		FAILED=1
		;;
	*) echo "$name: красным подтверждён ($out)"
		;;
	esac
	git checkout -- "$file"
}

# ── горы ──────────────────────────────────────────────────────────────────

mut "$MOUNTAIN" "		elif height >= 0.85:" "		elif height >= 1.5:"
check M1_snow_threshold_ignored "$MOUNTAIN"

mut "$MOUNTAIN" "		model.height_grid[cell] += fault.uplift" "		model.height_grid[cell] += 0.0"
check M2_uplift_is_a_noop "$MOUNTAIN"

mut "$MOUNTAIN" "			var smoothed = current * 0.7 + avg * 0.3" "			var smoothed = current * 0.7 - avg * 3.0"
check M3_erosion_digs_the_map "$MOUNTAIN"

mut "$MOUNTAIN" "	rng.seed = model.seed_value + 100" "	rng.seed = hash(str(Time.get_ticks_msec()))"
check M4_mountain_seed_is_random "$MOUNTAIN"

# ── реки ──────────────────────────────────────────────────────────────────

mut "$RIVER" "var MIN_LENGTH: int = 5" "var MIN_LENGTH: int = 1"
check M5_short_rivers_kept "$RIVER"

mut "$RIVER" "			if height >= MIN_ELEVATION and terrain != _HexUtils.Terrain.WATER:" "			if height >= 0.0 and terrain != _HexUtils.Terrain.WATER:"
check M6_sources_anywhere "$RIVER"

mut "$RIVER" "			if height >= MIN_ELEVATION and terrain != _HexUtils.Terrain.WATER:" "			if height >= MIN_ELEVATION:"
check M7_sources_in_water "$RIVER"

mut "$RIVER" "		if neighbor_height < best_height:" "		if neighbor_height > best_height:"
check M8_rivers_flow_uphill "$RIVER"

mut "$RIVER" "			model.river_grid[cell] = river.width" "			model.river_grid[cell] = 0.0"
check M9_zero_width "$RIVER"

mut "$RIVER" "	return cell.x >= 0 and cell.x < model.map_width and cell.y >= 0 and cell.y < model.map_height" "	return true"
check M10_rivers_leave_the_map "$RIVER"

mut "$RIVER" "				model.terrain_grid[cell] = _HexUtils.Terrain.RIVER" "				pass"
check M11_river_not_painted "$RIVER"

# ── леса ──────────────────────────────────────────────────────────────────

mut "$FOREST" "	_HexUtils.Terrain.SAND: 0.0," "	_HexUtils.Terrain.SAND: 1.0,"
check M12_forest_on_sand "$FOREST"

mut "$FOREST" "	var min_spacing = 4" "	var min_spacing = 1"
check M13_clusters_touch "$FOREST"

mut "$FOREST" "		if placed_tiles >= target_forest_tiles:
			break" "		if placed_tiles >= 1000000:
			break"
check M14_coverage_ceiling_ignored "$FOREST"

# M15 — эквивалентен, и это открытие, а не слепота теста: порог 0.7 стоит в
# недостижимой области. Плотность = clamp(1 − средняя_дистанция/√n, 0.3, 1.0);
# компактный кластер даёт максимум 0.66 (замер по зёрнам 1/42/777/4242), а 1.0
# бывает только у кластеров из одной клетки, которые переживают clearings. Сдвиг
# 0.7→0.95 не меняет ни одной подписи на реальных данных, а DENSE_FOREST из-за
# этого на карте — всегда одиночные клетки-артефакты (замер: 0–2 на 40×40).
# Недостижимая ветка заведена в тикет, тест на неё не пишется.
mut "$FOREST" "	if cluster.density > 0.7:
		cluster.type = \"dense\"" "	if cluster.density > 0.95:
		cluster.type = \"dense\""
check M15_density_type_threshold "$FOREST" green

mut "$FOREST" "			elif cluster.density > 0.4:" "			elif cluster.density > -1.0:"
check M16_sparse_clusters_paint "$FOREST"

# M17 — эквивалентен: последняя строка `_is_suitable_for_forest` —
# `return rng.randf() < suitability`, и для территории с пригодностью 0.0 она и
# так false. Ранний возврат дублирует её, поэтому закреплять его тестом нельзя:
# тест проверял бы мёртвую ветку.
mut "$FOREST" "	if suitability <= 0.0:
		return false" "	if suitability <= -9.0:
		return false"
check M17_suitability_gate_ignored "$FOREST" green

mut "$FOREST" "	rng.seed = model.seed_value + 500" "	rng.seed = hash(str(Time.get_ticks_msec()))"
check M18_forest_seed_is_random "$FOREST"

echo "---"
if [ "$FAILED" -ne 0 ]; then
	echo "БАТАРЕЯ КРАСНАЯ: часть мутантов не покраснела (или не применилась)"
	exit 1
fi
echo "БАТАРЕЯ ЗЕЛЁНАЯ: все мутанты покраснели"

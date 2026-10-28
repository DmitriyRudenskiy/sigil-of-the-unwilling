extends BaseTest

## Значенческий контракт `GameNumbersCity` (T-227 · С-4, закрытая дыра).
##
## Файл — не перебор 133 констант (это «зелёный по умолчанию»: подмена значения
## цифрой на цифре не падает). У носителя три отдельных риска, и каждый закрыт
## своим родом проверки:
##
## 1) **Расхождение с фасадом.** `GameNumbers` — compat-shim: `real values live in
##    the GameNumbers* domain classes`, весь код читает `GameNumbers.X`. Новая
##    константа домена, не выписанная в шим, недоступен потребителю и молчит.
##    Проверка — скан исходника (механизм тот же, что `test_theme_source_scan.gd`:
##    имя обязано быть видно в тексте, динамического способа его «протащить» нет).
##
## 2) **Писатели без читателя.** 115 из 133 констант читает только замороженная
##    линия города (D-157: `scenes/archive/world.tscn`, «city cycle, рейды легаси»),
##    а три не читает никто. Список немых — замкнутый и только сокращается;
##    обратная половина проверки не даёт ему протухнуть (починил — убери строку).
##
## 3) **Пары и порядка.** Числа живут связками: пороги миграции обязаны совпадать
##    с полосами репутации, `CITY_LEVEL_MAX` — с длиной кривой процветания,
##    три имени «кольца 1–3» (D6, 02g §2.1) — быть одним числом, таблицы харизмы —
##    одной длины, вероятности — в [0,1], d20-сложности — в диапазоне кубика.
##    Одиночная правка одной стороны пары роняет тест, а не баланс молча.
##
## Значения-контракты (те, что названы в GDD и не являются настройкой) пинуются
## числом; остальное проверяется соотношением. Настройка баланса — не этот файл:
## числа без обоснования живут реестром TBD (docs/07-balance.md §10).

const _DEF := "res://scripts/constants/game_numbers_city.gd"
const _SHIM := "res://scripts/constants/game_numbers.gd"
const _SCAN_ROOT := "res://scripts"
## Скан потребителей: сам фасад и его соседи по каталогу — не потребитель.
const _NOT_CONSUMER_PREFIX := "res://scripts/constants/"

## Немые константы (писатели без читателя). Рэтчет: только сокращать; причина
## обязана объяснять, почему строка здесь, а не «потом разберёмся». T-271.
const _UNREAD_ALLOWED := {
	"REP_DISASTER": "полоса «катастрофы» никем не читается (T-271)",
	"PROSPERITY_LEVEL_REQ": "заменён кривой PROSPERITY_LEVEL_REQS (T-271)",
	"DEMO_MAX_TRAITS": "лимит черт демо-создания, приёмника нет (T-271)",
	"SOCIAL_IMMIGRATION_MOD": "читается ключом словаря GameNumbers.SOCIAL_CHA_TABLES, не именем",
	"SOCIAL_MAX_STACKS": "читается ключом словаря GameNumbers.SOCIAL_CHA_TABLES, не именем",
	"SOCIAL_RECRUIT_QUALITY": "читается ключом словаря GameNumbers.SOCIAL_CHA_TABLES, не именем",
}

## Замороженная линия (D-157) — каталоги, чтецы которых не делают дыру живой;
## нужны только для того, чтобы отличить «немой» от «читает легаси».
const _HEX_NEIGHBOURS := 6


# --- служебное ------------------------------------------------------------

func _read(path: String) -> String:
	var txt := FileAccess.get_file_as_string(path)
	assert_str(txt).is_not_empty().override_failure_message("не прочитан исходник %s" % path)
	return txt


func _const_names(src: String) -> Array[String]:
	var re := RegEx.new()
	var err := re.compile("(?m)^const\\s+(\\w+)")
	assert_that(err == OK).is_true().override_failure_message("регулярка имён констант не собралась")
	var out: Array[String] = []
	for m: RegExMatch in re.search_all(src):
		out.append(m.get_string(1))
	return out


## Весь production-код одним текстом (кроме каталога констант): проверка «имя
## прочитано» — текстовая, как и в других сканах этого семейства.
func _consumer_text() -> String:
	var parts: Array[String] = []
	var stack: Array[String] = [_SCAN_ROOT]
	while not stack.is_empty():
		var dir_path: String = stack.pop_back()
		var dir := DirAccess.open(dir_path)
		assert_object(dir).is_not_null().override_failure_message("нет каталога %s" % dir_path)
		dir.list_dir_begin()
		var name := dir.get_next()
		while name != "":
			var full := dir_path.path_join(name)
			if dir.current_is_dir():
				stack.append(full)
			elif name.ends_with(".gd") and not full.begins_with(_NOT_CONSUMER_PREFIX):
				parts.append(FileAccess.get_file_as_string(full))
			name = dir.get_next()
		dir.list_dir_end()
	var joined := "\n".join(parts)
	assert_that(joined.length() > 100000).is_true().override_failure_message("скан потребителей пуст — скан не работает")
	return joined


func _is_non_decreasing(values: Array) -> bool:
	for i in range(1, values.size()):
		if float(values[i]) < float(values[i - 1]):
			return false
	return true


func _is_strictly_increasing(values: Array) -> bool:
	for i in range(1, values.size()):
		if float(values[i]) <= float(values[i - 1]):
			return false
	return true


func _is_non_increasing(values: Array) -> bool:
	for i in range(1, values.size()):
		if float(values[i]) > float(values[i - 1]):
			return false
	return true


# --- 1 · фасад и замкнутость поверхности ----------------------------------

func test_every_constant_is_re_exported_by_the_shim() -> void:
	var names := _const_names(_read(_DEF))
	assert_that(names.size() > 100).is_true().override_failure_message("имена констант не собрались")
	var shim := _read(_SHIM)
	var missing: Array[String] = []
	for name in names:
		if not shim.contains("GameNumbersCity." + name):
			missing.append(name)
	assert_that(missing).is_empty().override_failure_message(
		"константы GameNumbersCity не видны через фасад GameNumbers: %s" % ", ".join(missing))


func test_unread_constants_are_the_allowed_closed_set() -> void:
	var names := _const_names(_read(_DEF))
	var consumers := _consumer_text()
	var unread: Array[String] = []
	for name in names:
		var re := RegEx.new()
		re.compile("GameNumbers\\s*\\.\\s*" + name + "\\b")
		if re.search(consumers) == null:
			unread.append(name)
	var unexpected: Array[String] = []
	for name in unread:
		if not _UNREAD_ALLOWED.has(name):
			unexpected.append(name)
	assert_that(unexpected).is_empty().override_failure_message(
		"немые константы вне замкнутого списка (писатели без читателя): %s" % ", ".join(unexpected))
	assert_that(unread.size()).is_less_equal(_UNREAD_ALLOWED.size()).override_failure_message(
		"немых констант больше, чем разрешено списком T-271")


func test_allowlist_does_not_outlive_its_dead_entries() -> void:
	# Обратная половина рэтчета: починенного немца нельзя оставить в списке.
	var consumers := _consumer_text()
	var stale: Array[String] = []
	for name in _UNREAD_ALLOWED:
		var re := RegEx.new()
		re.compile("GameNumbers\\s*\\.\\s*" + name + "\\b")
		if re.search(consumers) != null:
			stale.append(name)
	assert_that(stale).is_empty().override_failure_message(
		"эти константы уже читаются — строку из %s надо убрать: %s" % ["_UNREAD_ALLOWED", ", ".join(stale)])


# --- 2 · полосы и пары ----------------------------------------------------

func test_reputation_bands_are_ordered_and_bounded() -> void:
	assert_that(GameNumbers.REP_MIN < GameNumbers.REP_BAND_CRISIS).is_true()
	assert_that(GameNumbers.REP_BAND_CRISIS < GameNumbers.REP_BAND_DISCONTENT).is_true()
	assert_that(GameNumbers.REP_BAND_DISCONTENT < 0).is_true()
	assert_that(0 < GameNumbers.REP_BAND_PROSPERITY).is_true()
	assert_that(GameNumbers.REP_BAND_PROSPERITY < GameNumbers.REP_BAND_GOLDEN_AGE).is_true()
	assert_that(GameNumbers.REP_BAND_GOLDEN_AGE <= GameNumbers.REP_MAX).is_true()
	assert_that(GameNumbers.REP_DISASTER < 0).is_true()
	assert_that(GameNumbers.REP_VICTORY > 0).is_true()
	assert_that(GameNumbers.REP_STARVING < 0).is_true()
	assert_that(GameNumbers.REP_OVERPOP_PER < 0).is_true()
	assert_that(GameNumbers.REP_FOOD_SURPLUS > 0).is_true()
	assert_that(GameNumbers.STARVING_APPROVAL_PENALTY > 0).is_true()


func test_migration_thresholds_agree_with_reputation_bands() -> void:
	# Полоса недовольства и порог оттока — одно и то же состояние города; разные
	# числа означают, что город «недоволен», но жители не уходят.
	assert_that(GameNumbers.MIGRATE_IN_AT).is_equal(GameNumbers.REP_BAND_PROSPERITY)
	assert_that(GameNumbers.MIGRATE_OUT_AT).is_equal(GameNumbers.REP_BAND_DISCONTENT)
	assert_that(GameNumbers.MIGRATE_CRISIS_AT).is_equal(GameNumbers.REP_BAND_CRISIS)
	assert_that(GameNumbers.MIGRATE_CRISIS_PER_TURN > GameNumbers.MIGRATE_IN_PER_TURN).is_true()


func test_prosperity_bounds_and_level_curve() -> void:
	assert_that(GameNumbers.PROSPERITY_MIN < GameNumbers.PROSPERITY_BASE).is_true()
	assert_that(GameNumbers.PROSPERITY_BASE < GameNumbers.PROSPERITY_MAX).is_true()
	assert_that(GameNumbers.PROSPERITY_REP_LOW < GameNumbers.PROSPERITY_REP_HIGH).is_true()
	assert_that(GameNumbers.PROSPERITY_BLD_PER > 0.0).is_true()
	assert_that(GameNumbers.PROSPERITY_BLD_CAP > GameNumbers.PROSPERITY_BLD_PER).is_true()
	assert_that(GameNumbers.PROSPERITY_POP_RATIO > 0.0 and GameNumbers.PROSPERITY_POP_RATIO <= 1.0).is_true()
	assert_that(GameNumbers.PROSPERITY_GOLD_PER_PT > 0.0).is_true()
	# Кривая уровней 2..CITY_LEVEL_MAX: короткий массив = молчаливый clamp
	# (12-й уровень получил бы требование 11-го).
	var reqs: Array = GameNumbers.PROSPERITY_LEVEL_REQS
	assert_that(reqs.size()).is_equal(GameNumbers.CITY_LEVEL_MAX - GameNumbers.CITY_LEVEL_MIN)
	assert_that(_is_non_decreasing(reqs)).is_true().override_failure_message("кривая процветания не монотонна")
	assert_that(float(reqs[0]) > GameNumbers.PROSPERITY_BASE).is_true()
	assert_that(float(reqs[reqs.size() - 1]) < GameNumbers.PROSPERITY_MAX).is_true()
	assert_that(GameNumbers.PROSPERITY_LEVEL_POP_STEP > 0).is_true()


func test_three_names_of_the_ring_canon_are_one_number() -> void:
	# D6 / 02g §2.1: «кольца 1–3 вокруг ядра» названы трижды — радиус арены,
	# радиус застройки и предел радиуса уровня. Расхождение ломает геометрию города.
	assert_that(GameNumbers.ARENA_RADIUS).is_equal(GameNumbers.CITY_RING_MAX)
	assert_that(GameNumbers.CITY_RING_MAX).is_equal(GameNumbers.PROSPERITY_MAX_RADIUS)
	assert_that(GameNumbers.PROSPERITY_MAX_RADIUS >= 1).is_true()
	assert_that(GameNumbers.BUILDING_MAX_DIST_BASE >= 1).is_true()
	assert_that(GameNumbers.ZONE_INDUSTRIAL_MIN_DIST >= 1).is_true()
	assert_that(GameNumbers.ZONE_INDUSTRIAL_MIN_DIST <= GameNumbers.ARENA_RADIUS).is_true()


func test_scale_tiers_and_multipliers() -> void:
	var tiers: Array = GameNumbers.SCALE_TIERS
	assert_that(_is_strictly_increasing(tiers)).is_true()
	for mults in [GameNumbers.SCALE_STORAGE_MULT, GameNumbers.SCALE_AUTO_MULT]:
		var arr: Array = mults
		assert_that(arr.size()).is_equal(tiers.size() + 1)
		assert_that(_is_non_decreasing(arr)).is_true()
		assert_that(float(arr[0])).is_equal(1.0)
	var upkeep: Array = GameNumbers.SCALE_UPKEEP_MULT
	assert_that(upkeep.size()).is_equal(tiers.size() + 1)
	assert_that(_is_non_increasing(upkeep)).is_true().override_failure_message(
		"крупное поселение не может обслуживать себя дороже мелкого")
	assert_that(float(upkeep[0])).is_equal(1.0)
	assert_that(float(upkeep[upkeep.size() - 1]) > 0.0).is_true()
	# Границы индекса: SCALE_TIERS — верхние границы тиров 0..n-1 (не начало тира),
	# поэтому pop == порогу ещё принадлежит прежнему тиру, а pop+1 — следующему.
	assert_that(ScaleShiftManager.TIER_NAMES.size()).is_equal(tiers.size() + 1)
	assert_that(ScaleShiftManager.tier_for(0)).is_equal(0)
	for i in tiers.size():
		assert_that(ScaleShiftManager.tier_for(int(tiers[i]))).is_equal(i)
		assert_that(ScaleShiftManager.tier_for(int(tiers[i]) + 1)).is_equal(i + 1)
	assert_that(ScaleShiftManager.tier_for(100000)).is_equal(tiers.size())
	assert_that(ScaleShiftManager.upkeep_multiplier(-5)).is_equal(1.0)
	assert_that(ScaleShiftManager.upkeep_multiplier(99)).is_less_equal(1.0)


# --- 3 · таблицы колец ----------------------------------------------------

func test_ring_yield_table_shape_and_lookup() -> void:
	var rows: Array = GameNumbers.RING_YIELD
	assert_that(rows.size()).is_equal(GameNumbers.ARENA_RADIUS + 1)
	for row in rows:
		var cells: Array = row
		assert_that(cells.size()).is_equal(5)
	# Ядро (кольцо 0) дохода не даёт — иначе «ядро 4 клетки» платит само за себя.
	var core: Array = rows[0]
	for cell in core:
		assert_that(float(cell)).is_equal(0.0)
	for ring in [1, 2, 3]:
		var y: Dictionary = GameNumbersCity.ring_yield(ring)
		assert_that(y.size()).is_equal(5)
		var expect: Array = rows[ring]
		assert_that(y[&"food"]).is_equal(float(expect[0]))
		assert_that(y[&"industry"]).is_equal(float(expect[1]))
		assert_that(y[&"dust"]).is_equal(float(expect[2]))
		assert_that(y[&"science"]).is_equal(float(expect[3]))
		assert_that(y[&"influence"]).is_equal(float(expect[4]))
	# Вне доски — пусто, а не нулевой доход (пустой словарь читается как «нет кольца»).
	assert_that(GameNumbersCity.ring_yield(0)).is_empty()
	assert_that(GameNumbersCity.ring_yield(GameNumbers.ARENA_RADIUS + 1)).is_empty()
	assert_that(GameNumbersCity.ring_yield(-1)).is_empty()


func test_ring_bonus_table_is_closed_against_the_building_catalog() -> void:
	var bonus: Dictionary = GameNumbers.RING_BONUS
	assert_that(bonus.size() > 0).is_true()
	var known := GameNumbersCity.ring_bonus(&"__нет_такого_id__", 1)
	assert_that(known).is_equal(0.0)
	for def_id in bonus:
		var row: Dictionary = bonus[def_id]
		for ring in range(1, GameNumbers.ARENA_RADIUS + 1):
			assert_that(row.has(ring)).is_true().override_failure_message(
				"RING_BONUS[%s] не задан для кольца %d — дыра читается как 0 молча" % [str(def_id), ring])
			assert_that(float(row[ring]) >= 0.0 and float(row[ring]) <= 1.0).is_true()
		assert_that(GameNumbersCity.ring_bonus(def_id, 0)).is_equal(0.0)
	# Замкнутый набор: надбавка названа по строительству из каталога.
	var file := FileAccess.open("res://assets/data/buildings.json", FileAccess.READ)
	assert_object(file).is_not_null()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	assert_that(parsed is Array).is_true().override_failure_message(
		"buildings.json должен быть массивом строительств")
	var ids: Array[String] = []
	for row in (parsed as Array):
		if row is Dictionary:
			ids.append(str((row as Dictionary).get("id", "")))
	var orphans: Array[String] = []
	for def_id in bonus:
		if not ids.has(str(def_id)):
			orphans.append(str(def_id))
	assert_that(orphans).is_empty().override_failure_message(
		"RING_BONUS называет строительство, которого нет в buildings.json: %s" % ", ".join(orphans))


# --- 4 · вероятности и множители -----------------------------------------

func test_probabilities_live_in_unit_interval() -> void:
	assert_that(GameNumbers.RAID_CHANCE_MIN <= GameNumbers.RAID_CHANCE_BASE).is_true()
	assert_that(GameNumbers.RAID_CHANCE_BASE <= GameNumbers.RAID_CHANCE_MAX).is_true()
	assert_that(GameNumbers.RAID_CHANCE_MIN >= 0.0).is_true()
	assert_that(GameNumbers.RAID_CHANCE_MAX <= 1.0).is_true()
	assert_that(GameNumbers.RAID_REP_DIVISOR > 0.0).is_true()
	assert_that(GameNumbers.RAID_PILLAGE_FRACTION > 0.0 and GameNumbers.RAID_PILLAGE_FRACTION <= 1.0).is_true()
	assert_that(GameNumbers.ROYALTY_FRACTION > 0.0 and GameNumbers.ROYALTY_FRACTION < 1.0).is_true()
	assert_that(GameNumbers.ARENA_FEATURE_CHANCE > 0.0 and GameNumbers.ARENA_FEATURE_CHANCE < 1.0).is_true()
	assert_that(GameNumbers.DEMO_CRITICAL_THRESHOLD > 0.0 and GameNumbers.DEMO_CRITICAL_THRESHOLD < 1.0).is_true()
	assert_that(GameNumbers.SOCIAL_ATTRITION_CHA >= 0).is_true()
	assert_that(GameNumbers.REP_MIN <= GameNumbers.RAID_REP_LOSS).is_true()
	assert_that(GameNumbers.RAID_REP_RELIEF > 0).is_true()


func test_storm_and_zone_multipliers_are_bonuses_not_inversions() -> void:
	# Шторм режет производство; «смягчение» обязано быть слабее удара, но тоже < 1.
	assert_that(GameNumbers.ARENA_STORM_PERIOD >= 1).is_true()
	assert_that(GameNumbers.ARENA_STORM_PROD_MULT > 0.0).is_true()
	assert_that(GameNumbers.ARENA_STORM_PROD_MULT < GameNumbers.ARENA_STORM_MITIG_MULT).is_true()
	assert_that(GameNumbers.ARENA_STORM_MITIG_MULT <= 1.0).is_true()
	assert_that(GameNumbers.ARENA_STORM_MITIG_FOOD < GameNumbers.ARENA_STORM_FOOD).is_true()
	assert_that(GameNumbers.ARENA_CLUSTER_MIN >= 1).is_true()
	assert_that(GameNumbers.ARENA_CLUSTER_MULT > 1.0).is_true()
	assert_that(GameNumbers.ARENA_CLUSTER_HOUSING >= 0).is_true()
	assert_that(GameNumbers.ZONE_MAX_MULT > 1.0).is_true()
	assert_that(GameNumbers.ZONE_AGGLOMERATION_COUNT >= 1).is_true()
	assert_that(GameNumbers.ZONE_AGGLOMERATION_BONUS > 0.0).is_true()
	assert_that(GameNumbers.LOGISTICS_MIN_MULT <= GameNumbers.LOGISTICS_MAX_MULT).is_true()
	assert_that(GameNumbers.LOGISTICS_MIN_MULT > 0.0).is_true()
	assert_that(GameNumbers.LOGISTICS_DIST_FALLOFF > 0.0).is_true()
	assert_that(GameNumbers.LOGISTICS_ROAD_BONUS >= 0.0).is_true()
	assert_that(GameNumbers.LOGISTICS_ROAD_MAX >= 1.0).is_true()
	assert_that(GameNumbers.MARKET_DEFAULT_RATE > 0.0).is_true()
	assert_that(GameNumbers.MARKET_MIN_AMOUNT > 0.0).is_true()


func test_growth_and_inflow_are_not_negative() -> void:
	assert_that(GameNumbers.CITY_CYCLE_TURNS >= 1).is_true()
	assert_that(GameNumbers.HEX_SIZE > 0.0).is_true()
	assert_that(GameNumbers.INFLOW_BASE >= 0.0).is_true()
	assert_that(GameNumbers.INFLOW_PER_TEMPLE >= 0.0).is_true()
	assert_that(GameNumbers.INFLOW_GLORY_DIVISOR > 0.0).is_true()
	assert_that(GameNumbers.INFLOW_WINTER_MOD < GameNumbers.INFLOW_SUMMER_MOD).is_true()
	assert_that(GameNumbers.GROWTH_THRESHOLD_BASE > 0.0).is_true()
	assert_that(GameNumbers.GROWTH_THRESHOLD_EXP > 0.0).is_true()
	assert_that(GameNumbers.FOOD_PER_WORKER >= 0.0).is_true()
	assert_that(GameNumbers.FOOD_PER_MILITIA >= 0.0).is_true()
	assert_that(GameNumbers.FOOD_PER_FOLLOWER >= 0.0).is_true()
	assert_that(GameNumbers.FOOD_PER_SCHOLAR >= 0.0).is_true()
	assert_that(GameNumbers.BASE_SETTLEMENT_HOUSING > 0).is_true()
	assert_that(GameNumbers.BOROUGH_BASE_COST > 0.0).is_true()
	assert_that(GameNumbers.BOROUGH_COST_STEP > 0.0).is_true()
	assert_that(GameNumbers.BOROUGH_POP_RATIO_DEFAULT > 0.0).is_true()
	assert_that(GameNumbers.BOROUGH_POP_RATIO_WIDE > 0.0).is_true()
	assert_that(GameNumbers.BOROUGH_LEVELUP_NEIGHBORS >= 1).is_true()
	assert_that(GameNumbers.BOROUGH_LEVELUP_NEIGHBORS <= _HEX_NEIGHBOURS).is_true()
	assert_that(GameNumbers.SAFETY_PER_PATROL >= 0).is_true()
	assert_that(GameNumbers.RECRUIT_BATCH_SIZE >= 1).is_true()
	assert_that(GameNumbers.HERO_ARMY_MAX_STACKS >= 1).is_true()


func test_village_seed_and_borough_arrays() -> void:
	assert_that(GameNumbers.VILLAGE_START_WORKERS >= 1).is_true()
	assert_that(GameNumbers.VILLAGE_START_FOLLOWERS >= 0).is_true()
	assert_that(GameNumbers.VILLAGE_START_INDUSTRY >= 0.0).is_true()
	assert_that(GameNumbers.VILLAGE_START_GOLD >= 0.0).is_true()
	assert_that(GameNumbers.VILLAGE_START_FOOD >= 0.0).is_true()
	var caps: Array = GameNumbers.POP_CAP_BY_STRONGHOLD
	assert_that(_is_strictly_increasing(caps)).is_true()
	var approval: Array = GameNumbers.APPROVAL_NET_PER_BOROUGH_LEVEL
	assert_that(approval.size()).is_equal(GameNumbers.BOROUGH_MAX_LEVEL)
	assert_that(_is_non_decreasing(approval)).is_true()
	assert_that(GameNumbers.BUILDING_MAX_LEVEL >= 1).is_true()


# --- 5 · d20-поверхность (social-stats-weapon-tech) ----------------------

func test_social_charisma_tables_share_one_length() -> void:
	var immigration: Array = GameNumbersCity.SOCIAL_IMMIGRATION_MOD
	var stacks: Array = GameNumbersCity.SOCIAL_MAX_STACKS
	var quality: Array = GameNumbersCity.SOCIAL_RECRUIT_QUALITY
	# Индекс таблицы = cha-1 (cha 1..20); разная длина = выход за границу индекса.
	assert_that(immigration.size()).is_equal(20)
	assert_that(stacks.size()).is_equal(immigration.size())
	assert_that(quality.size()).is_equal(immigration.size())
	assert_that(_is_non_decreasing(immigration)).is_true()
	assert_that(_is_non_decreasing(stacks)).is_true()
	assert_that(_is_non_decreasing(quality)).is_true()
	assert_that(float(immigration[0]) > 0.0).is_true()
	assert_that(float(quality[0]) > 0.0).is_true()
	assert_that(int(stacks[0]) >= 1).is_true()
	assert_that(GameNumbers.CHA_MUTINY_DC >= 1 and GameNumbers.CHA_MUTINY_DC <= 20).is_true()
	assert_that(GameNumbers.SOCIAL_ATTRITION_CHA < immigration.size()).is_true()
	# Перенос в словарь — не потеря: фасад обязан отдавать те же массивы.
	var tables: Dictionary = GameNumbers.SOCIAL_CHA_TABLES
	assert_that(tables["immigration"]).is_same(immigration)
	assert_that(tables["max_stacks"]).is_same(stacks)
	assert_that(tables["recruit_quality"]).is_same(quality)


func test_deception_tables_are_within_their_dice() -> void:
	assert_that(GameNumbers.DECEPTION_MIN_PCT < GameNumbers.DECEPTION_MAX_PCT).is_true()
	assert_that(GameNumbers.DECEPTION_MIN_PCT >= 0).is_true()
	assert_that(GameNumbers.DECEPTION_MAX_PCT <= 100).is_true()
	assert_that(GameNumbers.DECEPTION_CRITICAL_MARGIN >= 1).is_true()
	for key in GameNumbers.DECEPTION_BASE:
		var pct: int = int(GameNumbers.DECEPTION_BASE[key])
		assert_that(pct >= GameNumbers.DECEPTION_MIN_PCT).is_true()
		assert_that(pct <= GameNumbers.DECEPTION_MAX_PCT).is_true()
	for key in GameNumbers.DECEPTION_TRAP_DC:
		var dc: int = int(GameNumbers.DECEPTION_TRAP_DC[key])
		assert_that(dc >= 1 and dc <= 30).is_true()
	for key in GameNumbers.RECRUIT_DC:
		var rdc: int = int(GameNumbers.RECRUIT_DC[key])
		assert_that(rdc >= 1 and rdc <= 30).is_true()
	var severities: Array = GameNumbers.DECEPTION_SEVERITIES
	assert_that(severities.size() >= 2).is_true()
	var ids: Array[String] = []
	var last := -1.0
	for row in severities:
		var entry: Dictionary = row
		var id := str(entry.get("id", ""))
		assert_that(id != "").is_true()
		assert_that(not ids.has(id)).is_true().override_failure_message("степень %s названа дважды" % id)
		ids.append(id)
		var surcharge := float(entry.get("surcharge", 0.0))
		assert_that(surcharge > last).is_true().override_failure_message(
			"степени последствий не упорядочены по нарастанию: %s" % id)
		last = surcharge
	assert_that(ids[0]).is_equal("none")
	assert_that(float((severities[0] as Dictionary).get("surcharge", -1.0))).is_equal(0.0)

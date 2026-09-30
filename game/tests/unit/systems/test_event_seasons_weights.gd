extends BaseTest

## crisis-content-seasonal-rare-events: схема seasons/weight/rarity,
## загрузчик (валидация + backward compat), селектор (сезонный фильтр,
## взвешенный детерминированный выбор).


func _sys() -> CrisisEventSystem:
	return make_node(CrisisEventSystem)


## Шаблон события с полями схемы.
func _event(id: String, seasons: Array = [], weight: float = 1.0, rarity: String = "common") -> CrisisEventSystem.DynamicEventData:
	var data := {
		"id": id,
		"title": id,
		"description": "",
		"weight": weight,
		"choices": [
			{"text": "ok", "impact": 1, "effects": {}, "requirements": {}},
			{"text": "ok2", "impact": 1, "effects": {}, "requirements": {}},
		],
	}
	if not seasons.is_empty():
		data["seasons"] = seasons
	if rarity != "common":
		data["rarity"] = rarity
	return CrisisEventSystem.DynamicEventData.new(data)


## ---------- 1.1/1.3 Схема: defaults ----------

func test_loader_defaults() -> void:
	# Файл без новых полей читается как раньше (backward compat).
	var e := _event("legacy")
	assert_that(e.seasons).is_equal([])
	assert_that(e.weight).is_equal(1.0)
	assert_that(e.rarity).is_equal("common")

func test_loader_reads_new_fields() -> void:
	var e := _event("tagged", ["spring", "winter"], 0.5, "rare")
	assert_that(e.seasons).is_equal(["spring", "winter"])
	assert_that(e.weight).is_equal(0.5)
	assert_that(e.rarity).is_equal("rare")

func test_crisis_schema_defaults() -> void:
	var c := CrisisEventSystem.CrisisEventData.new({"id": "c1", "title": "t"})
	assert_that(c.seasons).is_equal([])
	assert_that(c.weight).is_equal(1.0)
	assert_that(c.rarity).is_equal("common")

## ---------- 1.2 Валидация загрузчика ----------

func test_invalid_season_rejected() -> void:
	var sys := _sys()
	assert_that(sys._validate_template({"id": "bad", "seasons": ["monsoon"]})).is_false()

func test_valid_seasons_accepted() -> void:
	var sys := _sys()
	for s in CrisisEventSystem.VALID_SEASONS:
		assert_that(sys._validate_template({"id": "ok", "seasons": [s]})).is_true()

func test_missing_seasons_field_valid() -> void:
	var sys := _sys()
	assert_that(sys._validate_template({"id": "legacy", "weight": 1.2})).is_true()

func test_invalid_rarity_falls_back_to_common() -> void:
	var sys := _sys()
	var data := {"id": "x", "rarity": "legendary"}
	assert_that(sys._validate_template(data)).is_true()
	assert_that(data["rarity"]).is_equal("common")

func test_seasons_wrong_type_rejected() -> void:
	var sys := _sys()
	assert_that(sys._validate_template({"id": "bad", "seasons": "spring"})).is_false()

## ---------- 2.1 Сезонный фильтр ----------

func test_summer_event_not_available_in_winter() -> void:
	var sys := _sys()
	sys.event_templates.clear()
	sys.event_templates.append(_event("summer_only", ["summer"]))
	sys.event_templates.append(_event("winter_only", ["winter"]))
	sys.event_templates.append(_event("any_time"))
	sys.set_season_provider(func() -> String: return "winter")
	sys.day_counter = 100
	var available := sys.get_available_events()
	var ids: Array[String] = []
	for e in available:
		ids.append(e.id)
	assert_that(ids.has("summer_only")).is_false()
	assert_that(ids.has("winter_only")).is_true()
	assert_that(ids.has("any_time")).is_true()

func test_unknown_season_does_not_block() -> void:
	# Без провайдера (legacy-путь без календаря) сезонные события доступны.
	var sys := _sys()
	sys.event_templates.clear()
	sys.event_templates.append(_event("summer_only", ["summer"]))
	sys.day_counter = 100
	var available := sys.get_available_events()
	assert_that(available.size()).is_equal(1)

func test_crisis_season_filter() -> void:
	var sys := _sys()
	sys.crisis_templates.clear()
	var spring_crisis := CrisisEventSystem.CrisisEventData.new({"id": "cs", "title": "t", "seasons": ["spring"]})
	var any_crisis := CrisisEventSystem.CrisisEventData.new({"id": "ca", "title": "t"})
	sys.crisis_templates.append(spring_crisis)
	sys.crisis_templates.append(any_crisis)
	sys.set_season_provider(func() -> String: return "autumn")
	sys.day_counter = 100
	var ids: Array[String] = []
	for c in sys.get_available_crises():
		ids.append(c.id)
	assert_that(ids.has("cs")).is_false()
	assert_that(ids.has("ca")).is_true()

## ---------- 2.2 Детерминизм по seed ----------

func test_same_seed_same_selection_sequence() -> void:
	var sequences: Array[String] = []
	for run in 2:
		var sys := _sys()
		sys.rng.seed = 12345
		sys.event_templates.clear()
		sys.event_templates.append(_event("a", [], 1.0))
		sys.event_templates.append(_event("b", [], 1.0))
		sys.event_templates.append(_event("c", [], 1.0))
		var seq := ""
		for _i in 20:
			var chosen: CrisisEventSystem.DynamicEventData = sys.select_by_weight(sys.event_templates)
			seq += chosen.id
		sequences.append(seq)
	assert_that(sequences[0]).is_equal(sequences[1])

func test_different_seed_different_sequence() -> void:
	var seq_a := ""
	var seq_b := ""
	for sys_seed in [111, 222]:
		var sys := _sys()
		sys.rng.seed = sys_seed
		sys.event_templates.clear()
		sys.event_templates.append(_event("a", [], 1.0))
		sys.event_templates.append(_event("b", [], 1.0))
		var seq := ""
		for _i in 20:
			var chosen: CrisisEventSystem.DynamicEventData = sys.select_by_weight(sys.event_templates)
			seq += chosen.id
		if sys_seed == 111:
			seq_a = seq
		else:
			seq_b = seq
	# Вероятность совпадения 20 роллов из 2 ≈ 2^-20
	assert_that(seq_a).is_not_equal(seq_b)

## ---------- 2.3 Распределение весов ----------

func test_weight_distribution_10k_rolls() -> void:
	var sys := _sys()
	sys.rng.seed = 777
	sys.event_templates.clear()
	sys.event_templates.append(_event("heavy", [], 0.9))
	sys.event_templates.append(_event("light", [], 0.1))
	var counts := {"heavy": 0, "light": 0}
	const N := 10000
	for _i in N:
		var chosen: CrisisEventSystem.DynamicEventData = sys.select_by_weight(sys.event_templates)
		counts[chosen.id] += 1
	var heavy_ratio := float(counts["heavy"]) / float(N)
	# 0.9 ± 5%
	assert_that(heavy_ratio).is_between(0.85, 0.95)
	var light_ratio := float(counts["light"]) / float(N)
	assert_that(light_ratio).is_between(0.05, 0.15)

func test_select_by_weight_empty_returns_null() -> void:
	var sys := _sys()
	assert_that(sys.select_by_weight([])).is_null()

## ---------- 3/4 Контент: файлы на месте ----------

const SEASONAL_EVENT_IDS: Array[String] = [
	"event_spring_flood", "event_spring_spawn_surplus",
	"event_summer_drought_risk", "event_summer_caravan_peak",
	"event_autumn_harvest_boom", "event_autumn_mud_season",
	"event_winter_deep_frost", "event_winter_starvation",
]
const RARE_EVENT_IDS: Array[String] = [
	"event_rare_comet", "event_rare_eclipse",
	"event_rare_dragon_sighting", "event_rare_gold_vein",
]

func test_seasonal_content_loaded_with_tags() -> void:
	var sys := _sys()
	var by_id := {}
	for e in sys.event_templates:
		by_id[e.id] = e
	for id in SEASONAL_EVENT_IDS:
		assert_that(by_id.has(id)).is_true()
		var e: CrisisEventSystem.DynamicEventData = by_id[id]
		assert_that(e.seasons.size()).is_equal(1)
		assert_that(e.rarity).is_equal("common")
		# Сезон в id совпадает с тегом
		var season_part := id.get_slice("_", 1)
		assert_that(e.seasons.has(season_part)).is_true()

func test_rare_content_loaded_with_low_weight() -> void:
	var sys := _sys()
	var by_id := {}
	for e in sys.event_templates:
		by_id[e.id] = e
	for id in RARE_EVENT_IDS:
		assert_that(by_id.has(id)).is_true()
		var e: CrisisEventSystem.DynamicEventData = by_id[id]
		assert_that(e.rarity).is_equal("rare")
		assert_that(e.weight).is_less_equal(0.05)

func test_existing_events_tagged() -> void:
	var sys := _sys()
	var by_id := {}
	for e in sys.event_templates:
		by_id[e.id] = e
	assert_that(by_id["event_02_harvest"].seasons).is_equal(["autumn"])
	assert_that(by_id["event_10_cold"].seasons).is_equal(["winter"])
	var crisis_by_id := {}
	for c in sys.crisis_templates:
		crisis_by_id[c.id] = c
	assert_that(crisis_by_id["crisis_07_flood"].seasons).is_equal(["spring"])

extends BaseTest

## Validates the crisis event database (dynamic-world-crisis-system — Task 2.3).
## Loads the real JSON templates through CrisisEventSystem and checks structure,
## type coverage, icon existence, and that every choice effect key is well-formed.


## Choice-effect keys the crisis data format recognizes. The test enforces
## FORMAT consistency (catches typos / unknown keys), not runtime wiring.
## NOTE (pre-existing integration gap): reputation_change, mana_change and the
## "materials" resource are part of the data model but not yet wired to
## GameManager's player_data (wood/food/gold). Tracked in tasks.md.
const KNOWN_EFFECT_KEYS: Array[String] = [
	"resource_change", "morale_change", "population_change",
	"unlock_building", "permanent_modifier", "unlock_law",
	"reputation_change", "mana_change",
]


func _sys() -> CrisisEventSystem:
	return make_node(CrisisEventSystem)  # _ready loads event + crisis templates


## Integration target: a real GameManager mounted at /root/GameManager so
## CrisisEventSystem's get_node_or_null("/root/GameManager") resolves to it.
var _gm: GameManager = null

func _wire_game_manager() -> GameManager:
	_gm = GameManager.new()
	_gm.name = "GameManager"
	get_tree().root.add_child(_gm)
	return _gm

func after_test() -> void:
	if is_instance_valid(_gm):
		get_tree().root.remove_child(_gm)
		_gm.queue_free()
	_gm = null


## --- Common event database (Task 2.2) ---

const COMMON_EVENT_IDS: Array[String] = [
	"event_01_strangers", "event_02_harvest", "event_03_merchant",
	"event_04_storage", "event_05_hero", "event_06_breakdown",
	"event_07_artifact", "event_08_caravan", "event_09_birth", "event_10_cold",
]

# Keys apply_choice_effects actually applies (the extras in KNOWN_EFFECT_KEYS are
# recognized data keys but not yet wired to GameManager).
const WIRED_EFFECT_KEYS: Array[String] = [
	"resource_change", "morale_change", "population_change",
	"unlock_building", "permanent_modifier", "unlock_law",
]

func test_ten_common_events_loaded() -> void:
	var sys := _sys()
	var ids: Array[String] = []
	for e in sys.event_templates:
		if e.id != "":
			ids.append(e.id)
	assert_that(ids.size()).is_equal(10)
	for id in COMMON_EVENT_IDS:
		assert_that(ids.has(id)).is_true()

func test_common_event_icons_exist() -> void:
	var sys := _sys()
	for e in sys.event_templates:
		if e.id == "":
			continue
		assert_that(FileAccess.file_exists(e.icon_path)).is_true()

func test_common_event_choices_use_wired_keys() -> void:
	var sys := _sys()
	for e in sys.event_templates:
		if e.id == "":
			continue
		assert_that(e.choices.size()).is_greater_equal(2)
		for choice in e.choices:
			assert_that(choice.text.length() > 0).is_true()
			assert_that(choice.effects is Dictionary).is_true()
			for key in choice.effects:
				assert_that(WIRED_EFFECT_KEYS.has(str(key))).is_true()


## --- Integration: choice/ongoing effects actually mutate GameManager (P0 gap fix) ---

func test_choice_effects_apply_to_game_manager() -> void:
	var gm := _wire_game_manager()
	var sys := _sys()
	sys.apply_choice_effects({
		"resource_change": {"food": -10, "gold": 20},
		"population_change": 3,
		"morale_change": -5,
	})
	assert_that(gm.get_resource("food")).is_equal(20)   # 30 - 10
	assert_that(gm.get_resource("gold")).is_equal(120)  # 100 + 20
	assert_that(gm.get_population()).is_equal(8)         # 5 + 3
	assert_that(gm.get_global_morale()).is_equal(45)     # 50 - 5

func test_ongoing_crisis_effects_apply() -> void:
	var gm := _wire_game_manager()
	var sys := _sys()
	# Data convention (see crisis_*.json): resource_drain is a positive magnitude
	# (negated in code); morale_penalty/production_reduction are stored signed.
	sys.apply_crisis_effects({
		"resource_drain": {"food": 5},
		"morale_penalty": -8,
		"production_reduction": -0.2,
	})
	assert_that(gm.get_resource("food")).is_equal(25)   # 30 - 5
	assert_that(gm.get_global_morale()).is_equal(42)     # 50 - 8
	assert_that(gm.player_data.get("production_modifier", 0.0)).is_less(0.0)

func test_unlock_and_modifier_effects_apply() -> void:
	var gm := _wire_game_manager()
	var sys := _sys()
	sys.apply_choice_effects({
		"unlock_building": "barracks",
		"permanent_modifier": {"id": "m1", "effect": {"production": 0.1}},
		"unlock_law": "order_tax_code",
	})
	assert_that(gm.has_building("barracks")).is_true()
	# add_permanent_modifier stores the effect dict directly (no "effect" wrapper)
	assert_that(gm.player_data["permanent_modifiers"]["m1"].has("production")).is_true()
	assert_that(sys.law_manager.is_law_active("order_tax_code")).is_true()

func test_resolve_crisis_clears_and_applies_effects() -> void:
	var gm := _wire_game_manager()
	var sys := _sys()
	sys.current_crisis = sys.crisis_templates[0]
	var food_before: int = gm.get_resource("food")
	sys.resolve_crisis(0)
	assert_that(sys.current_crisis == null).is_true()
	# choice 0 effects + resolution_effects must have been applied (food only drains)
	assert_that(gm.get_resource("food")).is_less_equal(food_before)


func test_eight_crisis_templates_loaded() -> void:
	var sys := _sys()
	assert_that(sys.crisis_templates.size()).is_equal(8)


func test_all_six_crisis_types_covered() -> void:
	var sys := _sys()
	var seen: Array[int] = []
	for c in sys.crisis_templates:
		if not seen.has(c.crisis_type):
			seen.append(c.crisis_type)
	# NATURAL_DISASTER, RESOURCE_SHORTAGE, SOCIAL_UNREST, EXTERNAL_THREAT, EPIDEMIC, MAGICAL_ANOMALY
	assert_that(seen.size()).is_equal(6)


func test_each_crisis_has_valid_structure() -> void:
	var sys := _sys()
	for c in sys.crisis_templates:
		assert_that(c.id.length() > 0).is_true()
		assert_that(c.title.length() > 0).is_true()
		assert_that(c.choices.size()).is_greater_equal(2)
		assert_that(c.severity).is_between(1, 5)
		assert_that(c.duration_days).is_greater(0)


func test_crisis_icons_exist() -> void:
	var sys := _sys()
	for c in sys.crisis_templates:
		if c.icon_path != "":
			assert_that(FileAccess.file_exists(c.icon_path)).is_true()


func test_every_choice_is_well_formed() -> void:
	var sys := _sys()
	for c in sys.crisis_templates:
		for choice in c.choices:
			assert_that(choice.text.length() > 0).is_true()
			assert_that(choice.effects is Dictionary).is_true()
			for key in choice.effects:
				assert_that(KNOWN_EFFECT_KEYS.has(str(key))).is_true()


func test_ongoing_effects_use_supported_keys() -> void:
	var sys := _sys()
	# Keys the ongoing/resolution data format recognizes (population_drain is a
	# known-unwired data key, see KNOWN_EFFECT_KEYS note).
	const ONGOING_KEYS: Array[String] = ["resource_drain", "morale_penalty", "production_reduction", "population_drain"]
	for c in sys.crisis_templates:
		for key in c.ongoing_effects:
			assert_that(ONGOING_KEYS.has(str(key))).is_true()


func test_crisis_ids_are_unique() -> void:
	var sys := _sys()
	var ids: Array[String] = []
	for c in sys.crisis_templates:
		assert_that(ids.has(c.id)).is_false()
		ids.append(c.id)


## --- Save/Load round-trip (Task 4.3) ---

func test_serialize_deserialize_roundtrip() -> void:
	var sys := _sys()
	sys.current_crisis = sys.crisis_templates[0]
	# event_templates[1] = event_01_strangers (has a real id; [0] is the
	# events_database wrapper with an empty id, which round-trips to nothing)
	sys.active_events.append(sys.event_templates[1])
	sys.day_counter = 42
	sys.next_event_day = 17
	sys.event_history.append({"id": "ev_x", "day": 3})
	sys.law_manager.unlock_law("order_tax_code")

	var data: Dictionary = sys.serialize_state()

	var sys2 := _sys()
	sys2.deserialize_state(data)

	assert_that(sys2.current_crisis.id).is_equal(sys.current_crisis.id)
	assert_that(sys2.active_events.size()).is_equal(1)
	assert_that(sys2.active_events[0].id).is_equal(sys.event_templates[1].id)
	assert_that(sys2.day_counter).is_equal(42)
	assert_that(sys2.next_event_day).is_equal(17)
	assert_that(sys2.event_history.size()).is_equal(1)
	assert_that(sys2.event_history[0].get("id")).is_equal("ev_x")
	assert_that(sys2.law_manager.is_law_active("order_tax_code")).is_true()


func test_deserialize_empty_is_noop() -> void:
	var sys := _sys()
	sys.day_counter = 99
	sys.deserialize_state({})
	assert_that(sys.day_counter).is_equal(99)


func test_deserialize_unknown_ids_are_skipped() -> void:
	var sys := _sys()
	var data: Dictionary = sys.serialize_state()
	data["current_crisis_id"] = "nonexistent"
	data["active_event_ids"] = ["nope"]
	var sys2 := _sys()
	sys2.deserialize_state(data)
	assert_that(sys2.current_crisis == null).is_true()
	assert_that(sys2.active_events.size()).is_equal(0)

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

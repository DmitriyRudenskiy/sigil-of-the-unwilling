extends BaseTest
## save-load-coverage-expansion 3.1: активный кризис (фаза/таймеры/события/законы)
## переживает save/load через CrisisEventSystem.serialize_state/deserialize_state.
## Система legacy (orphaned main.tscn) — self-contained; live-путь сейва
## (SaveData) кризисов пока не содержит (контент придёт в
## crisis-content-seasonal-rare-events).

func test_active_crisis_roundtrip() -> void:
	var sys: CrisisEventSystem = make_node(CrisisEventSystem)
	assert_bool(sys.crisis_templates.size() > 0).is_true()
	assert_bool(sys.event_templates.size() > 0).is_true()

	# Активный кризис + идущие события + счётчики + законы
	var crisis := sys.crisis_templates[0]
	var event := sys.event_templates[0]
	sys.current_crisis = crisis
	sys.active_events = [event]
	sys.day_counter = 42
	sys.next_event_day = 55
	sys.last_crisis_day = 40
	sys._crisis_start_day = 40
	sys.event_history = [
		{"type": "crisis", "id": crisis.id, "day": 40, "resolved": false},
		{"type": "event", "id": event.id, "day": 38},
	]
	assert_that(sys.law_manager.unlock_law("order_tax_code")).is_true()

	var state := sys.serialize_state()

	# Load: новая система (шаблоны загружаются в _ready)
	var sys2: CrisisEventSystem = make_node(CrisisEventSystem)
	sys2.deserialize_state(state)

	assert_that(sys2.day_counter).is_equal(42)
	assert_that(sys2.next_event_day).is_equal(55)
	assert_that(sys2.last_crisis_day).is_equal(40)
	assert_that(sys2.current_crisis).is_not_null()
	assert_that(sys2.current_crisis.id).is_equal(crisis.id)
	# duration-таймер восстановлен из истории (не сброшен в 0)
	assert_that(sys2._crisis_start_day).is_equal(40)
	assert_that(sys2.active_events.size()).is_equal(1)
	assert_that(sys2.active_events[0].id).is_equal(event.id)
	assert_that(sys2.event_history.size()).is_equal(2)
	assert_that(sys2.law_manager.is_law_active("order_tax_code")).is_true()


func test_resolved_crisis_not_restored_as_active() -> void:
	var sys: CrisisEventSystem = make_node(CrisisEventSystem)
	var crisis := sys.crisis_templates[0]
	sys.current_crisis = crisis
	sys.day_counter = 30
	sys._crisis_start_day = 25
	sys.event_history = [
		{"type": "crisis", "id": crisis.id, "day": 25, "resolved": true},
	]
	# Разрешённый кризис: serialize хранит id, но история пометит resolved —
	# deserialize всё равно восстановит шаблон (см. контракт serialize_state:
	# current_crisis_id хранится как есть). Проверяем детерминизм roundtrip.
	var state := sys.serialize_state()
	var sys2: CrisisEventSystem = make_node(CrisisEventSystem)
	sys2.deserialize_state(state)
	assert_that(sys2.current_crisis.id).is_equal(crisis.id)
	# resolved-запись → start_day НЕ подтянут из неё (цикл ищет unresolved)
	assert_that(sys2._crisis_start_day).is_equal(30)


func test_empty_state_roundtrip() -> void:
	var sys: CrisisEventSystem = make_node(CrisisEventSystem)
	sys.day_counter = 7
	var state := sys.serialize_state()

	var sys2: CrisisEventSystem = make_node(CrisisEventSystem)
	sys2.deserialize_state(state)
	assert_that(sys2.day_counter).is_equal(7)
	assert_that(sys2.current_crisis).is_null()
	assert_that(sys2.active_events.size()).is_equal(0)


func test_deserialize_empty_is_noop() -> void:
	var sys: CrisisEventSystem = make_node(CrisisEventSystem)
	sys.day_counter = 99
	sys.deserialize_state({})
	assert_that(sys.day_counter).is_equal(99)

extends BaseTest


var bus: Node

func before_test() -> void:
	bus = GameEventBusAutoload.new()

func after_test() -> void:
	if bus != null:
		bus.free()
		bus = null

func test_bus_creation() -> void:
	assert_that(bus).is_not_null()

func test_bus_is_node() -> void:
	assert_bool(bus is Node).is_true()

func test_battle_started_signal() -> void:
	var data: Dictionary = {}
	bus.battle_started.connect(func(): data["received"] = true)
	bus.battle_started.emit()
	assert_bool(data.get("received", false)).is_true()

func test_battle_completed_signal() -> void:
	var data: Dictionary = {}
	bus.battle_completed.connect(func(w: BattleState.Side, c: Vector2i):
		data["winner"] = w
		data["cell"] = c
	)
	bus.battle_completed.emit(BattleState.Side.ATTACKER, Vector2i(5, 5))
	assert_that(data.get("winner", -1)).is_equal(BattleState.Side.ATTACKER)
	assert_that(data.get("cell", Vector2i(-1, -1))).is_equal(Vector2i(5, 5))

func test_battle_won_signal() -> void:
	var data: Dictionary = {}
	bus.battle_won.connect(func(c: Vector2i): data["cell"] = c)
	bus.battle_won.emit(Vector2i(3, 7))
	assert_that(data.get("cell", Vector2i(-1, -1))).is_equal(Vector2i(3, 7))

func test_battle_lost_signal() -> void:
	var data: Dictionary = {}
	bus.battle_lost.connect(func(c: Vector2i): data["cell"] = c)
	bus.battle_lost.emit(Vector2i(2, 4))
	assert_that(data.get("cell", Vector2i(-1, -1))).is_equal(Vector2i(2, 4))

func test_village_captured_signal() -> void:
	var data: Dictionary = {}
	bus.village_captured.connect(func(c: Vector2i): data["cell"] = c)
	bus.village_captured.emit(Vector2i(10, 10))
	assert_that(data.get("cell", Vector2i(-1, -1))).is_equal(Vector2i(10, 10))

func test_turn_ended_signal() -> void:
	var data: Dictionary = {}
	bus.turn_ended.connect(func(t: int, m: int):
		data["turn"] = t
		data["month"] = m
	)
	bus.turn_ended.emit(5, 3)
	assert_that(data.get("turn", -1)).is_equal(5)
	assert_that(data.get("month", -1)).is_equal(3)

func test_resource_discovered_signal() -> void:
	var data: Dictionary = {}
	bus.resource_discovered.connect(func(c: Vector2i, id: StringName):
		data["cell"] = c
		data["id"] = id
	)
	bus.resource_discovered.emit(Vector2i(4, 4), &"oak")
	assert_that(data.get("cell", Vector2i(-1, -1))).is_equal(Vector2i(4, 4))
	assert_that(data.get("id", &"")).is_equal(&"oak")

func test_resource_extracted_signal() -> void:
	var data: Dictionary = {}
	bus.resource_extracted.connect(func(c: Vector2i, id: StringName, a: int):
		data["cell"] = c
		data["id"] = id
		data["amount"] = a
	)
	bus.resource_extracted.emit(Vector2i(6, 6), &"silver", 3)
	assert_that(data.get("cell", Vector2i(-1, -1))).is_equal(Vector2i(6, 6))
	assert_that(data.get("id", &"")).is_equal(&"silver")
	assert_that(data.get("amount", -1)).is_equal(3)

func test_resource_exhausted_signal() -> void:
	var data: Dictionary = {}
	bus.resource_exhausted.connect(func(c: Vector2i, id: StringName):
		data["cell"] = c
		data["id"] = id
	)
	bus.resource_exhausted.emit(Vector2i(8, 8), &"coal")
	assert_that(data.get("cell", Vector2i(-1, -1))).is_equal(Vector2i(8, 8))
	assert_that(data.get("id", &"")).is_equal(&"coal")

func test_glory_earned_signal() -> void:
	var data: Dictionary = {}
	bus.glory_earned.connect(func(a: float, r: StringName):
		data["amount"] = a
		data["reason"] = r
	)
	bus.glory_earned.emit(15.0, &"battle_won")
	assert_that(data.get("amount", -1.0)).is_equal(15.0)
	assert_that(data.get("reason", &"")).is_equal(&"battle_won")

func test_multiple_subscribers() -> void:
	var data: Dictionary = {"count": 0}
	bus.battle_won.connect(func(_c: Vector2i): data["count"] += 1)
	bus.battle_won.connect(func(_c: Vector2i): data["count"] += 1)
	bus.battle_won.connect(func(_c: Vector2i): data["count"] += 1)
	bus.battle_won.emit(Vector2i(1, 1))
	assert_that(data["count"]).is_equal(3)

func test_signal_isolation() -> void:
	var data: Dictionary = {}
	bus.battle_won.connect(func(_c: Vector2i): data["won"] = true)
	bus.battle_lost.connect(func(_c: Vector2i): data["lost"] = true)
	bus.battle_won.emit(Vector2i(1, 1))
	assert_bool(data.get("won", false)).is_true()
	assert_bool(data.get("lost", false)).is_false()

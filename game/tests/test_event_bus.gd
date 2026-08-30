extends "res://tests/test_base.gd"
## Тесты шины событий: испускание, подписка, типы сигналов.

const _GameEventBus = preload("res://core/GameEventBus.gd")

var bus: Node

func before_each() -> void:
	bus = _GameEventBus.new()

func after_each() -> void:
	if bus != null:
		bus.free()
		bus = null

# ==================== СОЗДАНИЕ ====================

func test_bus_creation() -> void:
	assert_not_null(bus, "bus created")

func test_bus_is_node() -> void:
	assert_true(bus is Node, "bus is Node")

# ==================== БОЙ ====================

func test_battle_started_signal() -> void:
	var data: Dictionary = {}
	bus.battle_started.connect(func(): data["received"] = true)
	bus.battle_started.emit()
	assert_true(data.get("received", false), "battle_started received")

func test_battle_completed_signal() -> void:
	var data: Dictionary = {}
	bus.battle_completed.connect(func(w: BattleState.Side, c: Vector2i):
		data["winner"] = w
		data["cell"] = c
	)
	bus.battle_completed.emit(BattleState.Side.ATTACKER, Vector2i(5, 5))
	assert_eq(data.get("winner", -1), BattleState.Side.ATTACKER, "winner is attacker")
	assert_eq(data.get("cell", Vector2i(-1, -1)), Vector2i(5, 5), "cell is (5,5)")

func test_battle_won_signal() -> void:
	var data: Dictionary = {}
	bus.battle_won.connect(func(c: Vector2i): data["cell"] = c)
	bus.battle_won.emit(Vector2i(3, 7))
	assert_eq(data.get("cell", Vector2i(-1, -1)), Vector2i(3, 7), "battle_won cell")

func test_battle_lost_signal() -> void:
	var data: Dictionary = {}
	bus.battle_lost.connect(func(c: Vector2i): data["cell"] = c)
	bus.battle_lost.emit(Vector2i(2, 4))
	assert_eq(data.get("cell", Vector2i(-1, -1)), Vector2i(2, 4), "battle_lost cell")

# ==================== МИР ====================

func test_village_captured_signal() -> void:
	var data: Dictionary = {}
	bus.village_captured.connect(func(c: Vector2i): data["cell"] = c)
	bus.village_captured.emit(Vector2i(10, 10))
	assert_eq(data.get("cell", Vector2i(-1, -1)), Vector2i(10, 10), "village_captured cell")

func test_turn_ended_signal() -> void:
	var data: Dictionary = {}
	bus.turn_ended.connect(func(t: int, m: int):
		data["turn"] = t
		data["month"] = m
	)
	bus.turn_ended.emit(5, 3)
	assert_eq(data.get("turn", -1), 5, "turn is 5")
	assert_eq(data.get("month", -1), 3, "month is 3")

# ==================== РЕСУРСЫ ====================

func test_resource_discovered_signal() -> void:
	var data: Dictionary = {}
	bus.resource_discovered.connect(func(c: Vector2i, id: StringName):
		data["cell"] = c
		data["id"] = id
	)
	bus.resource_discovered.emit(Vector2i(4, 4), &"oak")
	assert_eq(data.get("cell", Vector2i(-1, -1)), Vector2i(4, 4), "discovered cell")
	assert_eq(data.get("id", &""), &"oak", "discovered resource id")

func test_resource_extracted_signal() -> void:
	var data: Dictionary = {}
	bus.resource_extracted.connect(func(c: Vector2i, id: StringName, a: int):
		data["cell"] = c
		data["id"] = id
		data["amount"] = a
	)
	bus.resource_extracted.emit(Vector2i(6, 6), &"silver", 3)
	assert_eq(data.get("cell", Vector2i(-1, -1)), Vector2i(6, 6), "extracted cell")
	assert_eq(data.get("id", &""), &"silver", "extracted resource id")
	assert_eq(data.get("amount", -1), 3, "extracted amount")

func test_resource_exhausted_signal() -> void:
	var data: Dictionary = {}
	bus.resource_exhausted.connect(func(c: Vector2i, id: StringName):
		data["cell"] = c
		data["id"] = id
	)
	bus.resource_exhausted.emit(Vector2i(8, 8), &"coal")
	assert_eq(data.get("cell", Vector2i(-1, -1)), Vector2i(8, 8), "exhausted cell")
	assert_eq(data.get("id", &""), &"coal", "exhausted resource id")

# ==================== СЛАВА ====================

func test_glory_earned_signal() -> void:
	var data: Dictionary = {}
	bus.glory_earned.connect(func(a: float, r: StringName):
		data["amount"] = a
		data["reason"] = r
	)
	bus.glory_earned.emit(15.0, &"battle_won")
	assert_eq(data.get("amount", -1.0), 15.0, "glory amount")
	assert_eq(data.get("reason", &""), &"battle_won", "glory reason")

# ==================== МНОЖЕСТВЕННЫЕ ПОДПИСЧИКИ ====================

func test_multiple_subscribers() -> void:
	var data: Dictionary = {"count": 0}
	bus.battle_won.connect(func(_c: Vector2i): data["count"] += 1)
	bus.battle_won.connect(func(_c: Vector2i): data["count"] += 1)
	bus.battle_won.connect(func(_c: Vector2i): data["count"] += 1)
	bus.battle_won.emit(Vector2i(1, 1))
	assert_eq(data["count"], 3, "3 subscribers received")

func test_signal_isolation() -> void:
	var data: Dictionary = {}
	bus.battle_won.connect(func(_c: Vector2i): data["won"] = true)
	bus.battle_lost.connect(func(_c: Vector2i): data["lost"] = true)
	bus.battle_won.emit(Vector2i(1, 1))
	assert_true(data.get("won", false), "battle_won received")
	assert_false(data.get("lost", false), "battle_lost NOT received")

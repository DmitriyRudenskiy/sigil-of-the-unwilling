extends "res://tests/gut_base.gd"
## 1.6 Порт tools/memory_profile.gd: пять операций с профилированием памяти.
##
## Детерминированный инвариант для CI: дельта выделения памяти по каждой
## операции должна быть конечной и неотрицательной (direction/sanity — не
## конкретный КБ, как указано в design.md). Точные КБ зависят от железа/версии.

const _UnitRegistry = preload("res://scripts/autoload/UnitRegistry.gd")

var _deltas: Array = []

func _measure(name: String, fn: Callable) -> void:
	var mem_before := OS.get_static_memory_usage()
	var result = fn.call()
	var mem_after := OS.get_static_memory_usage()
	var delta_kb := (mem_after - mem_before) / 1024
	_deltas.append([name, delta_kb])

func test_memory_profile_deltas_finite_and_nonnegative() -> void:
	_measure("MapModel 60x60 generate", func():
		var model = load("res://scripts/world/MapModel.gd").new()
		model.map_width = 60
		model.map_height = 60
		model.seed_value = 42
		model.generate_noise()
		return model
	)

	_measure("BattleState full battle", func():
		var state = load("res://scripts/systems/BattleState.gd").new()
		var ureg = _UnitRegistry.new()
		var atk: Array[UnitStack] = []
		var def: Array[UnitStack] = []
		for i in 8:
			atk.append(ureg.make_fixed_stack("swordsmen", 20))
			def.append(ureg.make_fixed_stack("goblins", 20))
		state.place_army(atk, def)
		state.build_queue()
		ureg.free()
		return state
	)

	_measure("SpellbookRegistry 420 spells", func():
		var reg = load("res://scripts/autoload/SpellbookRegistry.gd").new()
		reg.ensure_definitions()
		reg.free()
		return reg
	)

	_measure("SaveData roundtrip", func():
		var data = load("res://scripts/core/SaveData.gd").new()
		data.run_seed = 12345
		data.hero = {"cell": {"x": 10, "y": 20}, "army": [], "inventory": {}}
		data.world = {}
		var json := JSON.stringify(data.to_dict())
		var parsed = JSON.parse_string(json)
		var data2 = load("res://scripts/core/SaveData.gd").new()
		data2.from_dict(parsed)
		return data2
	)

	_measure("PlaceholderTexture 10 circles", func():
		var textures: Array = []
		for i in 10:
			var col := Color(float(i) / 10.0, 0.5, 0.5)
			textures.append(PlaceholderTexture.circle(22, col, Color(0.1, 0.1, 0.1)))
		return textures
	)

	assert_true(_deltas.size() == 5, "all five operations profiled (got: %d)" % _deltas.size())
	for entry in _deltas:
		var name: String = entry[0]
		var delta: float = entry[1]
		assert_true(delta == delta, "%s delta is finite (not NaN)" % name)
		assert_true(delta >= 0.0, "%s delta is non-negative (%.1f KB)" % [name, delta])

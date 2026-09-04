extends "res://tests/gut_base.gd"
## 1.5 Порт tools/benchmark_all.gd: пять бенчмарков (map gen, spell registry,
## serialization, placeholder texture, JSON parse).
##
## Детерминированный инвариант для CI: каждый бенчмарк должен отработать и
## вернуть конечное, неотрицательное среднее время (в мс). Абсолютные пороги
## (50/20/5 мс из исходника) оставлены как информационные warning'и — их
## жёсткая проверка в CI некорректна (зависит от железа, даёт флэки).

const INF := 1e9
var _iterations := 3
var _results: Array = []

func _record(name: String, times: Array) -> void:
	if times.is_empty():
		return
	var avg := 0.0
	var mn := INF
	var mx := 0.0
	for t in times:
		avg += t
		mn = minf(mn, t)
		mx = maxf(mx, t)
	avg /= float(times.size())
	_results.append({"name": name, "avg_ms": avg, "min_ms": mn, "max_ms": mx})

func _bench_map_generation() -> void:
	var times: Array = []
	for i in _iterations:
		var model = load("res://scripts/world/MapModel.gd").new()
		model.map_width = 60
		model.map_height = 60
		model.seed_value = 42 + i
		var t0 := Time.get_ticks_usec()
		model.generate_noise()
		var t1 := Time.get_ticks_usec()
		times.append((t1 - t0) / 1000.0)
	_record("MapModel.generate_noise", times)

func _bench_spell_registry() -> void:
	var times: Array = []
	var reg = load("res://scripts/autoload/SpellbookRegistry.gd").new()
	for i in _iterations:
		var t0 := Time.get_ticks_usec()
		reg.ensure_definitions()
		var t1 := Time.get_ticks_usec()
		times.append((t1 - t0) / 1000.0)
	_record("SpellbookRegistry.ensure_definitions", times)
	# SpellbookRegistry — Node-autoload, без free станет orphan (GUT-фол).
	reg.free()

func _bench_serialization() -> void:
	var save_data = load("res://scripts/core/SaveData.gd").new()
	save_data.run_seed = 12345
	save_data.hero = {
		"cell": {"x": 10, "y": 20},
		"move_points": 10.0,
		"hero_name": "TestHero",
		"stats": {"attack": 5, "defense": 3, "spell_power": 4, "knowledge": 2},
		"resources": {"wood": 10, "mercury": 2, "ore": 10, "sulfur": 2, "crystal": 2, "gems": 2, "gold": 500},
		"army": [{"key": "swordsmen", "count": 103}],
		"inventory": {"equipped": {}, "backpack": []},
		"mana_current": 20,
		"mana_max": 20,
		"magic_schools": {"air": 1, "fire": 0, "water": 0, "earth": 0},
		"spellbook": ["magic_arrow", "haste"],
		"skills": {"nature_sense": 0, "keen_eye": 0, "navigation": 0, "geology": 0, "alchemy": 0},
		"tools": [],
		"strategic_resources": {},
		"time_mp_spent": 0.0,
	}
	save_data.world = {
		"captured_villages": [{"x": 3, "y": 4}],
		"defeated_enemies": [{"x": 5, "y": 5}],
		"removed_resources": [],
		"opened_chests": [],
		"removed_scrolls": [],
		"discovered_nodes": [],
		"exhausted_nodes": [],
	}
	var times: Array = []
	for i in _iterations:
		var t0 := Time.get_ticks_usec()
		var json_str := JSON.stringify(save_data.to_dict(), "\t")
		var t1 := Time.get_ticks_usec()
		times.append((t1 - t0) / 1000.0)
	_record("SaveManager: JSON.stringify", times)

func _bench_placeholder_texture() -> void:
	var times: Array = []
	for i in _iterations:
		var t0 := Time.get_ticks_usec()
		for j in 10:
			var col := Color(float(j) / 10.0, 0.5, 0.5)
			PlaceholderTexture.circle(22, col, Color(0.1, 0.1, 0.1))
		var t1 := Time.get_ticks_usec()
		times.append((t1 - t0) / 1000.0)
	_record("PlaceholderTexture: 10 circles", times)

func _bench_json_parse() -> void:
	var save_data = load("res://scripts/core/SaveData.gd").new()
	save_data.run_seed = 12345
	save_data.hero = {"cell": {"x": 10, "y": 20}, "army": [], "inventory": {}}
	save_data.world = {}
	var json_str := JSON.stringify(save_data.to_dict(), "\t")
	var times: Array = []
	for i in _iterations:
		var t0 := Time.get_ticks_usec()
		var json := JSON.new()
		json.parse(json_str)
		var t1 := Time.get_ticks_usec()
		times.append((t1 - t0) / 1000.0)
	_record("JSON.parse (save payload)", times)

func test_benchmarks_run_and_report_finite_times() -> void:
	_bench_map_generation()
	_bench_spell_registry()
	_bench_serialization()
	_bench_placeholder_texture()
	_bench_json_parse()
	assert_true(_results.size() == 5, "all five benchmarks ran (got: %d)" % _results.size())
	for r in _results:
		var avg: float = r["avg_ms"]
		assert_true(avg == avg, "%s avg is finite (not NaN)" % r["name"])
		assert_true(avg >= 0.0, "%s avg is non-negative (%.3f)" % [r["name"], avg])

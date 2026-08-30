extends SceneTree
## Комплексный бенчмарк производительности.
## Запуск: godot --headless -s tools/benchmark_all.gd
##
## Флаги:
##   --iterations N   Количество повторений (по умолчанию 10)
##   --map-size W H   Размер карты (по умолчанию 60 60)

var _results: Array = []
var _iterations := 10
var _map_w := 60
var _map_h := 60
const INF := 1e9

func _init() -> void:
	var args := OS.get_cmdline_args()
	for i in args.size():
		if args[i] == "--iterations" and i + 1 < args.size():
			_iterations = int(args[i + 1])
		elif args[i] == "--map-size" and i + 2 < args.size():
			_map_w = int(args[i + 1])
			_map_h = int(args[i + 2])

	print("=== Performance Benchmark Suite ===")
	print("Iterations: %d, Map: %dx%d" % [_iterations, _map_w, _map_h])
	print("")

	_bench_map_generation()
	_bench_spell_registry()
	_bench_serialization()
	_bench_placeholder_texture()
	_bench_json_parse()

	_print_summary()
	quit(0)

# ==================== 1. ГЕНЕРАЦИЯ КАРТЫ ====================
func _bench_map_generation() -> void:
	var times: Array = []
	for i in _iterations:
		var model = load("res://world/MapModel.gd").new()
		model.map_width = _map_w
		model.map_height = _map_h
		model.seed_value = 42 + i
		var t0 := Time.get_ticks_usec()
		model.generate_noise()
		var t1 := Time.get_ticks_usec()
		times.append((t1 - t0) / 1000.0)
	_record("MapModel.generate_noise", times)

# ==================== 2. КАРТОЧНАЯ СИСТЕМА ====================
func _bench_spell_registry() -> void:
	var times: Array = []
	for i in _iterations:
		var reg = load("res://data/SpellbookRegistry.gd").new()
		var t0 := Time.get_ticks_usec()
		reg.ensure_definitions()
		var t1 := Time.get_ticks_usec()
		times.append((t1 - t0) / 1000.0)
	_record("SpellbookRegistry.ensure_definitions", times)

# ==================== 3. СЕРИАЛИЗАЦИЯ ====================
func _bench_serialization() -> void:
	var times: Array = []
	var save_data = load("res://core/SaveData.gd").new()
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
	for i in _iterations:
		var t0 := Time.get_ticks_usec()
		var json_str := JSON.stringify(save_data.to_dict(), "\t")
		var t1 := Time.get_ticks_usec()
		times.append((t1 - t0) / 1000.0)
	_record("SaveManager: JSON.stringify", times)

# ==================== 4. PLACEHOLDER TEXTURE ====================
func _bench_placeholder_texture() -> void:
	var times: Array = []
	for i in _iterations:
		var t0 := Time.get_ticks_usec()
		for j in 10:
			var col := Color(float(j) / 10.0, 0.5, 0.5)
			PlaceholderTexture.circle(22, col, Color(0.1, 0.1, 0.1))
		var t1 := Time.get_ticks_usec()
		times.append((t1 - t0) / 1000.0)
	_record("PlaceholderTexture: 10 circles (cold)", times)

	# Тёплый кэш
	var times2: Array = []
	for i in _iterations:
		var t0 := Time.get_ticks_usec()
		for j in 10:
			var col := Color(float(j) / 10.0, 0.5, 0.5)
			PlaceholderTexture.circle(22, col, Color(0.1, 0.1, 0.1))
		var t1 := Time.get_ticks_usec()
		times2.append((t1 - t0) / 1000.0)
	_record("PlaceholderTexture: 10 circles (cached)", times2)

# ==================== 5. JSON PARSE (big payload) ====================
func _bench_json_parse() -> void:
	var save_data = load("res://core/SaveData.gd").new()
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

# ==================== УТИЛИТЫ ====================
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
	_results.append({
		"name": name,
		"avg_ms": avg,
		"min_ms": mn,
		"max_ms": mx,
		"iterations": times.size(),
	})
	print("  %-45s avg: %8.2f ms  min: %8.2f ms  max: %8.2f ms" % [name, avg, mn, mx])

func _print_summary() -> void:
	print("")
	print("=== Summary ===")
	print("%-45s %10s %10s %10s" % ["Benchmark", "Avg (ms)", "Min (ms)", "Max (ms)"])
	print("-".repeat(75))
	for r in _results:
		print("%-45s %10.2f %10.2f %10.2f" % [r["name"], r["avg_ms"], r["min_ms"], r["max_ms"]])
	print("")

	# Целевые пороги
	var warnings := []
	for r in _results:
		var name: String = r["name"]
		var avg: float = r["avg_ms"]
		if name.contains("generate_noise") and avg > 50.0:
			warnings.append("Map generation > 50ms: %.1fms" % avg)
		if name.contains("SpellbookRegistry") and avg > 20.0:
			warnings.append("Spell registry > 20ms: %.1fms" % avg)
		if name.contains("stringify") and avg > 5.0:
			warnings.append("Serialization > 5ms: %.1fms" % avg)

	if warnings.is_empty():
		print("All benchmarks within target thresholds")
	else:
		print("Performance warnings:")
		for w in warnings:
			print("   - %s" % w)

	# JSON вывод
	var json_output := JSON.stringify({
		"benchmarks": _results,
		"map_size": {"w": _map_w, "h": _map_h},
		"iterations": _iterations,
		"warnings": warnings,
	}, "\t")
	var fa := FileAccess.open("res://benchmark_results.json", FileAccess.WRITE)
	if fa != null:
		fa.store_string(json_output)
		fa.close()
		print("Results saved to: res://benchmark_results.json")

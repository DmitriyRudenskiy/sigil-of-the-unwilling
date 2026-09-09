extends GdUnitTestSuite

const INF := 1e9
const BattleEmulator = preload("res://scripts/autoload/BattleEmulator.gd")
const UnitRegistry = preload("res://scripts/autoload/UnitRegistry.gd")
const UnitStats = preload("res://scripts/entities/UnitStats.gd")

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

## Из TestBattleRules (root): бой 7 стаков на 7 стаков (по 15 юнитов) < 1000 мс.
func test_battle_7v7_performance_under_1000ms() -> void:
	var units := UnitRegistry.new()
	units.ensure_definitions()
	var keys: Array[String] = [
		"swordsmen", "archers", "cavalry", "mages",
		"guardians", "champions", "knights",
	]
	var atk_army: Array = []
	var def_army: Array = []
	for k in keys:
		var st: UnitStats = units.get_definition(k)
		assert_bool(st != null).is_true()
		# emulate_battle собирает UnitStats из полей spec'а, а не из
		# реестра — передаём реальные статы, иначе бой из дефолтных 3/50 не решится.
		var spec := {
			"id": k, "name": k, "count": 15,
			"attack": st.attack, "base_damage": st.base_damage,
			"hp": st.hp, "speed": st.speed, "defense": st.defense,
			"tags": st.tags,
		}
		atk_army.append(spec.duplicate())
		def_army.append(spec.duplicate())
	var em := BattleEmulator.new()
	var t0 := Time.get_ticks_msec()
	var report: Dictionary = em.emulate_battle({
		"attacker_army": atk_army, "defender_army": def_army,
	})
	var ms := float(Time.get_ticks_msec() - t0)
	assert_bool(bool(report.get("battle_over", false))).is_true()
	assert_str(str(report.get("winner", ""))).is_not_empty()
	assert_int(int(report.get("turns", 0))).is_greater(0)
	assert_float(ms).is_less(1000.0)
	units.free()


func test_benchmarks_run_and_report_finite_times() -> void:
	_bench_map_generation()
	_bench_spell_registry()
	_bench_serialization()
	_bench_placeholder_texture()
	_bench_json_parse()
	assert_bool(_results.size() == 5).is_true()
	for r in _results:
		var avg: float = r["avg_ms"]
		assert_bool(avg == avg).is_true()
		assert_bool(avg >= 0.0).is_true()

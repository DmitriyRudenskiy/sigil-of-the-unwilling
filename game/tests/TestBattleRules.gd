extends GdUnitTestSuite

const BattleRules = preload("res://scripts/core/BattleRules.gd")
const UnitStats = preload("res://scripts/entities/UnitStats.gd")
const UnitStack = preload("res://scripts/entities/UnitStack.gd")
const BattleState = preload("res://scripts/systems/BattleState.gd")
const BattleEmulator = preload("res://scripts/autoload/BattleEmulator.gd")
const UnitRegistry = preload("res://scripts/autoload/UnitRegistry.gd")

var _rng: RandomNumberGenerator
var _attacker_unit: BattleState.BattleUnit
var _defender_unit: BattleState.BattleUnit

func before_test() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = 12345 # Детерминированный сид для тестов

	var atk_stats := UnitStats.new("orc", "Orc", 10, 5, 20, 5, 2, ["melee"])
	var def_stats := UnitStats.new("human", "Human", 5, 3, 10, 4, 5, ["melee"])
	# моки из ТЗ не работали (do_return на свойствах); реальные объекты дешевле
	_attacker_unit = BattleState.BattleUnit.new(UnitStack.new(atk_stats, 10))
	_defender_unit = BattleState.BattleUnit.new(UnitStack.new(def_stats, 10))


func test_calculate_attack_base_damage() -> void:
	var result := BattleRules.calculate_attack(_attacker_unit, _defender_unit, true, _rng, 0, 0)

	assert_bool(result.is_empty()).is_false()
	assert_int(result.get("damage", 0)).is_greater(0)
	# При ATK 10 vs DEF 5, множитель должен быть > 1.0 (ATK_ADVANTAGE_PER_POINT = 0.05)
	# base_damage 5 * 10 юнитов = 50..70 до множителя
	assert_int(result.get("damage", 0)).is_greater_equal(50)


# TASK_04: бой 7 стаков на 7 стаков (по 15 юнитов) должен завершаться < 1000 мс
func test_battle_7v7_performance() -> void:
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

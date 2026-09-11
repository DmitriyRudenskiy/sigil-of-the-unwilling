extends BaseTest


const BATTLES := 200

func _simulate(atk_key: String, def_key: String, seed: int) -> Dictionary:
	var emu := BattleEmulator.new()
	var atk: Array[UnitStack] = [Units.make_fixed_stack(atk_key, 10)]
	var def: Array[UnitStack] = [Units.make_fixed_stack(def_key, 10)]
	var state := BattleState.new()
	state.place_army(atk, def)
	var rng := TestFactories.seeded(9555)
	rng.seed = seed
	var report := emu.run_auto_battle(state, rng)
	report["decided"] = bool(report.get("battle_over", false))
	return report

func _side_rate(atk_key: String, def_key: String, seed_base: int, side: String) -> float:
	var wins := 0
	var decided := 0
	for i in BATTLES:
		var report := _simulate(atk_key, def_key, seed_base + i)
		if not report["decided"]:
			continue
		decided += 1
		if report["winner"] == side:
			wins += 1
	if decided == 0:
		return 0.5
	return float(wins) / float(decided)

func test_even_melee_fight_defender_advantage() -> void:
	var defender_rate := _side_rate("swordsmen", "swordsmen", 1000, "defender")
	assert_bool(defender_rate >= 0.50).is_true()

func test_ranged_wins_against_melee_at_distance() -> void:
	var attacker_rate := _side_rate("archers", "swordsmen", 2000, "attacker")
	assert_bool(attacker_rate >= 0.80).is_true()

func test_simulated_battles_are_deterministic_per_seed() -> void:
	var a := _simulate("archers", "swordsmen", 42)
	var b := _simulate("archers", "swordsmen", 42)
	assert_that(a["winner"]).is_equal(b["winner"])
	assert_that(a["turns"]).is_equal(b["turns"])

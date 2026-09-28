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

## tactical-combat-implementation (фазы 4/8.1): старое преимущество защитника в
## зеркальном мeel-бою было артефактом старого эмулятора (одно действие за ход:
## атакующий закрывал дистанцию, защитник бьёл первым в контакте). Эмулятор
## теперь повторяет игровое поведение (move+attack в тот же ход, контратака
## выжившего защитника) — в зеркальном бою перевес получает инициатор
## (первый ход + первый удар), но контратака даёт защитнику шанс.
## Измерено: атакующий ≈ 0.855.
func test_even_melee_fight_attacker_initiative_advantage() -> void:
	var attacker_rate := _side_rate("swordsmen", "swordsmen", 1000, "attacker")
	assert_bool(attacker_rate >= 0.50).is_true()

## tactical-combat-implementation (фаза 4): дальний бой ограничен дальностью
## 4 гекса (RANGED_MAX_RANGE) — лучник больше не чипает мечника с 16 гексов
## (старый неограниченный range давал «бесплатную» чип-фазу с первого хода).
## На ровной местности мечник закрывает дистанцию, но лучник контратакует
## (одна контратака за бой, как в игровом потоке) и выигрывает matchup
## (измерено: атакующий-лучник ≈ 0.615).
func test_ranged_wins_against_lone_melee_with_retaliation() -> void:
	var attacker_rate := _side_rate("archers", "swordsmen", 2000, "attacker")
	assert_bool(attacker_rate >= 0.50).is_true()

func test_simulated_battles_are_deterministic_per_seed() -> void:
	var a := _simulate("archers", "swordsmen", 42)
	var b := _simulate("archers", "swordsmen", 42)
	assert_that(a["winner"]).is_equal(b["winner"])
	assert_that(a["turns"]).is_equal(b["turns"])

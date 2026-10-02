extends BaseTest


## T17/D2 (K2, 02d v1.2): лестница перевеса — без RNG, бой детерминирован.
## Старые rate-тесты (200 боёв по seed'ам) бессмысленны: все 200 дают один и
## тот же исход. Теперь: один детерминированный прогон + коридор по раундам.
## ponytail: баланс юнитов под лестницу не ретьюнен — исходы зафиксированы
## как есть; ретьюн статов (например, archers в ближнем бою) — отдельная задача.

const ROUND_CAP := 60


func _simulate(atk_key: String, def_key: String, seed: int) -> Dictionary:
	var emu := BattleEmulator.new()
	var atk: Array[UnitStack] = [Units.make_fixed_stack(atk_key, 10)]
	var def: Array[UnitStack] = [Units.make_fixed_stack(def_key, 10)]
	var state := BattleState.new()
	state.place_army(atk, def)
	state.seed_dnd(seed)
	return emu.run_auto_battle(state)


## Зеркальный melee-бой: инициатор закрывает дистанцию первым и выигрывает
## (первый ход + первый удар; контратака защитника не компенсирует).
func test_even_melee_fight_attacker_wins() -> void:
	var r := _simulate("swordsmen", "swordsmen", 42)
	assert_bool(r.get("battle_over", false)).is_true()
	assert_str(str(r.get("winner", ""))).is_equal("attacker")
	assert_int(int(r.get("turns", 9999))).is_between(1, ROUND_CAP)


## Archers vs swordsmen: на лестнице мечник выигрывает — лучник теряет
## RANGED_MELEE_PENALTY в контакте, а дистанционной фазы почти нет
## (дистанция закрывается за первый раунд). Измерено на лестнице 02d v1.2.
func test_swordsmen_win_against_archers_on_ladder() -> void:
	var r := _simulate("archers", "swordsmen", 42)
	assert_bool(r.get("battle_over", false)).is_true()
	assert_str(str(r.get("winner", ""))).is_equal("defender")
	assert_int(int(r.get("turns", 9999))).is_between(1, ROUND_CAP)


func test_simulated_battles_are_deterministic_per_seed() -> void:
	var a := _simulate("archers", "swordsmen", 42)
	var b := _simulate("archers", "swordsmen", 42)
	assert_that(a["winner"]).is_equal(b["winner"])
	assert_that(a["turns"]).is_equal(b["turns"])

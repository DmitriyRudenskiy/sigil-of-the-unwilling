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


## Зеркальный melee-бой: бой решает ПЕРВЫЙ УДАР, а не сторона. На 17 колонок
## дистанцию первым закрывал инициатор и он же выигрывал; на 11×9 (смена
## battle-99-hex-clean-hud) стороны сходятся в один раунд и очередь (инициатива
## стека) разворачивает исход в пользу защитника. Что именно это значит для
## лестницы перевеса — вопрос владельцу (Q-M95), здесь зафиксирован замер.
func test_even_melee_fight_is_decided_by_initiative_not_side() -> void:
	var r := _simulate("swordsmen", "swordsmen", 42)
	assert_bool(r.get("battle_over", false)).is_true()
	assert_str(str(r.get("winner", ""))).is_equal("defender")
	assert_int(int(r.get("turns", 9999))).is_between(1, ROUND_CAP)


## Archers vs swordsmen: на 17 колонок мечник выигрывал — лучник теряет
## RANGED_MELEE_PENALTY в контакте, а дистанционной фазы почти нет. На 11×9
## атакующие лучники успевают дать залп раньше, чем их съедят, и выигрывают;
## ретьюн лучника под узкое поле — тот же Q-M95.
func test_archers_hold_their_own_on_narrow_field() -> void:
	var r := _simulate("archers", "swordsmen", 42)
	assert_bool(r.get("battle_over", false)).is_true()
	assert_str(str(r.get("winner", ""))).is_equal("attacker")
	assert_int(int(r.get("turns", 9999))).is_between(1, ROUND_CAP)


func test_simulated_battles_are_deterministic_per_seed() -> void:
	var a := _simulate("archers", "swordsmen", 42)
	var b := _simulate("archers", "swordsmen", 42)
	assert_that(a["winner"]).is_equal(b["winner"])
	assert_that(a["turns"]).is_equal(b["turns"])

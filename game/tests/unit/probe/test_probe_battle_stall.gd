extends BaseTest

## Матричный отчёт 2026-10-25 (задачи 9.2/9.3 цикла scenario-matrix-behavior-reliability,
## движок боя — T-205): Ranger/Trader (seed 465305719) встал в бой, где ни одна сторона
## не могла достать другую, и сжёг 21 211 кадров на ходе 20 — в предохранитель матрицы.
## На стороне автоигрока две заплатки, обе держат этот файл:
##
## 1) `pick_attack_target` — правила приёма атаки совпадают с
##    BattleTurnExecutor.request_attack. Прежняя политика брала «ближайшего врага на
##    d > 1» для любого дальнобойного; исполнитель такой запрос молча отклонял, а
##    автоигрок повторял его кадр за кадром.
## 2) `battle_progress_key` — сталл-сеть считается по необратимому прогрессу (позиции,
##    живость, состав стэков). По «активному юниту/has_moved» сеть не накапливала бы
##    никогда: BattleActionResolver.do_wait() перекладывает юнита в конец turn_queue, не
##    расходуя ход (T-205), и в бою-патруле очередь крутится между двумя юнитами.
##
## Поведение сети целиком (skip по прошествии BATTLE_STALL_WAIT_FRAMES, падение по
## BATTLE_STALL_FAIL_FRAMES) видно в матричном прогоне той же ячейки:
## `error=бой-висяк: ни движения, ни потерь 600 кадров (ход 20, …)` вместо молчаливого
## `done=false`. Здесь держится семантика ключа — то, что делало сеть слепой.

const RANGED: Array[String] = ["ranged"]
const MELEE: Array[String] = ["melee"]


func _unit(uid: int, cell: Vector2i, tags: Array[String], side: int, count: int = 5) -> BattleState.BattleUnit:
	var stats := UnitStats.new("u%d" % uid, "Unit %d" % uid, 1, 1, 10, 4, 0, tags)
	var u := BattleState.BattleUnit.new(UnitStack.new(stats, count))
	u.uid = uid
	u.cell = cell
	u.side = side
	return u


func _attacker(uid: int, cell: Vector2i, tags: Array[String], count: int = 5) -> BattleState.BattleUnit:
	return _unit(uid, cell, tags, BattleState.Side.ATTACKER, count)


func _defender(uid: int, cell: Vector2i, tags: Array[String] = MELEE, count: int = 5) -> BattleState.BattleUnit:
	return _unit(uid, cell, tags, BattleState.Side.DEFENDER, count)


func _state(units_a: Array, units_d: Array) -> BattleState:
	var bs := BattleState.new()
	for u in units_a:
		bs.attacker_units.append(u)
	for u in units_d:
		bs.defender_units.append(u)
	bs.build_queue()
	return bs


# ── 1) Выбор цели = правила приёма исполнителя ─────────────────────────────────────

## Дальнобойный стреляет только туда, куда пустит BattleLineOfSight.can_target_ranged
## (дальность ≤ GameNumbersBattle.RANGED_MAX_RANGE = 4). Отрицание непустое: тот же
## герой на дистанции 3 цель берёт.
func test_ranged_target_must_be_within_weapon_range() -> void:
	var hero := _attacker(1, Vector2i(5, 5), RANGED)
	var far := _defender(2, Vector2i(5, 11))
	var far_bs := _state([hero], [far])
	assert_bool(HexUtils.hex_distance(hero.cell, far.cell, true) > 4).is_true() \
		.override_failure_message("префикс сломан: «дальний» враг должен быть вне радиуса")
	assert_bool(BalanceProbe.pick_attack_target(far_bs, hero) == null).is_true() \
		.override_failure_message("цель вне радиуса нельзя выбирать: request_attack отклонит молча")

	var near := _defender(3, Vector2i(5, 8))
	var near_bs := _state([hero], [near])
	assert_bool(BalanceProbe.pick_attack_target(near_bs, hero) == near).is_true() \
		.override_failure_message("тот же герой на дистанции 3 обязан увидеть цель — иначе тест был пустым")


## С соседом исполнитель пустит только соседнюю атаку (`else: if distance != 1: return`),
## поэтому выбор «дальнего» при живом соседе — это вечный отклонённый запрос.
func test_adjacent_enemy_is_the_only_acceptable_target_when_present() -> void:
	var hero := _attacker(1, Vector2i(5, 5), RANGED)
	var adjacent := _defender(2, Vector2i(5, 6))
	var distant := _defender(3, Vector2i(5, 8))
	var bs := _state([hero], [adjacent, distant])
	assert_bool(BalanceProbe.pick_attack_target(bs, hero) == adjacent).is_true() \
		.override_failure_message("при соседнем враге дальнобойный бьёт соседа; выбор дальней цели отклоняется")


## Ближний бой: цель только сосед (ветка `distance != 1` в request_attack).
func test_melee_target_must_be_adjacent() -> void:
	var hero := _attacker(1, Vector2i(5, 5), MELEE)
	var distant := _defender(2, Vector2i(5, 8))
	var bs := _state([hero], [distant])
	assert_bool(BalanceProbe.pick_attack_target(bs, hero) == null).is_true() \
		.override_failure_message("ближний не выбирает цель на дистанции 3")

	var adjacent := _defender(3, Vector2i(4, 5))
	var near_bs := _state([_attacker(1, Vector2i(5, 5), MELEE)], [adjacent])
	assert_bool(BalanceProbe.pick_attack_target(near_bs, near_bs.attacker_units[0]) == adjacent).is_true() \
		.override_failure_message("соседняя цель обязана выбираться — иначе предыдущий assert пустой")


# ── 2) Ключ сталл-сети: необратимый прогресс, а не очередь хода ────────────────────

## Тот самый бой-патруль (T-205): do_wait перекладывает юнита в конец очереди, ход не
## расходуется, активный юнит чередуется каждый кадр. Ключ обязан остаться прежним —
## только тогда сеть накопит кадры и сообщит о висяке.
func test_progress_key_survives_wait_rotation() -> void:
	var hero := _attacker(1, Vector2i(9, 0), RANGED)
	var stack := _attacker(2, Vector2i(11, 0), MELEE, 42)
	var foe := _defender(3, Vector2i(9, 9))
	var bs := _state([hero, stack], [foe])
	var before := BalanceProbe.battle_progress_key(bs)

	BattleActionResolver.do_wait(bs, hero)
	BattleActionResolver.do_wait(bs, stack)
	hero.has_moved = not hero.has_moved
	bs.turn_idx = (bs.turn_idx + 3) % maxi(1, bs.turn_queue.size())

	assert_str(BalanceProbe.battle_progress_key(bs)).is_equal(before)  # ротируется — не прогресс


## Отрицание к предыдущему: движение, потеря бойцов и потеря юнита — прогресс, и ключ
## обязан измениться, иначе сеть роняла бы живые бои.
func test_progress_key_tracks_movement_losses_and_deaths() -> void:
	var hero := _attacker(1, Vector2i(9, 0), RANGED)
	var foe := _defender(2, Vector2i(9, 9))
	var bs := _state([hero], [foe])
	var base := BalanceProbe.battle_progress_key(bs)

	hero.cell = Vector2i(9, 1)
	var moved := BalanceProbe.battle_progress_key(bs)
	assert_bool(moved != base).is_true() \
		.override_failure_message("сдвиг юнита — прогресс; ключ не изменился")

	hero.cell = Vector2i(9, 0)
	foe.set_count(int(foe.get_count()) - 1)
	assert_bool(BalanceProbe.battle_progress_key(bs) != base).is_true() \
		.override_failure_message("потеря бойцов в стэке — прогресс")

	foe.set_count(int(foe.get_count()) + 1)
	foe.alive = false
	foe.dnd_current_hp = 0
	assert_bool(BalanceProbe.battle_progress_key(bs) != base).is_true() \
		.override_failure_message("выбывший юнит — прогресс")

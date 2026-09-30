class_name BattleHandoff
extends RefCounted
## Инкапсулирует сбор и валидацию всех данных для старта боя.
## Убирает дублирование между _start_battle() и start_enemy_attack().

# ── Собранные данные ──
var hero_army: Array[UnitStack] = []
var hero_bonus: Dictionary = {}
var hero_artifact_mods: Dictionary = {}
var hero_magic: Variant = null
var enemy_army: Array[UnitStack] = []
var enemy_bonus: Dictionary = {}
var obstacle_seed: int = -1
var roles_swapped: bool = false
var enemy_cell: Vector2i = Vector2i(-1, -1)

# ── Валидация ──
var is_valid: bool = false
var validation_errors: Array[String] = []


## Фабрика: собирает все данные для боя.
## roles_swapped = true когда враг атакует героя (роли меняются).
static func collect(
	hero: Node,
	enemy_army_raw: Variant,
	p_enemy_cell: Vector2i,
	spawner: Node,
	rng: RandomNumberGenerator,
	p_roles_swapped: bool = false
) -> BattleHandoff:
	var h := BattleHandoff.new()
	h.enemy_cell = p_enemy_cell
	h.roles_swapped = p_roles_swapped
	h._collect_hero_data(hero)
	h._collect_enemy_data(enemy_army_raw, spawner)
	h.obstacle_seed = rng.randi() if rng != null else randi()
	h._validate()
	return h


## Данные для передачи в BattleFlow.start_battle() с учётом ролей.
func get_attacker_army() -> Array[UnitStack]:
	return enemy_army if roles_swapped else hero_army

func get_defender_army() -> Array[UnitStack]:
	return hero_army if roles_swapped else enemy_army

func get_attacker_bonus() -> Dictionary:
	return enemy_bonus if roles_swapped else hero_bonus

func get_defender_bonus() -> Dictionary:
	return hero_bonus if roles_swapped else enemy_bonus

func get_attacker_artifact_mods() -> Dictionary:
	return {} if roles_swapped else hero_artifact_mods

func get_defender_artifact_mods() -> Dictionary:
	return hero_artifact_mods if roles_swapped else {}

func get_hero_magic() -> Variant:
	return hero_magic

## Выжившие стеки героя по итогам боя.
## В обычном бою герой — атакующий, в перевёрнутом — защитник.
func extract_hero_survivors(
	surv_atk: Array[UnitStack],
	surv_def: Array[UnitStack]
) -> Array[UnitStack]:
	return surv_def if roles_swapped else surv_atk

## Герой победил?
func hero_won(winner: BattleState.Side) -> bool:
	if roles_swapped:
		return winner == BattleState.Side.DEFENDER
	return winner == BattleState.Side.ATTACKER


# ── Приватные ──

func _collect_hero_data(hero: Node) -> void:
	if hero == null:
		return

	# Армия
	if hero.has_method("get_army_for_battle"):
		var raw: Variant = hero.call("get_army_for_battle")
		hero_army = _to_stack_array(raw)

	# Личный боец: герой всегда на доске (early-game-foundation)
	if hero.has_method("get_hero_battle_stack"):
		var fighter: UnitStack = hero.call("get_hero_battle_stack")
		if fighter != null:
			hero_army.append(fighter)

	# Бонусы героя (атака, защита, магия, знание, удача, мораль)
	if hero.has_method("get_battle_bonus"):
		var bonus: Variant = hero.call("get_battle_bonus")
		if bonus is Dictionary:
			hero_bonus = bonus

	# Модификаторы артефактов
	var inv: Variant = hero.get("inventory")
	if inv != null and inv.has_method("get_total_modifiers"):
		var mods: Variant = inv.call("get_total_modifiers")
		if mods is Dictionary:
			hero_artifact_mods = mods

	# Магия
	hero_magic = hero.get("magic")


func _collect_enemy_data(enemy_army_raw: Variant, spawner: Node) -> void:
	enemy_army = _to_stack_array(enemy_army_raw)

	if spawner != null and spawner.has_method("get_enemy_defender_bonus"):
		var bonus: Variant = spawner.call("get_enemy_defender_bonus")
		if bonus is Dictionary:
			enemy_bonus = bonus


func _validate() -> void:
	validation_errors.clear()

	if hero_army.is_empty():
		validation_errors.append("hero_army_empty")

	if enemy_army.is_empty():
		validation_errors.append("enemy_army_empty")

	for stack in hero_army:
		if stack == null or not stack.is_alive():
			validation_errors.append("hero_army_has_dead_stack")
			break

	for stack in enemy_army:
		if stack == null or not stack.is_alive():
			validation_errors.append("enemy_army_has_dead_stack")
			break

	is_valid = validation_errors.is_empty()


static func _to_stack_array(raw: Variant) -> Array[UnitStack]:
	var out: Array[UnitStack] = []
	if raw is Array:
		for s in raw:
			if s is UnitStack:
				out.append(s)
	return out

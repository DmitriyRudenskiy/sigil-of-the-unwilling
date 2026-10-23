class_name CombatState extends RefCounted

## Боевое ядро: юниты, очередь, выполнение одного действия, исход.
## Ни Node, ни сцен, ни спрайтов (спека «Модель не зависит от отображения»).

signal turn_started(unit: BattleUnit)
signal action_performed(action: BattleAction)
signal unit_died(unit: BattleUnit)
signal battle_ended(result: int)

## Страховка от «бой никогда не кончится». Исход при этом неопределён, а не
## «победа» и не «поражение» — врать в отчёт тесту права нет.
const MAX_TURNS := 200
const NO_RESULT := -1

var units: Array[BattleUnit] = []
var order: Array[BattleUnit] = []
var current: BattleUnit
var turn_index := 0
var finished := false
var result: int = NO_RESULT
var history: Array[BattleAction] = []
var rng := RandomNumberGenerator.new()

var _cursor := -1


func setup(roster: RosterData, enemies: Array[UnitStats], seed_value: int) -> void:
	rng.seed = seed_value
	units = []
	for slot in roster.units.size():
		units.append(BattleUnit.new(roster.units[slot], BattleUnit.SIDE_PLAYER, slot))
	for slot in enemies.size():
		units.append(BattleUnit.new(enemies[slot], BattleUnit.SIDE_ENEMY, slot))
	order = TurnQueue.order(units)
	current = null
	turn_index = 0
	finished = false
	result = NO_RESULT
	history = []
	_cursor = -1


func start() -> void:
	_advance()


## Публичная точка входа игрока: выполнить действие и передать ход.
func perform(action: BattleAction) -> void:
	assert(not finished, "действие после конца боя")
	_execute(action)
	if finished:
		return
	action.actor.end_turn()
	_advance()


func alive(side: int) -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	for unit in units:
		if unit.side == side and unit.is_alive():
			out.append(unit)
	return out


func foes_of(unit: BattleUnit) -> Array[BattleUnit]:
	return alive(_other_side(unit.side))


func allies_of(unit: BattleUnit) -> Array[BattleUnit]:
	return alive(unit.side)


## &"ready" | &"cost" | &"cooldown" | &"no_target" — причина недоступности
## показывает панель (спека battle-demo-ui).
func ability_state(unit: BattleUnit, ability: Ability) -> StringName:
	if unit.has_status(&"stun"):
		return &"stun"
	if unit.focus < ability.cost:
		return &"cost"
	if unit.on_cooldown(ability.id):
		return &"cooldown"
	if _targets(unit, ability).is_empty():
		return &"no_target"
	return &"ready"


func legal_actions(unit: BattleUnit) -> Array[BattleAction]:
	var actions: Array[BattleAction] = [BattleAction.skip(unit)]
	if unit.has_status(&"stun"):
		return actions
	for foe in foes_of(unit):
		actions.append(BattleAction.attack(unit, foe))
	for ability in unit.stats.abilities:
		if ability_state(unit, ability) == &"ready":
			actions.append(BattleAction.use_ability(unit, ability, _targets(unit, ability)))
	return actions


func _other_side(side: int) -> int:
	return BattleUnit.SIDE_ENEMY if side == BattleUnit.SIDE_PLAYER else BattleUnit.SIDE_PLAYER


func _execute(action: BattleAction) -> void:
	history.append(action)
	match action.kind:
		BattleAction.Kind.ATTACK:
			_hit(action, action.targets[0], null)
		BattleAction.Kind.ABILITY:
			var ability: Ability = action.ability
			action.actor.focus = maxi(0, action.actor.focus - ability.cost)
			if ability.cooldown > 0:
				action.actor.cooldowns[ability.id] = ability.cooldown
			for target in action.targets:
				if ability.deals_damage:
					for _hit_number in ability.hits:
						if target.is_alive():
							_hit(action, target, ability)
			for status_id in ability.applies:
				for target in action.targets:
					if target.is_alive():
						target.apply_status(status_id)
			for status_id in ability.self_applies:
				if action.actor.is_alive():
					action.actor.apply_status(status_id)
	action_performed.emit(action)
	_check_over()


func _hit(action: BattleAction, target: BattleUnit, ability: Ability) -> void:
	var damage := CombatRules.damage(action.actor, target, ability, rng)
	target.deal_damage(damage)
	action.damage[target.uid()] = int(action.damage.get(target.uid(), 0)) + damage
	if not target.is_alive():
		unit_died.emit(target)


## Жадный детерминированный ИИ противника (design-brief.md): способность, если
## доступна, иначе базовая атака по самому слабому по HP.
func _enemy_action(unit: BattleUnit) -> BattleAction:
	var foes := foes_of(unit)
	if unit.has_status(&"stun") or foes.is_empty():
		return BattleAction.skip(unit)
	for ability in unit.stats.abilities:
		if ability_state(unit, ability) == &"ready":
			return BattleAction.use_ability(unit, ability, _targets(unit, ability))
	return BattleAction.attack(unit, _weakest(foes))


func _advance() -> void:
	while not finished:
		var next_unit := _next_alive()
		if next_unit == null:
			_check_over()
			return
		current = next_unit
		turn_index += 1
		var outcome := current.begin_turn()
		if outcome.died:
			unit_died.emit(current)
		if _check_over():
			return
		turn_started.emit(current)
		if current.side == BattleUnit.SIDE_ENEMY:
			_execute(_enemy_action(current))
			current.end_turn()
			continue
		return


func _next_alive() -> BattleUnit:
	if order.is_empty():
		return null
	for _attempt in order.size():
		_cursor = (_cursor + 1) % order.size()
		if order[_cursor].is_alive():
			return order[_cursor]
	return null


func _check_over() -> bool:
	if finished:
		return true
	if alive(BattleUnit.SIDE_ENEMY).is_empty():
		_finish(BattleUnit.SIDE_PLAYER)
	elif alive(BattleUnit.SIDE_PLAYER).is_empty():
		_finish(BattleUnit.SIDE_ENEMY)
	elif turn_index >= MAX_TURNS:
		_finish(NO_RESULT)
	return finished


func _finish(outcome: int) -> void:
	finished = true
	result = outcome
	battle_ended.emit(outcome)


func _weakest(candidates: Array[BattleUnit]) -> BattleUnit:
	var best := candidates[0]
	for unit in candidates:
		if unit.hp < best.hp:
			best = unit
	return best


func _targets(unit: BattleUnit, ability: Ability) -> Array[BattleUnit]:
	var foes := foes_of(unit)
	var allies := allies_of(unit)
	var picked: Array[BattleUnit] = []
	match ability.target_kind:
		Ability.TargetKind.ENEMY_SINGLE:
			if not foes.is_empty():
				picked.append(_weakest(foes))
		Ability.TargetKind.ENEMY_ALL:
			picked = foes
		Ability.TargetKind.ALLY_SINGLE:
			if not allies.is_empty():
				picked.append(_weakest(allies))
		Ability.TargetKind.ALLY_OTHERS:
			for ally in allies:
				if ally != unit:
					picked.append(ally)
	return picked

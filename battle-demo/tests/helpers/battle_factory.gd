class_name BattleFactory extends RefCounted

## Конструкторы боя для тестов и съёмки кадров: состояние собирается кодом,
## без .tres, чтобы тест не зависел от данных (задача 1.7).


static func ability(
	id: StringName,
	cost: int = 1,
	cooldown: int = 0,
	multiplier: float = 1.0,
	target_kind: int = Ability.TargetKind.ENEMY_SINGLE,
	applies: Array = [],
	self_applies: Array = [],
	hits: int = 1,
	defense_ignores: float = 0.0,
	deals_damage: bool = true
) -> Ability:
	var built := Ability.new()
	built.id = id
	built.display_name = String(id)
	built.cost = cost
	built.cooldown = cooldown
	built.multiplier = multiplier
	built.target_kind = target_kind
	built.hits = hits
	built.defense_ignores = defense_ignores
	built.deals_damage = deals_damage
	var target_statuses: Array[StringName] = []
	for status_id in applies:
		target_statuses.append(status_id)
	built.applies = target_statuses
	var self_statuses: Array[StringName] = []
	for status_id in self_applies:
		self_statuses.append(status_id)
	built.self_applies = self_statuses
	return built


static func stats(
	id: StringName,
	max_hp: int,
	attack: int,
	defense: int,
	initiative: int,
	unit_abilities: Array = []
) -> UnitStats:
	var built := UnitStats.new()
	built.id = id
	built.display_name = String(id)
	built.max_hp = max_hp
	built.attack = attack
	built.defense = defense
	built.initiative = initiative
	var typed: Array[Ability] = []
	for one in unit_abilities:
		typed.append(one)
	built.abilities = typed
	return built


static func roster(unit_stats: Array, roster_id: StringName = &"test") -> RosterData:
	var built := RosterData.new()
	built.id = roster_id
	built.title = String(roster_id)
	var typed: Array[UnitStats] = []
	for one in unit_stats:
		typed.append(one)
	built.units = typed
	return built


static func state(roster_data: RosterData, enemies: Array, seed_value: int = 1) -> CombatState:
	var combat := CombatState.new()
	var typed_enemies: Array[UnitStats] = []
	for one in enemies:
		typed_enemies.append(one)
	combat.setup(roster_data, typed_enemies, seed_value)
	combat.start()
	return combat


## Жадно играет за сторону игрока до конца боя. Возвращает число выполненных
## действий игрока. Используется дымовым прогоном и тестом детерминизма.
static func auto_play(combat: CombatState, max_actions: int = 500) -> int:
	var performed := 0
	while not combat.finished and performed < max_actions:
		var chosen := BattleAction.skip(combat.current)
		for candidate in combat.legal_actions(combat.current):
			if candidate.kind != BattleAction.Kind.PASS:
				chosen = candidate
				break
		combat.perform(chosen)
		performed += 1
	return performed

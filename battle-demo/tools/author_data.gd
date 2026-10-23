extends SceneTree

# [AI]: сгенерировано по задаче 5.1–5.3 tasks.md, проверено человеком.
#
# Автор скрипт данных: собирает девять UnitStats и два RosterData и сохраняет
# .tres. Рукой эти файлы не пишем — формат typed-массивов в ресурсах Godot
# легко испортить, а скрипт правится в одном месте. Числа — docs/design-brief.md.


func _init() -> void:
	var pool := _pool()
	var all := pool.duplicate()
	all.append(_enemy())
	var by_id := {}
	for stats in all:
		var path := "res://data/units/%s.tres" % stats.id
		var error := ResourceSaver.save(stats, path)
		assert(error == OK, "не сохранён %s (%d)" % [path, error])
		by_id[stats.id] = stats

	var rosters := [
		_roster(&"a", "Стена", "Есть рыцарь, нет жреца: держим удар, лечения нет",
			["knight", "spearman", "archer", "wizard", "sorcerer", "barbarian", "cutthroat"], by_id),
		_roster(&"b", "Ритм", "Есть жрец, нет рыцаря: линия тонкая, живём благословением",
			["spearman", "archer", "wizard", "sorcerer", "barbarian", "cutthroat", "priest"], by_id),
	]
	for roster in rosters:
		var path := "res://data/rosters/%s.tres" % roster.id
		var error := ResourceSaver.save(roster, path)
		assert(error == OK, "не сохранён %s (%d)" % [path, error])

	print("Сохранено юнитов: %d, наборов: %d" % [all.size(), rosters.size()])
	quit(0)


func _ability(
	id: StringName,
	display_name: String,
	cost: int,
	cooldown: int,
	multiplier: float,
	target_kind: int = Ability.TargetKind.ENEMY_SINGLE,
	applies: Array = [],
	self_applies: Array = [],
	hits: int = 1,
	defense_ignores: float = 0.0,
	deals_damage: bool = true
) -> Ability:
	var built := Ability.new()
	built.id = id
	built.display_name = display_name
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


func _unit(
	id: StringName,
	display_name: String,
	max_hp: int,
	attack: int,
	defense: int,
	initiative: int,
	abilities: Array = []
) -> UnitStats:
	var built := UnitStats.new()
	built.id = id
	built.display_name = display_name
	built.max_hp = max_hp
	built.attack = attack
	built.defense = defense
	built.initiative = initiative
	var typed: Array[Ability] = []
	for one in abilities:
		typed.append(one)
	built.abilities = typed
	return built


## Порядок возврата = порядок пула (позиции 1–8). Девятый, stormmage, — враг.
func _pool() -> Array:
	return [
		_unit(&"knight", "Рыцарь", 120, 12, 12, 7, [
			_ability(&"shield_wall", "Стена щита", 2, 3, 0.0,
				Ability.TargetKind.ENEMY_SINGLE, [&"weaken"], [], 1, 0.0, false),
		]),
		_unit(&"spearman", "Копейщик", 90, 16, 8, 9, [
			_ability(&"impaling_thrust", "Пронзающий выпад", 2, 2, 1.6,
				Ability.TargetKind.ENEMY_SINGLE, [], [], 1, 0.5),
		]),
		_unit(&"archer", "Лучница", 70, 18, 4, 13, [
			_ability(&"volley", "Залп", 3, 3, 1.3,
				Ability.TargetKind.ENEMY_SINGLE, [&"bleed"]),
		]),
		_unit(&"wizard", "Волшебник", 65, 20, 5, 11, [
			_ability(&"siphon", "Иссушение", 3, 2, 1.4),
		]),
		_unit(&"sorcerer", "Чародей", 75, 14, 6, 10, [
			_ability(&"evil_eye", "Сглаз", 3, 3, 1.0,
				Ability.TargetKind.ENEMY_SINGLE, [&"weaken", &"bleed"]),
		]),
		_unit(&"barbarian", "Варвар", 105, 22, 5, 6, [
			_ability(&"cleave", "Рубящий удар", 3, 2, 1.8,
				Ability.TargetKind.ENEMY_SINGLE, [], [&"bleed"]),
		]),
		_unit(&"cutthroat", "Тайный убийца", 70, 19, 4, 16, [
			_ability(&"dagger_dance", "Танец кинжалов", 2, 2, 0.7,
				Ability.TargetKind.ENEMY_SINGLE, [], [], 2),
		]),
		_unit(&"priest", "Жрец", 80, 11, 7, 8, [
			_ability(&"blessing", "Благословение", 2, 2, 0.0,
				Ability.TargetKind.ALLY_SINGLE, [&"regen"], [], 1, 0.0, false),
		]),
	]


func _enemy() -> UnitStats:
	return _unit(&"stormmage", "Маг грозы", 180, 24, 9, 12, [
		_ability(&"thunderstorm", "Гроза", 3, 3, 1.2,
			Ability.TargetKind.ENEMY_ALL, [&"bleed"]),
	])


func _roster(id: StringName, title: String, difference: String, unit_ids: Array, by_id) -> RosterData:
	var built := RosterData.new()
	built.id = id
	built.title = title
	built.difference = difference
	var typed: Array[UnitStats] = []
	for unit_id in unit_ids:
		typed.append(by_id[unit_id])
	built.units = typed
	return built

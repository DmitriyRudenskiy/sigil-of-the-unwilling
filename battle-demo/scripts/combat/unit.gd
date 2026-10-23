class_name BattleUnit extends RefCounted

## Экземпляр юнита в бою: HP, focus, статусы, кулдауны.
## Изменение состояния — только методами этого класса (см. architecture.md).

const SIDE_PLAYER := 0
const SIDE_ENEMY := 1

const FOCUS_START := 3
const FOCUS_MAX := 5
const FOCUS_GAIN := 1

## Длительность считается в ходах владельца: эффект срабатывает в начале хода,
## длительность уменьшается в конце. Статус одного типа не складывается —
## повторное применение обновляет длительность.
const STATUSES := {
	&"bleed": {"duration": 2, "tick_damage": 5},
	&"stun": {"duration": 1},
	&"weaken": {"duration": 2, "attack_mult": 0.7},
	&"regen": {"duration": 2, "tick_heal": 6},
}

var stats: UnitStats
var side: int = SIDE_PLAYER
## Позиция в линии своей стороны (0..6).
var slot: int = 0
var hp: int = 0
var focus: int = FOCUS_START
var died: bool = false
## StringName -> оставшиеся ходы.
var durations := {}
## StringName -> оставшийся кулдаун.
var cooldowns := {}
var turns_taken := 0


func _init(stats: UnitStats, side: int, slot: int) -> void:
	self.stats = stats
	self.side = side
	self.slot = slot
	hp = stats.max_hp


func uid() -> String:
	return "%s#%d" % [String(stats.id), slot]


func max_hp() -> int:
	return stats.max_hp


func is_alive() -> bool:
	return not died and hp > 0


func hp_fraction() -> float:
	return clampf(float(hp) / float(max_hp()), 0.0, 1.0)


func has_status(id: StringName) -> bool:
	return durations.has(id)


func status_ids() -> Array:
	return durations.keys()


func apply_status(id: StringName) -> void:
	assert(STATUSES.has(id), "неизвестный статус: %s" % id)
	durations[id] = int(STATUSES[id].duration)


func effective_attack() -> int:
	var value := float(stats.attack)
	if has_status(&"weaken"):
		value *= float(STATUSES[&"weaken"].attack_mult)
	return int(round(value))


func on_cooldown(id: StringName) -> bool:
	return int(cooldowns.get(id, 0)) > 0


## Начало хода: прирост focus (не в первый ход), тики статусов, проверка оглушения.
func begin_turn() -> Dictionary:
	if turns_taken > 0:
		focus = mini(FOCUS_MAX, focus + FOCUS_GAIN)
	if has_status(&"bleed"):
		deal_damage(int(STATUSES[&"bleed"].tick_damage))
	if is_alive() and has_status(&"regen"):
		hp = mini(max_hp(), hp + int(STATUSES[&"regen"].tick_heal))
	return {"can_act": is_alive() and not has_status(&"stun"), "died": died}


## Конец хода: уменьшение длительностей и кулдаунов, удаление обнулившихся.
func end_turn() -> void:
	turns_taken += 1
	for id: StringName in durations.keys():
		durations[id] = int(durations[id]) - 1
		if int(durations[id]) <= 0:
			durations.erase(id)
	for id: StringName in cooldowns.keys():
		cooldowns[id] = int(cooldowns[id]) - 1
		if int(cooldowns[id]) <= 0:
			cooldowns.erase(id)


## Урон из любого источника. Смертельный удар оставляет hp = 0 (спека).
func deal_damage(amount: int) -> void:
	if not is_alive():
		return
	hp = clampi(hp - maxi(0, amount), 0, max_hp())
	if hp == 0:
		died = true


func heal(amount: int) -> void:
	if is_alive():
		hp = mini(max_hp(), hp + maxi(0, amount))

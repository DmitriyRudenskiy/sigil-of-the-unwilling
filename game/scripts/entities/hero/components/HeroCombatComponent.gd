class_name HeroCombatComponent
extends HeroComponent

var combat_hp: int = 0
var max_combat_hp: int = 0
var is_alive: bool = true

func set_max_hp(v: int) -> void:
	max_combat_hp = v
	combat_hp = v
	is_alive = true

func set_hp(amount: int) -> void:
	combat_hp = clampi(amount, 0, max(max_combat_hp, 0))
	is_alive = combat_hp > 0

func mark_dead() -> void:
	combat_hp = 0
	is_alive = false

func is_combat_dead() -> bool:
	return combat_hp <= 0

func revive() -> void:
	is_alive = true
	combat_hp = max_combat_hp

func serialize() -> Dictionary:
	return {
		"combat_hp": combat_hp,
		"max_combat_hp": max_combat_hp,
		"is_alive": is_alive,
	}

func deserialize(data: Dictionary) -> void:
	combat_hp = int(data.get("combat_hp", 0))
	max_combat_hp = int(data.get("max_combat_hp", 0))
	is_alive = bool(data.get("is_alive", true))

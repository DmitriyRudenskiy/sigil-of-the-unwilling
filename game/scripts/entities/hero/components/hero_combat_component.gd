class_name HeroCombatComponent
extends HeroComponent

var combat_hp: int = 0
var max_combat_hp: int = 0
var is_alive: bool = true

# Ранение после проигранного боя (tactical-combat фаза 7.2):
# сниженные статы на N ходов + HP-шрам (перманентно до исцеления).
var wounded_turns: int = 0
var hp_scar: int = 0


func is_wounded() -> bool:
	return wounded_turns > 0


## Герой ранен: статы снижаются на WOUNDED_STAT_PENALTY, max HP — на hp_scar.
func apply_wounded(turns: int, hp_loss: int) -> void:
	wounded_turns = maxi(wounded_turns, turns)
	hp_scar = maxi(hp_scar, maxi(0, hp_loss))
	max_combat_hp = max(1, max_combat_hp - hp_scar)
	combat_hp = mini(combat_hp, max_combat_hp)


## Конец хода мира: тикает ранение; по исцелению HP-шрам снимается.
func end_turn() -> void:
	if wounded_turns <= 0:
		return
	wounded_turns -= 1
	if wounded_turns == 0:
		max_combat_hp = max(1, max_combat_hp + hp_scar)
		hp_scar = 0
		combat_hp = mini(combat_hp, max_combat_hp)

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
		"wounded_turns": wounded_turns,
		"hp_scar": hp_scar,
	}

func deserialize(data: Dictionary) -> void:
	combat_hp = int(data.get("combat_hp", 0))
	max_combat_hp = int(data.get("max_combat_hp", 0))
	is_alive = bool(data.get("is_alive", true))
	# Legacy-сейвы (до фазы 7.2): ключей нет → герой не ранен.
	wounded_turns = int(data.get("wounded_turns", 0))
	hp_scar = int(data.get("hp_scar", 0))

class_name UnitStats
extends RefCounted
## Immutable definition of a unit type.


var key: String = ""
var display_name: String = ""
var base_damage: int = 0
var hp: int = 1
var speed: int = 0
var defense: int = 0


func _init(p_key: String = "", p_display_name: String = "",
           p_damage: int = 0, p_hp: int = 1, p_speed: int = 0, p_defense: int = 0) -> void:
    key = p_key
    display_name = p_display_name
    base_damage = p_damage
    hp = p_hp
    speed = p_speed
    defense = p_defense

class_name UnitStats
extends RefCounted

var key: String = ""
var display_name: String = ""
var attack: int = 0
var base_damage: int = 0
var hp: int = 1
var speed: int = 0
var defense: int = 0
var tags: Array[String] = []


func _init(
    p_key: String = "",
    p_display_name: String = "",
    p_attack: int = 0,
    p_base_damage: int = 0,
    p_hp: int = 1,
    p_speed: int = 0,
    p_defense: int = 0,
    p_tags: Array = []
) -> void:
    key = p_key
    display_name = p_display_name
    attack = p_attack
    base_damage = p_base_damage
    hp = p_hp
    speed = p_speed
    defense = p_defense
    tags.assign(p_tags)


func has_tag(tag: String) -> bool:
    return tags.has(tag)


func copy() -> UnitStats:
    return UnitStats.new(key, display_name, attack, base_damage, hp, speed, defense, tags)

class_name UnitStack
extends RefCounted
## Runtime stack: reference to definition + mutable count.

const _UnitStats = preload("res://game/entities/UnitStats.gd")

var stats: UnitStats
var count: int = 0


func _init(p_stats: UnitStats = null, p_count: int = 0) -> void:
    # Защитная копия: мутации рантайм-статов (артефакты в бою и т.п.)
    # не должны просачиваться в общее определение реестра (РФ6-1).
    stats = p_stats.copy() if p_stats != null else null
    count = p_count


func is_alive() -> bool:
    return stats != null and count > 0


func get_key() -> String:
    return stats.key if stats != null else ""


func get_display_name() -> String:
    return stats.display_name if stats != null else ""


func duplicate_stack() -> UnitStack:
    return UnitStack.new(stats, count)


func to_dict() -> Dictionary:
    if stats == null:
        return {}
    return {
        "key": stats.key,
        "icon": "",
        "name": stats.display_name,
        "count": count,
        "base_damage": stats.base_damage,
        "hp": stats.hp,
        "speed": stats.speed,
        "defense": stats.defense,
    }


static func from_dict(data: Dictionary, stats: UnitStats) -> UnitStack:
    if stats == null:
        return null
    return UnitStack.new(stats, int(data.get("count", 0)))

class_name UnitStack
extends RefCounted

const _UnitStats = preload("res://scripts/entities/unit_stats.gd")

var stats: UnitStats
var count: int = 0
## dnd-live-battle-wiring: optional per-character D&D stat block. null = pure
## stack-model unit (backward compatible). A non-null profile makes this stack
## a single D&D character (count = 1) that fights via DnDBattleBridge.
var dnd_profile: DnDCombatantProfile = null

func _init(p_stats: UnitStats = null, p_count: int = 0) -> void:
    stats = p_stats.copy() if p_stats != null else null
    count = p_count

func is_alive() -> bool:
    return stats != null and count > 0

func get_key() -> String:
    return stats.key if stats != null else ""

func get_display_name() -> String:
    return stats.display_name if stats != null else ""

func duplicate_stack() -> UnitStack:
    var d := UnitStack.new(stats, count)
    d.dnd_profile = dnd_profile  # profile is shared (immutable stat block)
    return d

func to_dict() -> Dictionary:
    if stats == null:
        return {}
    var d := {
        "key": stats.key,
        "icon": "",
        "name": stats.display_name,
        "count": count,
        "base_damage": stats.base_damage,
        "hp": stats.hp,
        "speed": stats.speed,
        "defense": stats.defense,
    }
    if dnd_profile != null:
        d["dnd_profile"] = dnd_profile.to_dict()
    return d

static func from_dict(data: Dictionary, stats_: UnitStats) -> UnitStack:
    if stats_ == null:
        return null
    var s := UnitStack.new(stats_, int(data.get("count", 0)))
    if data.has("dnd_profile") and data["dnd_profile"] is Dictionary:
        s.dnd_profile = DnDCombatantProfile.from_dict(data["dnd_profile"])
    return s

extends RefCounted
class_name Chronicle

var entries: Array[Dictionary] = []


var bus: Object = null


func append(entry: Dictionary) -> Dictionary:
	var e: Dictionary = entry.duplicate(true)
	e["generation"] = entries.size() + 1
	entries.append(e)
	var b := _resolve_bus()
	if b != null:
		b.chronicle_entry_added.emit(
			StringName("g%d" % entries.size()), _entry_text(e))
	return e


func _resolve_bus() -> Object:
	if bus != null:
		return bus
	# ИСПРАВЛЕНИЕ: Services.resolve вместо get_node("/root/GameEventBus")
	var resolved: Object = Services.resolve(&"event_bus")
	if resolved != null:
		bus = resolved
	return bus


func to_array() -> Array:
	var out: Array = []
	for e in entries:
		out.append(e.duplicate(true))
	return out


func from_array(arr: Array) -> void:
	entries.clear()
	for e in arr:
		if e is Dictionary:
			entries.append(e)


func _entry_text(e: Dictionary) -> String:
	return "Поколение %s: %s (%s) — %s, слава %s" % [
		str(e.get("generation", "?")),
		str(e.get("hero_name", "?")),
		str(e.get("path", "")),
		str(e.get("outcome", "?")),
		str(e.get("glory", 0)),
	]

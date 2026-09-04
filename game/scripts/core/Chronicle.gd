extends RefCounted
class_name Chronicle
## legend-chronicle: летопись поколений — персистентный список записей
## «каждый герой — своя запись». Запись (Dictionary):
##   hero_name, path, end_turn, cities, glory, battles_won, battles_lost,
##   outcome ("succession" | "VICTORY" | "DEFEAT"), generation (авто).
## Чистый RefCounted (без Node/ServiceLocator) — headless-тесты.

var entries: Array[Dictionary] = []


## Аудит #22: шина — guard-эмит. Chronicle — чистый RefCounted; в контексте
## без autoload (-s скрипт) GameEventBus не существует, и прямой emit падал.
## null — искать GameEventBus в корне SceneTree (кэш в том же поле).
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
	var ml := Engine.get_main_loop()
	if ml is SceneTree:
		bus = (ml as SceneTree).root.get_node_or_null("/root/GameEventBus")
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

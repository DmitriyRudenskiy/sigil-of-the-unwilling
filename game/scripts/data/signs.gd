extends RefCounted
class_name Signs

## T-002 «Выбор знака»: каталог восьми Знаков (docs/02c-signs.md, финальная
## редакция автора 2026-09-30; имена/девизы — verbatim). Выбор 1 из 8 на всю
## игру (Q18, D12); Престиж косметический (S2); ресурс знака и фракционные
## действия — вне MVP (02c §1). Числа/имена — только в data/signs.json (K-M15).

const DATA_PATH := "res://data/signs.json"

static var _cache: Dictionary = {}


static func all() -> Array:
	return _load().get("signs", [])


static func ids() -> Array:
	var out: Array = []
	for s in all():
		out.append(str(s.get("id", "")))
	return out


static func by_id(id: String) -> Dictionary:
	for s in all():
		if str(s.get("id", "")) == id:
			return s
	return {}


static func is_valid(id: String) -> bool:
	return not by_id(id).is_empty()


static func _load() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		return {"signs": []}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"signs": []}
	_cache = parsed
	return _cache

extends RefCounted
class_name MvpSaveManager
## T-110: MVP-сейвы — 3 слота, атомарная запись (tmp + rename),
## байт-детерминизм (стабильный порядок ключей), версия major.minor.
## AC [[MVP-scope]]: «одинаковые вводные → байт-в-байт одна и та же
## последовательность событий» — на уровне сейва: одинаковое состояние
## сериализуется в одинаковые байты (I1-проверка цикла сейва).

const SLOT_COUNT := 3
const PATH_TEMPLATE := "user://mvp_save_slot_%d.json"

enum SaveError {
	OK,
	INVALID_SLOT,
	FILE_NOT_FOUND,
	FILE_OPEN_FAIL,
	PARSE_FAIL,
	INVALID_DATA,
	INCOMPATIBLE_VERSION,
	WRITE_FAIL,
}


static func get_slot_path(slot: int) -> String:
	return PATH_TEMPLATE % clampi(slot, 1, SLOT_COUNT)


static func has_save_in_slot(slot: int) -> bool:
	return slot_in_bounds(slot) and FileAccess.file_exists(get_slot_path(slot))


static func slot_in_bounds(slot: int) -> bool:
	return slot >= 1 and slot <= SLOT_COUNT


## Атомарный сейв: валидация → детерминистичная сериализация → tmp → rename.
static func save_slot(slot: int, state: Dictionary) -> Dictionary:
	if not slot_in_bounds(slot):
		return _err(SaveError.INVALID_SLOT, "slot must be 1..%d" % SLOT_COUNT)
	var validation := MvpSaveSchema.validate(state)
	if validation != "":
		return _err(SaveError.INVALID_DATA, validation)
	var path := get_slot_path(slot)
	var tmp_path := path + ".tmp"
	var payload := {
		"version": MvpSaveSchema.current_version(),
		"state": state,
	}
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return _err(SaveError.WRITE_FAIL, "cannot write %s" % tmp_path)
	file.store_string(serialize(payload))
	file.close()
	var dir := DirAccess.open("user://")
	if dir == null:
		return _err(SaveError.WRITE_FAIL, "cannot open user://")
	var err := dir.rename_absolute(ProjectSettings.globalize_path(tmp_path), ProjectSettings.globalize_path(path))
	if err != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_path))
		return _err(SaveError.WRITE_FAIL, "atomic rename failed")
	return {"ok": true, "error": SaveError.OK, "message": "saved", "path": path}


static func load_slot(slot: int) -> Dictionary:
	if not slot_in_bounds(slot):
		return _err(SaveError.INVALID_SLOT, "slot must be 1..%d" % SLOT_COUNT)
	var path := get_slot_path(slot)
	if not FileAccess.file_exists(path):
		return _err(SaveError.FILE_NOT_FOUND, "no save in slot %d" % slot)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _err(SaveError.FILE_OPEN_FAIL, "cannot read %s" % path)
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return _err(SaveError.PARSE_FAIL, "save is not a JSON object")
	var version = parsed.get("version", {})
	if not (version is Dictionary) or not MvpSaveSchema.is_compatible(version):
		return _err(
			SaveError.INCOMPATIBLE_VERSION,
			"save version %s incompatible with %s" % [str(version), str(MvpSaveSchema.current_version())],
		)
	var state = parsed.get("state", {})
	if not (state is Dictionary):
		return _err(SaveError.INVALID_DATA, "state is not an object")
	var validation := MvpSaveSchema.validate(state)
	if validation != "":
		return _err(SaveError.INVALID_DATA, validation)
	return {"ok": true, "error": SaveError.OK, "message": "loaded", "version": version, "state": state}


static func delete_slot(slot: int) -> bool:
	if not slot_in_bounds(slot):
		return false
	var path := get_slot_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return true


## Детерминистичная сериализация: рекурсивный порядок ключей — алфавитный.
## Одинаковый payload → одинаковые байты (I1: байт-в-байт).
static func serialize(payload: Dictionary) -> String:
	return JSON.stringify(_sort_deep(payload), "\t")


static func _sort_deep(value: Variant) -> Variant:
	if value is Dictionary:
		var keys: Array = (value as Dictionary).keys()
		keys = keys.map(func(k): return str(k))
		keys.sort()
		var sorted := {}
		for key in keys:
			sorted[key] = _sort_deep((value as Dictionary)[key])
		return sorted
	if value is Array:
		var out: Array = []
		for item in value:
			out.append(_sort_deep(item))
		return out
	return value


static func _err(code: int, message: String) -> Dictionary:
	return {"ok": false, "error": code, "message": message}

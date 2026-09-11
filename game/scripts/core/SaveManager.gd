extends Node
class_name SaveManager

const _SaveData = preload("res://scripts/core/SaveData.gd")

const SAVE_PATH := "user://save_slot_1.json"
const SLOT_COUNT := 5
const SAVE_PATH_TEMPLATE := "user://save_slot_%d.json"

enum SaveError {
	OK,
	FILE_NOT_FOUND,
	FILE_OPEN_FAIL,
	PARSE_FAIL,
	INVALID_DATA,
	WRITE_FAIL,
}

const ERROR_MESSAGES := {
	SaveError.OK: "OK",
	SaveError.FILE_NOT_FOUND: "Save file not found",
	SaveError.FILE_OPEN_FAIL: "Cannot open save file",
	SaveError.PARSE_FAIL: "JSON parse error",
	SaveError.INVALID_DATA: "Save data failed validation",
	SaveError.WRITE_FAIL: "Cannot write save file",
}

static func get_slot_path(slot: int) -> String:
	return SAVE_PATH_TEMPLATE % clampi(slot, 1, SLOT_COUNT)

static func has_save_in_slot(slot: int) -> bool:
	return FileAccess.file_exists(get_slot_path(slot))

static func delete_slot(slot: int) -> bool:
	var path := get_slot_path(slot)
	if not FileAccess.file_exists(path):
		return false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	GameLogger.info("Save deleted: %s" % path, "Save")
	return true

static func load_slot(slot: int) -> Dictionary:
	var path := get_slot_path(slot)
	if not FileAccess.file_exists(path):
		GameLogger.info("No save file at %s" % path, "Save")
		return {"error": SaveError.FILE_NOT_FOUND, "data": null, "message": ERROR_MESSAGES[SaveError.FILE_NOT_FOUND]}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		var err_code := FileAccess.get_open_error()
		GameLogger.error("SaveManager: cannot read %s (error %d)" % [path, err_code], "Save")
		return {"error": SaveError.FILE_OPEN_FAIL, "data": null, "message": ERROR_MESSAGES[SaveError.FILE_OPEN_FAIL]}

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_err := json.parse(text)
	if parse_err != OK:
		var msg := "%s at line %d" % [json.get_error_message(), json.get_error_line()]
		GameLogger.error("SaveManager: parse error: %s" % msg, "Save")
		return {"error": SaveError.PARSE_FAIL, "data": null, "message": msg}

	if json.data == null or not (json.data is Dictionary):
		GameLogger.error("SaveManager: root is not a Dictionary", "Save")
		return {"error": SaveError.INVALID_DATA, "data": null, "message": "Root is not a Dictionary"}

	var data := _SaveData.new()
	data.from_dict(json.data)
	if not data.is_valid():
		GameLogger.error("SaveManager: invalid data (version=%d, seed=%d)" % [data.version, data.run_seed], "Save")
		return {"error": SaveError.INVALID_DATA, "data": null, "message": ERROR_MESSAGES[SaveError.INVALID_DATA]}

	GameLogger.info("Loaded save from %s (seed=%d)" % [path, data.run_seed], "Save")
	return {"error": SaveError.OK, "data": data, "message": "OK"}

func save_to_slot(data: Variant, slot: int) -> SaveError:
	if data == null or not data.has_method("to_dict"):
		GameLogger.error("SaveManager: data is null or has no to_dict()", "Save")
		return SaveError.INVALID_DATA
	var path := get_slot_path(slot)
	var json_str := JSON.stringify(data.to_dict(), "\t")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		var err_code := FileAccess.get_open_error()
		GameLogger.error("SaveManager: cannot write %s (error %d)" % [path, err_code], "Save")
		return SaveError.WRITE_FAIL
	file.store_string(json_str)
	file.close()
	GameLogger.info("Game saved to slot %d (%s)" % [slot, path], "Save")
	return SaveError.OK

func save_game(data: Variant) -> SaveError:
	return save_to_slot(data, 1)

static func load_game() -> Dictionary:
	return load_slot(1)

static func load_game_legacy() -> Variant:
	var result: Dictionary = load_game()
	return result.get("data", null)

func has_save() -> bool:
	return has_save_in_slot(1)

func delete_save() -> bool:
	return delete_slot(1)

static func error_to_string(err: SaveError) -> String:
	return ERROR_MESSAGES.get(err, "Unknown error")

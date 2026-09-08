extends Node
class_name SaveManager

const _SaveData = preload("res://scripts/core/SaveData.gd")

const SAVE_PATH := "user://save_slot_1.json"


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


func save_game(data: Variant) -> SaveError:
	if data == null or not data.has_method("to_dict"):
		GameLogger.error("SaveManager: data is null or has no to_dict()", "Save")
		return SaveError.INVALID_DATA
	var json_str := JSON.stringify(data.to_dict(), "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		var err_code := FileAccess.get_open_error()
		GameLogger.error("SaveManager: cannot write %s (error %d)" % [SAVE_PATH, err_code], "Save")
		return SaveError.WRITE_FAIL
	file.store_string(json_str)
	file.close()
	GameLogger.info("Game saved to %s" % SAVE_PATH, "Save")
	return SaveError.OK


## R14 (P4): load_game чисто файловая (без состояния ноды) — static.
## Был статический load_slot(), создававший одноразовый SaveManager.new().
static func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		GameLogger.info("No save file at %s" % SAVE_PATH, "Save")
		return {"error": SaveError.FILE_NOT_FOUND, "data": null, "message": ERROR_MESSAGES[SaveError.FILE_NOT_FOUND]}

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		var err_code := FileAccess.get_open_error()
		GameLogger.error("SaveManager: cannot read %s (error %d)" % [SAVE_PATH, err_code], "Save")
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

	GameLogger.info("Loaded save from %s (seed=%d)" % [SAVE_PATH, data.run_seed], "Save")
	return {"error": SaveError.OK, "data": data, "message": "OK"}


static func load_game_legacy() -> Variant:
	var result: Dictionary = load_game()
	return result.get("data", null)


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> bool:
	if not has_save():
		return false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	GameLogger.info("Save deleted: %s" % SAVE_PATH, "Save")
	return true


static func error_to_string(err: SaveError) -> String:
	return ERROR_MESSAGES.get(err, "Unknown error")

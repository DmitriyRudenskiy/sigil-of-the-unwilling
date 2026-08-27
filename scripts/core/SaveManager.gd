extends Node
class_name SaveManager
## Save/Load manager: JSON to user:// directory.

const _SaveData = preload("res://scripts/core/SaveData.gd")

const SAVE_PATH := "user://save_slot_1.json"


func save_game(data: Variant) -> bool:
	var json_str := JSON.stringify(data.to_dict(), "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		printerr("Cannot open save file for writing: %s" % SAVE_PATH)
		return false
	file.store_string(json_str)
	file.close()
	print("[SaveManager] Game saved to %s" % SAVE_PATH)
	return true


func load_game() -> Variant:
	if not FileAccess.file_exists(SAVE_PATH):
		print("[SaveManager] No save file found at %s" % SAVE_PATH)
		return null

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		printerr("Cannot open save file for reading: %s" % SAVE_PATH)
		return null

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		printerr("Save file parse error: %s at line %d" % [json.get_error_message(), json.get_error_line()])
		return null

	var data := _SaveData.new()
	data.from_dict(json.data)

	if not data.is_valid():
		printerr("Save file invalid: version=%d, seed=%d" % [data.version, data.run_seed])
		return null

	print("[SaveManager] Game loaded from %s (seed=%d)" % [SAVE_PATH, data.run_seed])
	return data


static func load_slot() -> SaveData:
	var manager := SaveManager.new()
	var data = manager.load_game()
	manager.free()

	if data is SaveData:
		return data

	return null


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> bool:
	if not has_save():
		return false
	DirAccess.remove_absolute(SAVE_PATH)
	print("[SaveManager] Save deleted: %s" % SAVE_PATH)
	return true

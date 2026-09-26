
extends Node
class_name SpellbookRegistry

const JSON_PATH := "res://assets/data/spells.json"
const FALLBACK_JSON_PATH := "res://assets/data/spells_fallback.json"

const _Def = preload("res://scripts/data/spellbook_def.gd")
const _Enums = preload("res://scripts/data/spell_enums.gd")

var _spells: Dictionary = {}
var _by_template: Dictionary = {}
var _by_color: Dictionary = {}

func _ready() -> void:
	ensure_definitions()

func ensure_definitions() -> void:
	if not _spells.is_empty():
		return
	_load_from_json()

func reset() -> void:
	_spells.clear()
	_by_template.clear()
	_by_color.clear()

func _load_from_json() -> void:
	var data = _read_json_array(JSON_PATH)
	if data == null:
		_load_fallback()
		return
	_register_all(data)
	GameLogger.info("Loaded %d spells from JSON" % _spells.size(), "Spellbook")

func _load_fallback() -> void:
	var data = _read_json_array(FALLBACK_JSON_PATH)
	if data == null:
		push_error("SpellbookRegistry: fallback %s unavailable" % FALLBACK_JSON_PATH)
		return
	_register_all(data)
	GameLogger.info("Loaded %d spells from fallback" % _spells.size(), "Spellbook")

func _read_json_array(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_warning("SpellbookRegistry: %s not found" % path)
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("SpellbookRegistry: %s failed to open" % path)
		return null
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data == null or not (data is Array):
		push_error("SpellbookRegistry: invalid JSON format in %s" % path)
		return null
	return data

func _register_all(data: Array) -> void:
	for entry in data:
		if not (entry is Dictionary):
			continue
		var spell: Variant = _Def.from_dict(entry)
		if spell.id.is_empty():
			continue
		_register(spell)

func _register(spell) -> void:
	_spells[spell.id] = spell

	if not _by_template.has(spell.template):
		_by_template[spell.template] = []
	_by_template[spell.template].append(spell)

	var color_name: String = "UNKNOWN"
	var keys: Array = _Enums.SpellColor.keys()
	if spell.color < keys.size():
		color_name = str(keys[spell.color])
	if not _by_color.has(color_name):
		_by_color[color_name] = []
	_by_color[color_name].append(spell)

func register(spell) -> void:
	_register(spell)

func get_spell(id: StringName) -> Variant:
	ensure_definitions()
	return _spells.get(id, null)

func get_all() -> Array:
	ensure_definitions()
	var result: Array = []
	for id in _spells:
		result.append(_spells[id])
	return result

func get_by_template(template: StringName) -> Array:
	ensure_definitions()
	if _by_template.has(template):
		return _by_template[template]
	return []

func get_by_color(color: String) -> Array:
	ensure_definitions()
	if _by_color.has(color):
		return _by_color[color]
	return []

func get_count() -> int:
	return _spells.size()

func get_template_count() -> int:
	ensure_definitions()
	return _by_template.size()

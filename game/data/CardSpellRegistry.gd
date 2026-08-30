## scripts/card/CardSpellRegistry.gd
extends Node
class_name CardSpellRegistry
## Autoload: CardSpells. Загружает ~420 карт из JSON.

const JSON_PATH := "res://data/card_spells.json"

const _Def = preload("res://data/CardSpellDef.gd")
const _Enums = preload("res://data/CardEnums.gd")

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
	if not FileAccess.file_exists(JSON_PATH):
		push_warning("CardSpellRegistry: %s not found, using fallback" % JSON_PATH)
		_load_fallback()
		return

	var file := FileAccess.open(JSON_PATH, FileAccess.READ)
	var text := file.get_as_text()
	file.close()

	var data = JSON.parse_string(text)
	if data == null or not (data is Array):
		push_error("CardSpellRegistry: invalid JSON format")
		return

	for entry in data:
		if not (entry is Dictionary):
			continue
		var spell: Variant = _Def.from_dict(entry)
		if spell.id.is_empty():
			continue
		_register(spell)

	print("[CardSpellRegistry] Loaded %d spells from JSON" % _spells.size())

func _load_fallback() -> void:
	# Минимальный набор для тестов
	var fallback: Array[Dictionary] = [
		{"id": "ice_bolt", "name": "Ice Bolt", "template": "DIRECT_DAMAGE", "speed": "fast", "cost": 1, "color": "primal",
		 "params": {"amount": 2, "target": "ANY_NEXUS", "apply_status": "FROZEN", "status_duration": 1}},
		{"id": "annihilate", "name": "Annihilate", "template": "HARD_REMOVAL", "speed": "fast", "cost": 7, "color": "shadow",
		 "params": {"target": "ENEMY_UNIT", "ignore_ward": true}},
		{"id": "nullify", "name": "Nullify", "template": "COUNTERMAGIC", "speed": "fast", "cost": 3, "color": "primal",
		 "params": {}},
		{"id": "agile_strike", "name": "Agile Strike", "template": "COMBAT_TRICK", "speed": "fast", "cost": 3, "color": "justice",
		 "params": {"atk": 2, "hp": 2}},
		{"id": "mute", "name": "Mute", "template": "DEBUFF_CONTROL", "speed": "fast", "cost": 2, "color": "shadow",
		 "params": {"status": "SILENCE"}},
		{"id": "bottled_insight", "name": "Bottled Insight", "template": "CARD_DRAW", "speed": "fast", "cost": 2, "color": "primal",
		 "params": {"count": 1}},
		{"id": "earth_conjuring", "name": "Earth Conjuring", "template": "MANA_RAMP", "speed": "fast", "cost": 1, "color": "time",
		 "params": {"power": 1, "influence": "time"}},
		{"id": "blink", "name": "Blink", "template": "BOUNCE", "speed": "fast", "cost": 2, "color": "primal",
		 "params": {"target": "ALLY_UNIT"}},
		{"id": "deathstrike", "name": "Deathstrike", "template": "HARD_REMOVAL", "speed": "fast", "cost": 3, "color": "shadow",
		 "condition": {"target_hp_max": 4}, "params": {}},
		{"id": "reality_snap", "name": "Reality Snap", "template": "BOUNCE", "speed": "fast", "cost": 2, "color": "primal",
		 "condition": {"target_cost_max": 2}, "params": {"target": "ANY_UNIT"}},
		{"id": "turnabout", "name": "Turnabout", "template": "DEBUFF_CONTROL", "speed": "fast", "cost": 5, "color": "primal",
		 "params": {"change_control": true, "control_duration": 1}},
		{"id": "scalehide", "name": "Scalehide", "template": "KEYWORD_BUFF", "speed": "fast", "cost": 2, "color": "time",
		 "params": {"keyword": "ARMORED"}},
		{"id": "warren_delivery", "name": "Warren Delivery", "template": "TOKEN_GENERATION", "speed": "fast", "cost": 2, "color": "shadow",
		 "params": {"token_id": "rat", "count": 1, "atk": 1, "hp": 1}},
	]
	for entry in fallback:
		var spell: Variant = _Def.from_dict(entry)
		_register(spell)

func _register(spell) -> void:
	_spells[spell.id] = spell

	if not _by_template.has(spell.template):
		_by_template[spell.template] = []
	_by_template[spell.template].append(spell)

	var color_name: String = "UNKNOWN"
	var keys: Array = _Enums.CardColor.keys()
	if spell.color < keys.size():
		color_name = str(keys[spell.color])
	if not _by_color.has(color_name):
		_by_color[color_name] = []
	_by_color[color_name].append(spell)

# ==================== PUBLIC API ====================

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

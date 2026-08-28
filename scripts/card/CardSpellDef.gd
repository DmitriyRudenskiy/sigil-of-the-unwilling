## scripts/card/CardSpellDef.gd
class_name CardSpellDef
extends RefCounted
## Определение одного карточного заклинания.

const _CE = preload("res://scripts/card/CardEnums.gd")

var id: StringName = &""
var display_name: String = ""
var template: StringName = &""
var speed: int = _CE.SpellSpeed.FAST
var cost: int = 0
var color: int = _CE.CardColor.COLORLESS
var influence_req: Dictionary = {}
var description: String = ""
var flavor: String = ""
var params: Dictionary = {}
var condition: Dictionary = {}
var secondary_effects: Array[Dictionary] = []

static func from_dict(d: Dictionary):
	var s = new()
	s.id = StringName(d.get("id", ""))
	s.display_name = d.get("name", "")
	s.template = StringName(d.get("template", ""))
	s.speed = _CE.parse_speed(d.get("speed", "fast"))
	s.cost = int(d.get("cost", 0))
	s.color = _CE.parse_color(d.get("color", "colorless"))
	s.influence_req = d.get("influence_req", {})
	s.description = d.get("description", "")
	s.flavor = d.get("flavor", "")
	s.params = d.get("params", {})
	s.condition = d.get("condition", {})
	var se = d.get("secondary_effects", [])
	if se is Array:
		var typed: Array[Dictionary] = []
		for entry in se:
			if entry is Dictionary:
				typed.append(entry)
		s.secondary_effects = typed
	return s

func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": display_name,
		"template": template,
		"speed": _speed_to_str(speed),
		"cost": cost,
		"color": _color_to_str(color),
		"influence_req": influence_req,
		"description": description,
		"params": params,
		"condition": condition,
		"secondary_effects": secondary_effects,
	}

func _speed_to_str(s: int) -> String:
	match s:
		_CE.SpellSpeed.FAST: return "fast"
		_CE.SpellSpeed.SLOW: return "slow"
		_CE.SpellSpeed.BURST: return "burst"
	return "fast"

func _color_to_str(c: int) -> String:
	match c:
		_CE.CardColor.FIRE: return "fire"
		_CE.CardColor.TIME: return "time"
		_CE.CardColor.JUSTICE: return "justice"
		_CE.CardColor.PRIMAL: return "primal"
		_CE.CardColor.SHADOW: return "shadow"
		_CE.CardColor.MULTIFACTION: return "multifact"
		_: return "colorless"

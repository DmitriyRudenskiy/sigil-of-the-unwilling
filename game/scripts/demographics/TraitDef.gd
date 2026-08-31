class_name TraitDef
extends RefCounted
## Черта персонажа (M2: Демография).
##
## effect_type — ключ потребности, на которую черта влияет:
## &"hunger", &"rest", &"social", &"inspiration" (влияние = effect_value,
## добавляется к ежедневному дельте; может быть отрицательным).
## Сериализуется в Dictionary (JSON-совместимо).

enum Rarity { COMMON = 0, UNCOMMON = 1, RARE = 2, LEGENDARY = 3 }

var id: StringName = &""
var display_name := ""
var description := ""
var rarity: int = Rarity.COMMON
## Основной эффект (удобно для одиночных черт). Может быть &"" —
## тогда используется только effects.
var effect_type: StringName = &""
var effect_value: float = 0.0
## Дополнительные (или единственные) эффекты: need -> модификатор в день.
var effects: Dictionary = {}  # StringName -> float
var tags: Array[StringName] = []


## Суммарный модификатор черты к потребностям типа [type] за день.
func modifier_for(type: StringName) -> float:
	var v := float(effects.get(type, 0.0))
	if type == effect_type:
		v += effect_value
	return v


func to_dict() -> Dictionary:
	return {
		"id": String(id),
		"display_name": display_name,
		"description": description,
		"rarity": rarity,
		"effect_type": String(effect_type),
		"effect_value": effect_value,
		"effects": _effects_to_str(effects),
		"tags": tags.map(func(t: StringName) -> String: return String(t)),
	}


static func _effects_to_str(src: Dictionary) -> Dictionary:
	var out := {}
	for k in src:
		out[String(k)] = float(src[k])
	return out


static func from_dict(data: Dictionary) -> TraitDef:
	var t := TraitDef.new()
	t.id = StringName(data.get("id", ""))
	t.display_name = String(data.get("display_name", ""))
	t.description = String(data.get("description", ""))
	t.rarity = int(data.get("rarity", Rarity.COMMON))
	t.effect_type = StringName(data.get("effect_type", ""))
	t.effect_value = float(data.get("effect_value", 0.0))
	var raw_effects: Dictionary = data.get("effects", {})
	for k in raw_effects:
		t.effects[StringName(k)] = float(raw_effects[k])
	var raw_tags: Array = data.get("tags", [])
	t.tags.clear()
	for tag in raw_tags:
		t.tags.append(StringName(tag))
	return t

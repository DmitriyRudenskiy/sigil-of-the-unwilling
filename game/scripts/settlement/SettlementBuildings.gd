class_name SettlementBuildings
extends RefCounted
## Стройка, hearth, производство, переселение (фаза 3). Д2: статик + state.

const B = preload("res://scripts/data/settlement_buildings.gd")
const HexUtils = preload("res://scripts/core/HexUtils.gd")

# 3.4 Стройка свободными поселенцами: материалы списываются сразу,
# здание появляется через BUILD_CYCLES циклов.
const BUILD_CYCLES: int = 2

static func can_build(settle, type: String, meta: Dictionary = {}) -> bool:
	var b: Dictionary = B.by_id(type)
	if b.is_empty():
		return false
	# ункилоки
	match b.get("unlock", ""):
		"ancient_knowledge":
			if not meta.get("ancient_knowledge", false):
				return false
		"vs1": if int(meta.get("vanguard_level", 0)) < 1: return false
		"vs2": if int(meta.get("vanguard_level", 0)) < 2: return false
		"vs3": if int(meta.get("vanguard_level", 0)) < 3: return false
		"vs4": if int(meta.get("vanguard_level", 0)) < 4: return false
		"vs6": if int(meta.get("vanguard_level", 0)) < 6: return false
		"sc6": if int(meta.get("smoldering_level", 0)) < 6: return false
		"sc9": if int(meta.get("smoldering_level", 0)) < 9: return false
		"sc11": if int(meta.get("smoldering_level", 0)) < 11: return false
	if int(b.get("unlock_level", 0)) > 0 and int(meta.get("smoldering_level", 0)) < int(b["unlock_level"]):
		return false
	for res in b.get("cost", {}):
		if float(settle.state["resources"].get(res, 0.0)) < float(b["cost"][res]):
			return false
	return true

static func start_build(settle, type: String, cell: Vector2i) -> bool:
	if not can_build(settle, type):
		return false
	if _cell_occupied(settle, cell):
		return false
	var b: Dictionary = B.by_id(type)
	for res in b.get("cost", {}):
		settle.take_resource(res, float(b["cost"][res]))
	var bld: Dictionary = settle.add_building(type, cell)
	bld["data"]["build_left"] = BUILD_CYCLES
	return true

static func _cell_occupied(settle, cell: Vector2i) -> bool:
	for b in settle.state["buildings"]:
		if b["cell"] == cell:
			return true
	return false

# вызывается каждый ход: стройка идёт, производство работает
static func on_day_passed(settle, rng: RandomNumberGenerator) -> void:
	for b in settle.state["buildings"]:
		if int(b["data"].get("build_left", 0)) > 0:
			b["data"]["build_left"] = int(b["data"]["build_left"]) - 1
			continue
		if B.is_production(b["type"]):
			_produce(settle, b)
	_auto_rehome(settle)

static func _produce(settle, b: Dictionary) -> void:
	var recipe_id: String = b["data"].get("recipe", "")
	if recipe_id == "":
		return
	var r: Dictionary = B.RECIPES.get(recipe_id, {})
	if r.is_empty():
		return
	for res in r["input"]:
		if not settle.take_resource(res, float(r["input"][res])):
			return
	for res in r["output"]:
		settle.add_resource(res, float(r["output"][res]))

# 3.3 hearth: L1–3 за дома/декор в радиусе
static func hearth_level(settle) -> int:
	var hearths: Array = settle.buildings_of("hearth")
	if hearths.is_empty():
		return 0
	var h: Dictionary = hearths[0]
	var houses := 0
	for b in settle.state["buildings"]:
		if b == h:
			continue
		if B.is_housing(b["type"]) and HexUtils.hex_distance(h["cell"], b["cell"]) <= B.HEARTH_RADIUS:
			houses += 1
	if houses >= B.HEARTH_LEVEL3_HOUSES:
		return 3
	if houses >= B.HEARTH_LEVEL2_HOUSES:
		return 2
	return 1

static func hearth_bonus(settle) -> float:
	# L1: +1 Resolve всем; L2: +10% скорость; L3: +10% двойное (в прототипе 4.2)
	match hearth_level(settle):
		3: return 1.0
		2: return 1.0
		1: return 1.0
	return 0.0

# 3.5 Автопереселение: бездомные заселяются в свободные места
static func _auto_rehome(settle) -> void:
	var free_slots: Array = []
	for b in settle.state["buildings"]:
		if not B.is_housing(b["type"]):
			continue
		var cap := int(B.by_id(b["type"])["capacity"])
		var residents: Array = _residents_of(settle, b)
		for i in cap - residents.size():
			free_slots.append(b)
	if free_slots.is_empty():
		return
	for s in settle.state["settlers"]:
		if s["home"] != "":
			continue
		if s["species"] == "frog":
			# лягушки отказываются от Shelter
			var frog_house: Variant = _find(free_slots, "frog_house")
			if frog_house != null:
				_assign(settle, s, frog_house)
			continue
		var house: Variant = _find(free_slots, s["species"] + "_house")
		if house == null:
			house = _find(free_slots, "shelter")
		if house == null:
			house = _find(free_slots, "big_shelter")
		if house != null:
			_assign(settle, s, house)

static func _find(slots: Array, type: String):
	for b in slots:
		if b["type"] == type:
			return b
	return null

static func _assign(settle, s: Dictionary, b: Dictionary) -> void:
	s["home"] = b["id"]

static func _residents_of(settle, b: Dictionary) -> Array:
	var out: Array = []
	for s in settle.state["settlers"]:
		if s["home"] == b["id"]:
			out.append(s)
	return out

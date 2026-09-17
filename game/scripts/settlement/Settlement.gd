extends RefCounted
## Поселение — отдельная сущность мира (D1), state-Dictionary (D2).

var state: Dictionary = {}

func _init() -> void:
	reset()

func reset() -> void:
	state = {
		"id": "settlement_%d" % (Time.get_ticks_msec() % 100000),
		"center": Vector2i.ZERO,
		"core_cells": [],
		"day": 0,
		"settlers": [],        # Array[Dictionary]: {id, species, resolve, home, hunger, break_in}
		"buildings": [],       # Array[Dictionary]: {id, type, cell, data}
		"resources": {},       # String -> float
		"hostility": 0,
		"reputation": {},      # species -> {points, demand_threshold, decadence_spent}
		"victory": false,
		"defeat": "",
		"firekeeper_id": "",
	}

func add_settler(species: String) -> Dictionary:
	var s: Dictionary = {
		"id": "settler_%d" % (state["settlers"].size() + 1),
		"species": species,
		"resolve": float(Species.by_id(species).get("base_resolve", 5)),
		"home": "",
		"hunger": 0,
		"break_in": int(Species.by_id(species).get("break_interval", 1)),
	}
	state["settlers"].append(s)
	return s

func settlers_of(species: String) -> Array:
	var out: Array = []
	for s in state["settlers"]:
		if s["species"] == species:
			out.append(s)
	return out

func remove_settler(s: Dictionary) -> void:
	state["settlers"].erase(s)

func add_resource(id: String, amount: float) -> void:
	state["resources"][id] = float(state["resources"].get(id, 0.0)) + amount

func take_resource(id: String, amount: float) -> bool:
	var have: float = float(state["resources"].get(id, 0.0))
	if have < amount:
		return false
	state["resources"][id] = have - amount
	return true

func species_in_caravan() -> Array:
	var seen: Array = []
	for s in state["settlers"]:
		if not seen.has(s["species"]):
			seen.append(s["species"])
	return seen

const Species = preload("res://scripts/data/settlement_species.gd")

static func form_caravan(species_counts: Dictionary, dlc_purchased: Dictionary = {}) -> Variant:
	# species_counts: {species: count}. Не более 3 видов, все доступны.
	if species_counts.size() > GameNumbersSettlement.MAX_SPECIES:
		return null
	for sp in species_counts:
		if not Species.is_available(sp, dlc_purchased):
			return null
	var settle: Variant = new()
	for sp in species_counts:
		for i in int(species_counts[sp]):
			settle.add_settler(sp)
	# стартовые здания (2.1)
	settle.add_building("hearth", Vector2i.ZERO)
	settle.add_building("warehouse", Vector2i(1, 0))
	return settle

func add_building(type: String, cell: Vector2i) -> Dictionary:
	var b: Dictionary = {
		"id": "bld_%s_%d" % [type, state["buildings"].size() + 1],
		"type": type, "cell": cell, "data": {},
	}
	state["buildings"].append(b)
	return b

func buildings_of(type: String) -> Array:
	var out: Array = []
	for b in state["buildings"]:
		if b["type"] == type:
			out.append(b)
	return out

const GameNumbersSettlement = preload("res://scripts/constants/GameNumbersSettlement.gd")

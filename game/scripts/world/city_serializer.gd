class_name CitySerializer
extends RefCounted

const _ArenaClusterSystem = preload("res://scripts/city/arena_cluster_system.gd")

static func serialize(city: City) -> Dictionary:
	var d := {
		"version": City.SERIALIZATION_VERSION,
		"uid": city.uid,
		"display_name": city.display_name,
		"center": SerializationUtils.vec2i_to_dict(city.center),
		"reputation": city.reputation,
		"prosperity": city.prosperity,
		"level": city.level,
		"specialization": String(city.specialization),
		"faction": city.faction,
		"stronghold_level": city.stronghold_level,
		"is_capital": city.is_capital,
		"owner": String(city.owner),
		"food_stockpile": city.food_stockpile,
		"starving": city.starving,
		"scale_tier": city.scale_tier,
		"auto_resource_mult": city.auto_resource_mult,
		"upkeep_mult": city.upkeep_mult,
		"uid_seq": city._uid_seq,
	}
	var storage_str: Dictionary = {}
	for k in city.storage:
		storage_str[String(k)] = float(city.storage[k])
	d["storage"] = storage_str
	var sites: Array = []
	for cell in city.special_sites:
		sites.append({"cell": SerializationUtils.vec2i_to_dict(cell), "site": String(city.special_sites[cell])})
	d["special_sites"] = sites
	var roads_arr: Array = []
	for cell in city.roads:
		roads_arr.append(SerializationUtils.vec2i_to_dict(cell))
	d["roads"] = roads_arr
	if city.resource_ctx != null:
		d["resource_ctx"] = city.resource_ctx.serialize()
	var pops_arr: Array = []
	for u in city.pop:
		pops_arr.append(u.serialize())
	d["pop"] = pops_arr
	var bhs_arr: Array = []
	for borough in city.boroughs:
		bhs_arr.append({"cell": SerializationUtils.vec2i_to_dict(borough.cell), "level": borough.level, "uid": borough.uid})
	d["boroughs"] = bhs_arr
	var blds_arr: Array = []
	for building in city.buildings:
		blds_arr.append(building.serialize())
	d["buildings"] = blds_arr
	return d

static func deserialize(city: City, data: Dictionary) -> void:
	var version: int = int(data.get("version", 1))
	if version < City.SERIALIZATION_VERSION:
		data = _migrate_city_data(data, version)
	city.center = SerializationUtils.vec2i_from_dict(data.get("center", {}), Vector2i(-1, -1))
	city.reputation = int(data.get("reputation", 0))
	city.prosperity = clampf(float(data.get("prosperity", 50.0)), 0.0, 100.0)
	city.level = clampi(int(data.get("level", 1)), 1, GameNumbers.CITY_LEVEL_MAX)
	city.specialization = StringName(data.get("specialization", ""))
	city.faction = int(data.get("faction", City.Faction.DEFAULT))
	city.stronghold_level = int(data.get("stronghold_level", 1))
	city.is_capital = bool(data.get("is_capital", false))
	city.display_name = String(data.get("display_name", city.display_name))
	city.owner = StringName(data.get("owner", "none"))
	city.food_stockpile = float(data.get("food_stockpile", 0.0))
	city.starving = bool(data.get("starving", false))
	city.scale_tier = int(data.get("scale_tier", 0))
	city.auto_resource_mult = float(data.get("auto_resource_mult", 1.0))
	city.upkeep_mult = float(data.get("upkeep_mult", 1.0))

	city.storage.clear()
	var raw_storage: Dictionary = data.get("storage", {})
	for k in raw_storage:
		city.storage[StringName(k)] = float(raw_storage[k])

	city.special_sites.clear()
	for s in data.get("special_sites", []):
		var sc: Dictionary = s.cell
		city.special_sites[SerializationUtils.vec2i_from_dict(sc)] = StringName(s.site)

	city.roads.clear()
	for rc in data.get("roads", []):
		city.roads[SerializationUtils.vec2i_from_dict(rc)] = true

	if data.has("resource_ctx"):
		city.ensure_resource_ctx()
		city.resource_ctx.deserialize(data["resource_ctx"])

	city.pop.clear()
	for pd in data.get("pop", []):
		city.pop.append(PopUnit.deserialize(pd))

	city.boroughs.clear()
	for bd in data.get("boroughs", []):
		var bcell: Dictionary = bd.cell
		var bh := Borough.new()
		bh.cell = SerializationUtils.vec2i_from_dict(bcell)
		bh.level = int(bd.get("level", 1))
		bh.uid = int(bd.get("uid", 0))
		city.boroughs.append(bh)

	city.buildings.clear()
	for bl in data.get("buildings", []):
		var def := BuildingDefs.def_by_id(StringName(bl.get("def_id", "")))
		if def == null:
			GameLogger.warn("City.deserialize: неизвестное здание '%s' — пропущено" % bl.get("def_id", ""))
			continue
		city.buildings.append(UniqueBuilding.deserialize(bl, def))

	_ArenaClusterSystem.invalidate(city.uid)

	var max_uid := int(data.get("uid_seq", 0))
	for u in city.pop:
		max_uid = maxi(max_uid, u.uid + 1)
	for borough in city.boroughs:
		max_uid = maxi(max_uid, borough.uid + 1)
	for building in city.buildings:
		max_uid = maxi(max_uid, building.uid + 1)
	city._uid_seq = max_uid
	city._invalidate_exploited()

static func _migrate_city_data(data: Dictionary, from_version: int) -> Dictionary:
	var migrated := data.duplicate(true)
	if from_version < 2:
		if not migrated.has("scale_tier"):
			migrated["scale_tier"] = 0
		if not migrated.has("auto_resource_mult"):
			migrated["auto_resource_mult"] = 1.0
		if not migrated.has("upkeep_mult"):
			migrated["upkeep_mult"] = 1.0
	return migrated

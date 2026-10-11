class_name WorkerAssignment
extends RefCounted

static func assign_all(city: City) -> int:
	if city == null:
		return 0
	var assigned := 0
	for bld in city.buildings:
		if bld == null or bld.def == null:
			continue
		var chain: ProductionChain = bld.get_production_chain()
		if chain == null or chain.required_workers <= 0:
			continue
		var need: int = chain.required_workers - bld.assigned_workers
		if need <= 0:
			continue
		for u in city.pop:
			if need <= 0:
				break
			if u.state != PopUnit.State.WORKER or u.assigned_to != -1 or u.pending_state != -1:
				continue
			u.assigned_to = bld.uid
			bld.assigned_workers += 1
			need -= 1
			assigned += 1
	var campaign_result := _assign_campaign(city)
	assigned += int(campaign_result.assigned)
	if assigned > 0 or int(campaign_result.released) > 0:
		city.population_changed.emit()
	return assigned

static func campaign_recipe_priority(recipe: Dictionary) -> int:
	var outputs: Dictionary = recipe.get("outputs", {})
	if outputs.has("food") or outputs.has(&"food"):
		return 0
	if outputs.has("wood") or outputs.has(&"wood"):
		return 1
	if outputs.has("iron") or outputs.has(&"iron"):
		return 2
	return 3

static func sort_campaign_recipes(recipes: Array) -> Array:
	var ordered: Array = []
	for recipe in recipes:
		if recipe is Dictionary:
			ordered.append(recipe)
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_priority := campaign_recipe_priority(a)
		var b_priority := campaign_recipe_priority(b)
		if a_priority != b_priority:
			return a_priority < b_priority
		return String(a.get("id", "")) < String(b.get("id", ""))
	)
	return ordered

static func _assign_campaign(city: City) -> Dictionary:
	var recipe_targets: Array[Dictionary] = []
	var caps := {}
	var eligible_uids := {}
	var campaign_uids := {}
	for building_index in range(city.campaign_buildings.size()):
		var building: Dictionary = city.campaign_buildings[building_index]
		var uid := int(building.get("uid", -1))
		if uid < 0:
			continue
		campaign_uids[uid] = true
		var recipes := sort_campaign_recipes(building.get("recipes", []))
		var recipe_total := 0
		var is_active := String(building.get("state", "active")) == "active" \
				and int(building.get("construction_turns_remaining", 0)) <= 0
		if is_active:
			for recipe in recipes:
				var required := int(recipe.get("workers", 0))
				if required <= 0:
					continue
				recipe_total += required
				recipe_targets.append({
					"uid": uid,
					"recipe_id": String(recipe.get("id", "")),
					"priority": campaign_recipe_priority(recipe),
					"workers": required,
					"remaining": required,
					"index": building_index,
				})
		if recipe_total > 0:
			var declared_jobs := int(building.get("jobs", recipe_total))
			caps[uid] = mini(recipe_total, declared_jobs) if declared_jobs > 0 else recipe_total
			eligible_uids[uid] = true

	recipe_targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.priority) != int(b.priority):
			return int(a.priority) < int(b.priority)
		if int(a.uid) != int(b.uid):
			return int(a.uid) < int(b.uid)
		return String(a.recipe_id) < String(b.recipe_id)
	)

	var workers_by_uid := {}
	var released := 0
	for worker in city.pop:
		if worker.assigned_to == -1:
			continue
		if not campaign_uids.has(worker.assigned_to):
			continue
		if worker.state != PopUnit.State.WORKER or worker.pending_state != -1 \
				or not eligible_uids.has(worker.assigned_to):
			worker.assigned_to = -1
			released += 1
			continue
		var assigned: Array = workers_by_uid.get(worker.assigned_to, [])
		assigned.append(worker)
		workers_by_uid[worker.assigned_to] = assigned

	var current_by_uid := {}
	for uid in campaign_uids:
		var assigned: Array = workers_by_uid.get(uid, [])
		var cap := int(caps.get(uid, 0))
		while assigned.size() > cap:
			var worker = assigned.pop_back()
			worker.assigned_to = -1
			released += 1
		workers_by_uid[uid] = assigned
		current_by_uid[uid] = assigned.size()

	var recipe_workers_used := {}
	var building_remaining := {}
	for uid in caps:
		building_remaining[uid] = maxi(int(caps[uid]) - int(current_by_uid.get(uid, 0)), 0)
	for target in recipe_targets:
		var uid := int(target.uid)
		var already_assigned := int(current_by_uid.get(uid, 0)) - int(recipe_workers_used.get(uid, 0))
		var used_for_recipe := mini(maxi(already_assigned, 0), int(target.workers))
		target.remaining = int(target.workers) - used_for_recipe
		recipe_workers_used[uid] = int(recipe_workers_used.get(uid, 0)) + used_for_recipe

	var available: Array[PopUnit] = []
	for worker in city.pop:
		if worker.state == PopUnit.State.WORKER and worker.assigned_to == -1 \
				and worker.pending_state == -1:
			available.append(worker)
	var assigned_count := 0
	for target in recipe_targets:
		var uid := int(target.uid)
		var slots := mini(int(target.remaining), int(building_remaining.get(uid, 0)))
		while slots > 0 and not available.is_empty():
			var worker: PopUnit = available.pop_front()
			worker.assigned_to = uid
			current_by_uid[uid] = int(current_by_uid.get(uid, 0)) + 1
			building_remaining[uid] = int(building_remaining[uid]) - 1
			slots -= 1
			assigned_count += 1

	for building_index in range(city.campaign_buildings.size()):
		var building: Dictionary = city.campaign_buildings[building_index]
		var uid := int(building.get("uid", -1))
		if campaign_uids.has(uid):
			building["assigned_workers"] = int(current_by_uid.get(uid, 0))
			city.campaign_buildings[building_index] = building
	if released > 0:
		city.population_changed.emit()
	return {"assigned": assigned_count, "released": released}


static func release_orphans(city: City) -> int:
	if city == null:
		return 0
	var valid: Dictionary = {}
	for bld in city.buildings:
		if bld != null:
			valid[bld.uid] = true
	for building in city.campaign_buildings:
		if building is Dictionary:
			valid[int(building.get("uid", -1))] = true
	var freed := 0
	for u in city.pop:
		if u.assigned_to != -1 and not valid.has(u.assigned_to):
			u.assigned_to = -1
			freed += 1
	if freed > 0:
		city.population_changed.emit()
	return freed

static func release_building(city: City, building_uid: int) -> int:
	if city == null:
		return 0
	var freed := 0
	for u in city.pop:
		if u.assigned_to == building_uid:
			u.assigned_to = -1
			freed += 1
	for bld in city.buildings:
		if bld != null and bld.uid == building_uid:
			bld.assigned_workers = 0
	if freed > 0:
		city.population_changed.emit()
	return freed

static func rebalance(city: City) -> int:
	if city == null:
		return 0
	release_orphans(city)
	return assign_all(city)

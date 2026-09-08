extends RefCounted
class_name SuccessionController




func select_successor(deceased: HeroController, rng: RandomNumberGenerator = null) -> Follower:
	if deceased == null:
		return null
	var candidates: Array = []
	for f in deceased.followers:
		if f != null and f.path == deceased.path_id:
			candidates.append(f)
	if candidates.is_empty():
		return null
	candidates.sort_custom(func(a, b): return int(a.uid) < int(b.uid))
	var idx := 0
	if rng != null:
		idx = rng.randi() % candidates.size()
	return candidates[idx]



func build_successor(deceased: HeroController, rng: RandomNumberGenerator = null) -> HeroController:
	var succ := HeroController.new()
	succ.path_id = deceased.path_id
	if deceased.magic != null:
		succ.magic.spellbook = deceased.magic.spellbook.duplicate()
		succ.magic.schools = deceased.magic.schools.duplicate()
		succ.magic.mana_current = deceased.magic.mana_current
		succ.magic.mana_max = deceased.magic.mana_max
	_transfer_inventory(deceased, succ)
	if deceased.strategic_resources != null and deceased.strategic_resources.has_method("get_all"):
		succ.strategic_resources.set_all(deceased.strategic_resources.get_all())
	return succ


func _transfer_inventory(deceased: HeroController, succ: HeroController) -> void:
	var src = deceased.inventory
	if src == null:
		return
	for slot in src.equipped:
		var art: Artifact = src.equipped[slot]
		if art != null:
			succ.inventory.equipped[slot] = art.duplicate(true)
	succ.inventory.backpack.clear()
	for art in src.backpack:
		succ.inventory.backpack.append(art.duplicate(true))



func transfer_legend(deceased: HeroController, successor: HeroController,
                    source_cities: Array[City], dest_manager: CityManager) -> void:
	if dest_manager == null or source_cities == null:
		return
	var already_has := true
	for c in source_cities:
		if c != null and not dest_manager.cities.has(c):
			already_has = false
			break
	if not already_has:
		dest_manager.cities.clear()
		for c in source_cities:
			if c == null:
				continue
			var copy: City = City.new()
			copy.deserialize(c.serialize())
			dest_manager.register_city(copy)
	var cap: City = null
	for c in dest_manager.cities:
		if c != null and c.is_capital:
			cap = c
			break
	if cap != null:
		dest_manager.set_capital(cap)



func default_resurrection_cost() -> Dictionary:
	return {"industry": GameNumbers.SUCCESSION_RESURRECT_IND, GameNumbers.SUCCESSION_SPECIAL_KEY: GameNumbers.SUCCESSION_RESURRECT_GOLD}


func resurrect_hero(city: City, cost: Dictionary = {}) -> bool:
	if city == null:
		return false
	var c := cost.duplicate()
	if not c.has(&"industry"):
		c["industry"] = GameNumbers.SUCCESSION_RESURRECT_IND
	if not c.has(GameNumbers.SUCCESSION_SPECIAL_KEY):
		c[GameNumbers.SUCCESSION_SPECIAL_KEY] = GameNumbers.SUCCESSION_RESURRECT_GOLD
	if not city.can_resurrect(c):
		return false
	for key in c:
		if city.storage.has(key):
			city.storage[key] = maxf(0.0, float(city.storage[key]) - float(c[key]))
	return true



func on_hero_died(deceased: HeroController, rng: RandomNumberGenerator = null,
                  source_cities: Array[City] = [], dest_manager: CityManager = null) -> HeroController:
	if deceased == null:
		return null
	var successor_follower := select_successor(deceased, rng)
	if successor_follower == null:
		return null
	var successor := build_successor(deceased, rng)
	transfer_legend(deceased, successor, source_cities, dest_manager)
	return successor

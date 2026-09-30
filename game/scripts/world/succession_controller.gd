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
	# team-romance-roleplay 3.2: приоритет — супруг того же пути → bond ≥ 60 (по
	# убыванию bond) → остальные (по uid, как раньше). rng — случайный выбор
	# только внутри лучшей группы.
	var rel = deceased.relationships
	var tier := func(f: Follower) -> int:
		if rel != null and rel.has_pair(int(f.uid)):
			var p: Dictionary = rel.pair(int(f.uid))
			if bool(p.get("spouse", false)):
				return 0
			if int(p.get("bond", 0)) >= 60:
				return 1
		return 2
	var best_tier := 2
	for f in candidates:
		best_tier = mini(best_tier, tier.call(f))
	var top: Array = []
	for f in candidates:
		if tier.call(f) == best_tier:
			top.append(f)
	if best_tier == 1:
		top.sort_custom(func(a, b):
			var ba := int(rel.pair(int(a.uid))["bond"]) if rel != null else 0
			var bb := int(rel.pair(int(b.uid))["bond"]) if rel != null else 0
			if ba != bb:
				return ba > bb
			return int(a.uid) < int(b.uid))
	else:
		top.sort_custom(func(a, b): return int(a.uid) < int(b.uid))
	var idx := 0
	if rng != null and top.size() > 1:
		idx = rng.randi() % top.size()
	return top[idx]

func build_successor(deceased: HeroController, _rng: RandomNumberGenerator = null) -> HeroController:
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
	# Навыки
	if deceased.skills != null:
		for skill_name in deceased.skills.levels:
			succ.skills.set_skill(StringName(skill_name), int(deceased.skills.levels[skill_name]))
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

func transfer_legend(_deceased: HeroController, _successor: HeroController,
                    source_cities: Array[City], dest_manager: CityManager) -> void:
	if dest_manager == null or source_cities == null:
		return
	var already_has := true
	for city in source_cities:
		if city != null and not dest_manager.cities.has(city):
			already_has = false
			break
	if not already_has:
		dest_manager.cities.clear()
		for city in source_cities:
			if city == null:
				continue
			var copy: City = City.new()
			copy.deserialize(city.serialize())
			dest_manager.register_city(copy)
	var cap: City = null
	for city in dest_manager.cities:
		if city != null and city.is_capital:
			cap = city
			break
	if cap != null:
		dest_manager.set_capital(cap)

func default_resurrection_cost() -> Dictionary:
	return {"industry": GameNumbers.SUCCESSION_RESURRECT_IND, GameNumbers.SUCCESSION_SPECIAL_KEY: GameNumbers.SUCCESSION_RESURRECT_GOLD}

## Проверяет, можно ли воскресить героя в данном городе (храм + ресурсы).
func can_resurrect(city: City) -> bool:
	if city == null:
		return false
	if city.get_great_temple_level() < 1:
		return false
	if float(city.storage.get(&"industry", 0.0)) < GameNumbers.SUCCESSION_RESURRECT_IND:
		return false
	if float(city.storage.get(GameNumbers.SUCCESSION_SPECIAL_KEY, 0.0)) < GameNumbers.SUCCESSION_RESURRECT_GOLD:
		return false
	return true

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

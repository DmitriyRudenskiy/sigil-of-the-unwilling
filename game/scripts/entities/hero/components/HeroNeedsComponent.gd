class_name HeroNeedsComponent
extends HeroComponent

var needs: HeroNeeds = HeroNeeds.new()

func tick(in_city: bool, city: City = null) -> StringName:
	return needs.tick(in_city, city)

func is_critical(id: int) -> bool:
	return needs.is_critical(id)

func get_need(id: int) -> float:
	return needs.get_need(id)

func reset() -> void:
	needs.reset()

func get_needs() -> Dictionary:
	return needs.needs

func set_needs(v: Dictionary) -> void:
	needs.needs = v

func end_turn() -> void:
	if _hero == null or not _hero.is_alive:
		return
	var city: City = null
	if _hero.city_manager != null:
		var mov_comp := _hero.get_component("Movement") as HeroMovementComponent
		if mov_comp != null:
			city = _hero.city_manager.city_at(mov_comp.get_current_cell())
	var cause := tick(city != null, city)
	if cause != &"":
		_hero.mark_combat_dead()
		GameLogger.world("Hero death by needs: %s" % String(cause))
		GameEventBus.hero_died.emit(cause)

func serialize() -> Dictionary:
	return {"needs": needs.serialize()}

func deserialize(data: Dictionary) -> void:
	needs.deserialize(data.get("needs", {}))
